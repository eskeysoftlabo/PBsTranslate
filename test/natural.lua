-- Reviewed Japanese generation: fluent surface forms and semantic guardrails.
dofile('test/engine.lua')
local T=LoadEngine()
local cases={
 {'we need you to heal us','私たちを回復してほしいです'},
 {'we need you to heal us at roe','ローベック砦で私たちを回復してほしいです'},
 {'we need you not to attack','攻撃しないでほしいです'},
 {'we need you to not attack','攻撃しないでほしいです'},
 {'we do not need you to attack','私たちはあなたに攻撃してもらう必要はありません'},
 {'we needed you to heal us','私たちはあなたに私たちを回復してもらう必要がありました'},
 {'we need him to heal us','私たちは彼に私たちを回復してもらう必要があります'},
 {'we need you to heal us?','私たちはあなたに私たちを回復してもらう必要がありますか？'},
 {'two enemies left','敵があと2人います'},
 {'two enemies left?','敵があと2人いますか？'},
 {'two enemies left the keep','敵2人が砦を出ました'},
 {'only one healer left','ヒーラーが1人だけ残っています'},
 {'we need two more healers at roe','ローベック砦でヒーラーがあと2人必要です'},
 {'we need 2 more dps','DPSがあと2人必要です'},
 {'I have two potions left','ポーションが2本残っています'},
 {'I have no potions left','私にはポーションが残っていません'},
 {'no one left','誰も残っていません'},
 {'I have not used my ultimate yet','まだアルティメットを使っていません'},
 {'I was trying to join','参加しようとしていました'},
 {'I cannot heal you','あなたを回復できません'},
 {'I do not need to heal','回復する必要はありません'},
 {'I heal too','私も回復します'},
 {'I also heal','私も回復します'},
 {'I can heal too','私も回復できます'},
 {'I heal but you attack','私は回復しますが、あなたは攻撃します'},
 {'I heal, you attack','私は回復します、あなたは攻撃します'},
 {'if I heal, you attack','もし私が回復したら、あなたは攻撃します'},
 {'Can I heal','回復してもいいですか'},
 {'Can I heal?','回復してもいいですか？'},
 {'he can heal','彼は回復できます'},
}
local checks,failures=0,0
local function check(ok,label)
 checks=checks+1;if not ok then failures=failures+1;print('FAIL '..label) end
end
for _,cyro in ipairs({false,true}) do
 T.SetCyrodiilPriority(cyro)
 for _,c in ipairs(cases) do
  for _,input in ipairs({c[1],string.upper(c[1])}) do
   local got,stats=T.Translate(input)
   check(got==c[2] and stats.unknown==0,input..' -> '..got..' expected '..c[2])
  end
 end
end
T.SetUserEntries({i='pn:自分',healer='n:癒やし手'})
check(T.Translate('I heal'):find('自分',1,true)~=nil,'custom speaker is preserved')
local _,stats=T.Translate('two healers left')
check(not stats.structured,'custom noun bypasses structured counters')
T.SetUserEntries({['we need you to heal us']='x:指定した文章'})
check(T.Translate('we need you to heal us')=='指定した文章','custom sentence is verbatim')
T.SetUserEntries({})
local link='|H1:item:123|h[Example Item]|h'
check(T.Translate('I need '..link):find(link,1,true)~=nil,'item link is preserved')
check(T.Translate('I heal Zqxv'):find('Zqxv',1,true)~=nil,'unknown target is preserved')
print(('natural: %d checks, %d failures'):format(checks,failures))
if failures>0 then os.exit(1) end
