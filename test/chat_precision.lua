-- Reviewed short-chat meanings and counterexamples; no game APIs required.
dofile('test/engine.lua')
local T=LoadEngine()
local cases={
 {'no one is healing','誰も回復していません'},
 {'no one can heal','誰も回復できません'},
 {'no one attacked','誰も攻撃しませんでした'},
 {'I saw no one','誰も見ませんでした'},
 {'no one left','誰も残っていません'},
 {'no one left?','誰も残っていませんか？'},
 {'no one left the group','誰もグループを出ませんでした'},
 {'two enemies left','敵があと2人います'},
 {'two enemies left?','敵があと2人いますか？'},
 {'only one healer left','ヒーラーが1人だけ残っています'},
 {'only 2 enemies left','敵が2人だけ残っています'},
 {'no enemies left','敵は残っていません'},
 {'hi two enemies left','こんにちは、敵×2が残っています'},
 {'two enemies have left','敵2人が出ました'},
 {'two enemies left the keep','敵2人が砦を出ました'},
 {'the boss has left','ボスは出ました'},
 {'I went left','左に行きました'},
 {'I have two left hands','左手×2を持っています'},
 {'I have two potions left','ポーションが2本残っています'},
 {'I have no potions left','私にはポーションが残っていません'},
 {'I have two potions','ポーション×2を持っています'},
 {'out of magicka','マジカが尽きています'},
 {'out of magicka?','マジカが尽きていますか？'},
 {'out of stamina','スタミナが尽きています'},
 {'I am out of magicka','マジカが尽きています'},
 {'we were out of magicka','私たちはマジカが尽きていました'},
 {'we are not out of potions','私たちはポーションが尽きていません'},
 {'we ran out of magicka','マジカを使い果たしました'},
 {'out of the keep','砦から'},
 {'get out of the keep','砦から出てください'},
 {'we got out of the keep','砦から出ました'},
 {'dont get out of the keep','砦から出ないでください'},
 {'get out of red','赤い範囲から出てください'},
 {'dont get out of red','赤い範囲から出ないでください'},
 {'healer is not here yet','ヒーラーはまだここにいません'},
 {'healer is here now','今ヒーラーはここにいます'},
 {'no one is here yet','誰もまだここにいません'},
 {'we have no healer','ヒーラーがいません'},
 {'we have two healers','ヒーラー2人がいます'},
 {'we dont have enough healers','ヒーラーが足りません'},
 {'I dont have enough potions','ポーションが足りません'},
 {'we have enough healers','十分なヒーラーがいます'},
 {'no healers online','オンラインのヒーラーはいません'},
 {'no healers online?','オンラインのヒーラーはいませんか？'},
 {'healers are not online','ヒーラーはオンラインではありません'},
 {'who has the crown?','誰がクラウンを持っていますか？','誰がグループリーダーを持っていますか？'},
}
local checks,failures=0,0
local function check(ok,label)
 checks=checks+1
 if not ok then failures=failures+1;print('FAIL '..label) end
end
for _,cyro in ipairs({false,true}) do
 T.SetCyrodiilPriority(cyro)
 for _,c in ipairs(cases) do
  for _,input in ipairs({c[1],string.upper(c[1])}) do
   local got,stats=T.Translate(input);local want=cyro and c[3] or c[2]
   check(got==want and stats.unknown==0,input..' -> '..got..' expected '..want)
  end
 end
end
local got,stats=T.Translate('out of zqxv')
check(got=='zqxvから' and stats.unknown==1 and stats.known==1,'unknown resource kept and counted')
for key,value in pairs({['no one']='特別な呼び名',left='左側指定',['out of']='外側指定'}) do
 T.SetUserEntries({[key]='n:'..value})
 check(T.Translate(key)==value,'user dictionary '..key)
end
T.SetUserEntries({have='v:所持する/s'})
check(T.Translate('we have no healer')=='ヒーラーを所持しません','user have bypasses availability inference')
T.SetUserEntries({})
print(('chat precision: %d checks, %d failures'):format(checks,failures))
if failures>0 then os.exit(1) end
