-- Reviewed meaning regressions: tense, polarity, modality, contraction ambiguity.
dofile('test/engine.lua')
local T=LoadEngine()
local cases={
 {"Could you have healed me?","あなたは私を回復できましたか？"},
 {"Should I have waited?","私は待つべきでしたか？"},
 {"I'd seen it.","私はそれを見ました。"},
 {"He's gone.","彼は行きました。"},
 {"He's tired.","彼は疲れています。"},
 {"He's not killed.","彼は倒されていません。"},

 {"I'd been waiting.","私は待っていました。"},
 {"I've been waiting.","私は待っています。"},
 {"I haven't been able to heal.","私は回復できません。"},
 {"I could heal yesterday.","私は昨日回復できました。"},
 {"I might have already left.","私はもう出たかもしれません。"},
 {"He has just left.","彼はちょうど出ました。"},
 {"He has never seen it.","彼はそれを見たことがありません。"},

 {"I couldn't heal you.","私はあなたを回復できませんでした。"},
 {"I couldn't go to the dungeon.","私はダンジョンに行けませんでした。"},
 {"I couldnt heal you.","私はあなたを回復できませんでした。"},
 {"I couldn’t heal you.","私はあなたを回復できませんでした。"},
 {"I can't heal you.","私はあなたを回復できません。"},
 {"I don't know.","私は知りません。"},
 {"I didn't heal you.","私はあなたを回復しませんでした。"},
 {"Could you heal me?","私を回復してもらえますか？"},
 {"Could I join?","私は参加できますか？"},
 {"I could help tomorrow.","私は明日手伝えます。"},
 {"I couldn't join tomorrow.","私は明日参加できません。"},
 {"I couldn't help yesterday.","私は昨日手伝えませんでした。"},
 {"I should have waited.","私は待つべきでした。"},
 {"I shouldn't have attacked.","私は攻撃するべきではありませんでした。"},
 {"I should wait.","私は待つべきです。"},
 {"I shouldn't attack.","私は攻撃するべきではありません。"},
 {"We should have repaired the door.","私たちは扉を修理するべきでした。","私たちは門を修理するべきでした。"},
 {"He might have left.","彼は出たかもしれません。"},
 {"He may not have seen you.","彼はあなたを見なかったかもしれません。"},
 {"He must have left.","彼は出たに違いありません。"},
 {"I would have helped.","私は手伝ったでしょう。"},
 {"I could have healed you.","私はあなたを回復できたかもしれません。"},
 {"I couldn't have healed you.","私はあなたを回復できたはずがありません。"},
 {"I couldn't've healed you.","私はあなたを回復できたはずがありません。"},
 {"I couldn’t’ve healed you.","私はあなたを回復できたはずがありません。"},
 {"I'd've helped.","私は手伝ったでしょう。"},
 {"You shouldn't've attacked.","あなたは攻撃するべきではありませんでした。"},
 {"I'd already left.","私はもう出ました。"},
 {"I had already left.","私はもう出ました。"},
 {"He's already left.","彼はもう出ました。"},
 {"He's been waiting.","彼は待っています。"},
 {"I'd like to help.","私は手伝いたいです。"},
 {"He's killed.","彼は倒されています。"},
 {"He's killed the boss.","彼はボスを倒しました。"},
 {"I have left.","私は出ました。"},
 {"Turn left.","左に曲がってください。"},
 {"I didn't have to leave.","私は出なくてもよかったです。"},
 {"I don't have to leave.","私は出なくてもいいです。"},
 {"I had to leave.","私は出なければなりませんでした。"},
 {"I didn't need to leave.","私は出る必要はありませんでした。"},
 {"I don't need to leave.","私は出る必要はありません。"},
 {"I wasn't able to heal.","私は回復できませんでした。"},
 {"I won't be able to heal.","私は回復できません。"},
 {"I might have been healing.","私は回復していたかもしれません。"},
 {"He must have been killed.","彼は倒されたに違いありません。"},
 {"I may be healing.","私は回復しているかもしれません。"},
 {"I might be killed.","私は倒されるかもしれません。"},
 {"If I couldn't heal, we would die.","もし私が回復できなかったら、私たちは死にます。"},
 {"If you can heal, help me.","もしあなたが回復できたら、助けて。"},
 {"You must not attack.","あなたは攻撃してはいけません。"},
 {"You don't have to attack.","あなたは攻撃しなくてもいいです。"},
}
local failures,checks=0,0
for _,cyro in ipairs({false,true}) do
 T.SetCyrodiilPriority(cyro)
 for _,c in ipairs(cases) do
  for _,input in ipairs({c[1],string.upper(c[1])}) do
   local result,stats=T.Translate(input)
   checks=checks+1
   local want = cyro and c[3] or c[2]
   if result~=want or stats.unknown~=0 then
    failures=failures+1;print('FAIL '..input..' -> '..result..' expected '..want)
   end
  end
 end
end
print(('grammar precision: %d checks, %d failures'):format(checks,failures))
if failures>0 then os.exit(1) end
