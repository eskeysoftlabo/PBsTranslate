-- The structural reader (Syntax.lua + SyntaxGen.lua): reviewed lines it must produce itself, and
-- the ways it must hand a line back to the old engine instead of guessing.
dofile('test/engine.lua')
local T=LoadEngine()
local cases={
 {'let me see it','それを見せてください'},
 {'I saw him leave','彼が出るのを見ました'},
 {'can you help me find the key','鍵を見つけるのを手伝ってもらえますか'},
 {'I recommend doing the daily quests','デイリークエストをすることをお勧めします'},
 {'we are looking for a tank and a healer','タンクとヒーラーを探しています'},
 {'a tank is stronger than a healer','タンクはヒーラーより強いです'},
 {'he runs faster than me','彼は私より速く周回します'},
 {'it takes about ten minutes to clear the dungeon','ダンジョンをクリアするのに約10分かかります'},
 {'it takes 5 minutes','5分かかります'},
 {'how long does it take to finish the quest','クエストを終わらせるのにどのくらいかかりますか'},
 {'thank you so much for the help','本当に助けてくれてありがとうございます'},
 {'thanks for coming','来てくれてありがとう'},
 {'the server is down for maintenance','サーバーはメンテナンスのためにダウンしています'},
 {'I can\'t hear you','あなたの声が聞こえません'},
 {'he helped me with the quest','彼はクエストを手伝ってくれました'},
 {'that was the best run ever','それは今までで一番いい周回でした'},
 {'I am tired of this grind','このグラインドに飽きています'},
 {'I am very interested in history','歴史にとても興味があります'},
 {'I opened the door','扉を開けました'},
 {'I finished the quest','クエストを終わらせました'},
 {'I have never seen this item before','以前このアイテムを見たことがありません'},
 {'we are in the middle of a fight','私たちは戦いの最中です'},
 {'there are too many players in this zone','このゾーンのプレイヤーが多すぎます'},
 {'I died three times on the last boss','最終ボスで3回死にました'},
 {'I haven\'t played for a month','1か月間遊んでいません'},
 {'stay behind the tank so you don\'t die','死なないように、タンクの後ろにいてください'},
 {'make sure you bring food','料理を持ってくるようにしてください'},
 {'we all focus on the boss','私たちはみんなボスに集中します'},
 {'I am trying to sell my house for fifty thousand gold','5万ゴールドで家を売ろうとしています'},
 {'the daily reset is soon','デイリーリセットはもうすぐです'},
 {'I will be right there','ちょうどそこにいます'},
 {'do you know where the vendor is','商人がどこにいるか知っていますか'},
 {'what time does the event start','イベントは何時に始まりますか'},
 {'I think we should wait for the healer','ヒーラーを待つべきだと思います'},
 {'I forgot to bring my potions','私のポーションを持ってくるのを忘れました'},
 {'we wiped on the last boss twice','最終ボスで2回全滅しました'},
 {'my game crashed and I lost my loot','私のゲームは落ちて、戦利品を失くしました'},
 {'does anyone have a spare key','誰か予備の鍵を持っていますか'},
 {'the shop closes at midnight','店は真夜中に閉まります'},
 {'nobody is online right now','誰も今すぐオンラインではありません'},
 {'how do I get to the city from here','ここからどうやって街に着きますか'},
 {'don\'t forget to repair your armor','あなたの防具を修理するのを忘れないでください'},
 {'he told me that the boss is easy','彼は私にボスが簡単だと言いました'},
 {'the price of the potion went up yesterday','昨日ポーションの値段は上に行きました'},
}
local checks,failures=0,0
local function check(ok,label)
 checks=checks+1;if not ok then failures=failures+1;print('FAIL '..label) end
end
for _,c in ipairs(cases) do
 T.Syntax.lastError=nil
 local got,stats=T.Translate(c[1])
 check(got==c[2] and stats.unknown==0,c[1]..' -> '..got..' expected '..c[2])
 check(T.Syntax.lastError==nil,c[1]..' was not read by the structural reader: '..tostring(T.Syntax.lastError))
end
-- with the Cyrodiil words first, a line is still answered
T.SetCyrodiilPriority(true)
for _,c in ipairs(cases) do
 local ok,got=pcall(T.Translate,c[1])
 check(ok and got~='','Cyrodiil priority: '..c[1])
end
T.SetCyrodiilPriority(false)

-- the old engine answers when the reader cannot
local declined={
 'you don\'t need to be an expert to join us',
 'any tanks online?',
 'inc 2 on keep',
 'I have a flurble',
}
for _,line in ipairs(declined) do
 T.Syntax.enabled=false
 local old=T.Translate(line)
 T.Syntax.enabled=true
 local got=T.Translate(line)
 check(got~='' and got==old,'declined: '..line..' -> '..got..' old '..old)
end

-- switching the reader off gives the old engine's answer, and never an error
T.Syntax.enabled=false
for _,c in ipairs(cases) do
 local ok,got=pcall(T.Translate,c[1])
 check(ok and got~='','old engine alone: '..c[1])
end
T.Syntax.enabled=true

-- a user's own entry beats the reader
T.SetUserEntries({healer='n:癒やし手'})
check(T.Translate('a tank is stronger than a healer'):find('癒やし手',1,true)~=nil,'user noun is used')
T.SetUserEntries({['a tank is stronger than a healer']='x:指定した文章'})
check(T.Translate('a tank is stronger than a healer')=='指定した文章','user sentence is verbatim')
T.SetUserEntries({})

-- item links and names pass through
local link='|H1:item:123|h[Example Item]|h'
check(T.Translate('I opened '..link):find(link,1,true)~=nil,'item link is preserved')
check(T.Translate('I opened Zqxv'):find('Zqxv',1,true)~=nil,'unknown name is preserved')

print(('syntax: %d checks, %d failures'):format(checks,failures))
if failures>0 then os.exit(1) end
