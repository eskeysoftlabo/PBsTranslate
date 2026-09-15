-- Wheel construction follows ESO's Clear -> AddMenuEntry -> Cancel -> Show order.
ADDON_DIR='.'
dofile('test/harness.lua')
local ui=PBS_TRANSLATE.sharing
local count=0
local function check(label,got,want) count=count+1;assert(got==want,label..': '..tostring(got)..' ~= '..tostring(want)) end
ZO_CreateStringId('SI_RADIAL_MENU_CANCEL_BUTTON','Cancel')
ZO_CreateStringId('SI_PLAYER_TO_PLAYER_INVITE_TRADE','Trade')
function ZO_PreHook(object,name,hook)
    assert(name~='ShowPlayerInteractMenu','must not taint the protected menu builder')
    local old=object[name]
    object[name]=function(...) if not hook(...) then return old(...) end end
end
function ZO_PostHook(object,name,hook)
    assert(name~='ShowPlayerInteractMenu','must not taint the protected menu builder')
    local old=object[name]
    object[name]=function(...) local result=old(...);hook(...);return result end
end
local pending={}
function zo_callLater(fn) pending[#pending+1]=fn end
local gamepad=true
function IsInGamepadPreferredMode() return gamepad end
local allowed=true
function CanCommunicateWith() error('addon must not call communication restriction APIs') end
local ignored=false
function IsIgnored() return ignored end
local object={currentTargetDisplayName='@Peer',currentTargetCharacterNameRaw='Peer Character'}
function object:GetRadialMenu() return {entries=self.entries} end
PLAYER_TO_PLAYER=object
function object:AddMenuEntry(text,icons,enabled,callback)
    self.entries[#self.entries+1]={name=text,text=text,icons=icons,callback=callback}
end
function object:ShowPlayerInteractMenu(isIgnored)
    self.entries={}
    self:AddMenuEntry(GetString(SI_PLAYER_TO_PLAYER_INVITE_TRADE),{},not isIgnored and not ignored and allowed,function() end)
    self:AddMenuEntry(GetString(SI_RADIAL_MENU_CANCEL_BUTTON),{},true)
    self.visibleEntries=#self.entries
    return 'original return'
end
local originalBuilder=object.ShowPlayerInteractMenu
local started
ui.Start=function(_,peer) started=peer end
ui:InitMenus();ui:InitMenus()
check('protected builder identity unchanged',object.ShowPlayerInteractMenu,originalBuilder)
check('original return preserved',object:ShowPlayerInteractMenu(false),'original return')
check('item present before Show',object.visibleEntries,3)
check('native trade retained',object.entries[1].text,'Trade')
check('requested label',object.entries[2].text,'辞書データを共有')
check('native cancel retained',object.entries[3].text,'Cancel')
check('controller icon',object.entries[2].icons.enabledNormal:find('/Gamepad/',1,true)~=nil,true)
local chosen=object.entries[2].callback
object.currentTargetDisplayName='@DifferentPlayer'
chosen()
check('wait for wheel to close',started,nil)
table.remove(pending,1)()
check('original target captured',started,'@Peer')
check('private communication API remains untouched',object.ShowPlayerInteractMenu,originalBuilder)
object:ShowPlayerInteractMenu(false)
check('one item on reopening',object.visibleEntries,3)
object:ShowPlayerInteractMenu(true)
check('ignored argument respected',object.visibleEntries,2)
ignored=true;object:ShowPlayerInteractMenu(false)
check('ignore list respected',object.visibleEntries,2);ignored=false
allowed=false;object:ShowPlayerInteractMenu(false)
check('communication restriction respected',object.visibleEntries,2);allowed=true
object.currentTargetDisplayName=nil;object:ShowPlayerInteractMenu(false)
check('no player target',object.visibleEntries,2)
object.currentTargetDisplayName=GetDisplayName();object:ShowPlayerInteractMenu(false)
check('no self sharing',object.visibleEntries,2)
object.currentTargetDisplayName='@Peer';gamepad=false;object:ShowPlayerInteractMenu(false)
check('keyboard wheel receives entry',object.visibleEntries,3)
check('keyboard icon',object.entries[2].icons.enabledNormal,'EsoUI/Art/HUD/radialIcon_whisper_up.dds')
object.entries={};object:AddMenuEntry('Cancel',{},true)
check('other response menus untouched',#object.entries,1)
-- The object may be initialized only after add-on load; initialization stays retryable.
PLAYER_TO_PLAYER=nil;ui:InitMenus();PLAYER_TO_PLAYER=object;ui:InitMenus()
object:ShowPlayerInteractMenu(false)
check('no duplicate hooks after reactivation',object.visibleEntries,3)
object:AddMenuEntry('Trade',{},true,function() end)
local shares=0;for _,entry in ipairs(object.entries) do if entry.name=='辞書データを共有' then shares=shares+1 end end
check('repeated native entry does not duplicate share',shares,1)
print('interaction wheel: '..count..' checks passed')
