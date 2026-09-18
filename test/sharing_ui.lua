-- Integration of the ESO adapter with panel/dialog/LGB API-shaped test doubles.
ADDON_DIR='.'
dofile('test/harness.lua')
local addon,S=PBS_TRANSLATE,PBsTranslateShare
local ui=addon.sharing
local checks=0
local function check(label,got,want) checks=checks+1;assert(got==want,label..': '..tostring(got)..' ~= '..tostring(want)) end
local clock=100
function GetFrameTimeSeconds() return clock end
function GetGroupSize() return 2 end
function GetGroupUnitTagByIndex(i) return 'group'..i end
function GetUnitDisplayName(tag) return tag=='group1' and '@Peer' or '@PinkBanther' end
function GetUnitName(tag) return tag=='group1' and 'Peer Character' or 'My Character' end
function IsUnitOnline() return true end
local combat=false
function IsUnitInCombat() return combat end
function zo_callLater(fn) fn() end
local dialogs={}
GAMEPAD_DIALOGS={BASIC=1}
function ZO_Dialogs_RegisterCustomDialog(name,definition) dialogs[name]=definition end
local shown
function ZO_Dialogs_ShowPlatformDialog(name,data) shown={name=name,data=data,info=dialogs[name]} end
local function Press(index)
    local dialog=shown
    local definition=dialog.info.buttons[index]
    check('visible button',definition.visible(dialog),true)
    check('localized label',type(definition.text(dialog)),'string')
    definition.callback(dialog)
end
-- Only the wheel's AddMenuEntry may be hooked (see test/sharing_interact.lua); a hook on
-- anything else, such as the social menus, fails loudly.
function ZO_PostHook(_,name) error('client code must not be hooked: '..tostring(name)) end
function ZO_PreHook(_,name) error('client code must not be hooked: '..tostring(name)) end
local wire={}
local protocol={fields={}}
function protocol:SetDisplayName() end
function protocol:AddField(field) self.fields[#self.fields+1]=field end
function protocol:OnData(fn) self.receiver=fn end
function protocol:Finalize(options) self.options=options;return true end
function protocol:IsEnabled() return self.enabled~=false end
function protocol:Send(packet) wire[#wire+1]=packet;return true end
local handler={}
function handler:SetDisplayName() end
function handler:DeclareProtocol(id,name) check('protocol range',id>=0 and id<=511,true);self.id=id;self.name=name;return protocol end
LibGroupBroadcast={}
function LibGroupBroadcast:RegisterHandler(addonName,handlerName) handler.addonName=addonName;handler.handlerName=handlerName;return handler end
function LibGroupBroadcast.CreateNumericField(label,options) return {label=label,options=options} end
function LibGroupBroadcast.CreateStringField(label,options) return {label=label,options=options} end
ui:InitDialog();ui:InitTransport()
check('registered protocol id',handler.id,462)
check('registered protocol name',handler.name,'PBsTranslateDictionary')
check('handler is the add-on',handler.addonName,'PBsTranslate')
check('bounded string payload',protocol.fields[6].options.maxLength,96)
check('do not discard previous fragments',protocol.options.replaceQueuedMessages,false)
check('avoid combat bandwidth',protocol.options.isRelevantInCombat,false)
-- The panel offers online group members other than you, and starts the share from a button.
local memberRow,shareButton
for _,row in ipairs(PanelRows) do
    if row.label=='共有する相手' then memberRow=row end
    if row.label=='選んだ相手に辞書を共有' then shareButton=row end
end
check('panel member list',memberRow~=nil and shareButton~=nil,true)
local items=memberRow.items()
check('member list excludes self',#items,1)
check('member list names peer',memberRow.getFunction(),'@Peer')
do
    local size=GetGroupSize;GetGroupSize=function() return 0 end
    check('empty group placeholder',memberRow.items()[1].data,nil)
    memberRow.getFunction();wire={};shareButton.clickHandler()
    check('no recipient sends nothing',#wire,0)
    check('no recipient explained',ui.lastMessage,'同じグループのオンラインの相手を選んでください。')
    GetGroupSize=size
end
memberRow.setFunction(nil,items[1].name,items[1])
check('character name resolves to account',ui:Resolve('Peer Character'),'@Peer')
check('self excluded',ui:Resolve('@PinkBanther'),nil)
addon.sv.userWords={ham='n:ヴォレンドラング'}
shareButton.clickHandler()
check('start needs confirmation',#wire,0)
check('one saved entry displays one',shown.data.text:find('登録辞書 1件',1,true)~=nil,true)
check('settings list also has one entry',#addon:WordListItems(),1)
check('outgoing preview identifies entry',shown.data.text:find('ham = n:ヴォレンドラング',1,true)~=nil,true)
Press(1)
check('offer transmitted',wire[1].kind,S.OFFER)
check('wire count is one',ui.session.active.count,1)
check('timer active only in transfer',UpdateHandlers[addon.name..'Sharing']~=nil,true)
ui.session:Cancel();wire={}
check('idle timer removed',UpdateHandlers[addon.name..'Sharing'],nil)

-- Updating the same key must not add a record; a distinct key must be visible.
addon:StoreUserWord(' HAM ', 'n:ヴォレンドラング')
ui:Start('@Peer')
check('same normalized key still one',shown.data.text:find('登録辞書 1件',1,true)~=nil,true)
addon:StoreUserWord('lessy','n:アレッシア砦')
ui:Start('@Peer')
check('two records display two',shown.data.text:find('登録辞書 2件',1,true)~=nil,true)
check('second entry visible',shown.data.text:find('lessy = n:アレッシア砦',1,true)~=nil,true)
-- The confirmed preview and actual transfer use the same snapshot.
addon:DeleteUserWord('lessy')
Press(1)
check('approved snapshot count',ui.session.active.count,2)
check('approved snapshot contains second entry',ui.session.active.data:find('lessy',1,true)~=nil,true)
ui.session:Cancel();wire={}

-- A remote sender drives the real protocol callback, followed by UI acceptance/import.
local remoteWire={}
local remote=S.New({now=function() return clock end,name=function() return '@Peer' end,
    member=function(n) return n=='@PinkBanther' end,
    send=function(p) remoteWire[#remoteWire+1]=p;return true end,notify=function() end})
local function Pump()
    local turns=0
    while #wire>0 or #remoteWire>0 do
        turns=turns+1;assert(turns<1000)
        if #remoteWire>0 then protocol.receiver('group1',table.remove(remoteWire,1)) end
        if #wire>0 then remote:Receive('@PinkBanther',table.remove(wire,1)) end
    end
end
remote:Start('@PinkBanther',{ham='n:別の訳',lessy='n:アレッシア砦'})
Pump()
check('offer only before acceptance',ui.session.active.size,0)
check('existing dictionary unchanged',addon.sv.userWords.ham,'n:ヴォレンドラング')
Press(1);Pump()
check('complete review pending',ui.session.review~=nil,true)
check('no automatic import',addon.sv.userWords.lessy,nil)
check('preview contains proposed value',shown.info.mainText.text(shown):find('アレッシア砦',1,true)~=nil,true)
Press(2) -- import choices
-- User manually adds a word while review is pending. Merge must preserve it.
addon:StoreUserWord('manual','n:手動登録')
Press(1) -- new only
check('new imported',addon.sv.userWords.lessy,'n:アレッシア砦')
check('conflict preserved',addon.sv.userWords.ham,'n:ヴォレンドラング')
check('manual edit preserved',addon.sv.userWords.manual,'n:手動登録')
check('engine updated',PBsTranslate.Translate('lessy'),'アレッシア砦')
check('backup preimport state',addon.sv.shareBackup.lessy,nil)
check('review consumed',ui.session.review,nil)
ui:Restore();Press(1)
check('restore old dictionary',addon.sv.userWords.lessy,nil)
check('restore includes manual edit before import',addon.sv.userWords.manual,'n:手動登録')

ui.session.review={peer='@Peer',words={ham='n:別の訳'}}
ui:ImportOptions();Press(2)
check('overwrite needs separate confirmation',addon.sv.userWords.ham,'n:ヴォレンドラング')
Press(1)
check('overwrite confirmed',addon.sv.userWords.ham,'n:別の訳')
check('backup preserved old translation',addon.sv.shareBackup.ham,'n:ヴォレンドラング')
ui:Restore();Press(1)

-- Feature unavailable and stale UI actions cannot mutate the dictionary.
protocol.enabled=false;wire={};ui:Start('@Peer');check('disabled library sends nothing',#wire,0)
protocol.enabled=true;combat=true;ui:Start('@Peer');check('combat start blocked',#wire,0);combat=false
local oldReview={peer='@Peer',words={ham='n:古い受信'}}
ui.session.review={peer='@Peer',words={ham='n:新しい受信'}}
ui:Import(oldReview,true)
check('stale review ignored',addon.sv.userWords.ham,'n:ヴォレンドラング')
ui.session.review=nil
clock=clock+20
remote:Start('@PinkBanther',{test='n:確認'});Pump()
shown.info.noChoiceCallback(shown);Pump()
check('closing offer rejects it',ui.session.active,nil)
check('closing offer stops sender',remote.active,nil)
clock=clock+20
addon.sv.shareAllowRequests=false
remote:Start('@PinkBanther',{test='n:確認'});Pump()
check('request opt out',ui.session.active,nil)
remote:Cancel();Pump();addon.sv.shareAllowRequests=true
clock=clock+20
protocol.enabled=false
remote:Start('@PinkBanther',{test='n:確認'});Pump()
check('disabled protocol ignores requests',ui.session.active,nil)
remote:Cancel();Pump();protocol.enabled=true
local originalDeclare=handler.DeclareProtocol
handler.DeclareProtocol=function() error('Protocol with ID 462 already exists') end
ui.protocol=nil;ui.transportAttempted=false
check('protocol collision fails closed',ui:InitTransport(),false)
check('collision detail retained',ui.transportError:find('already exists',1,true)~=nil,true)
handler.DeclareProtocol=originalDeclare;ui.protocol=protocol
print('sharing UI: '..checks..' checks passed')
