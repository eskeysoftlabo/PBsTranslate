-- Run with Lua 5.4 or LuaJIT from the addon directory.
dofile('test/engine.lua')
local T=LoadEngine()
local cases=dofile('test/slang_cases.lua')
local failures,checks=0,0
for _,case in ipairs(cases) do
 for _,cyro in ipairs({false,true}) do
  T.SetCyrodiilPriority(cyro)
  for _,input in ipairs({case[1],string.upper(case[1])}) do
   local result,stats=T.Translate(input)
   checks=checks+1
   if result~=case[2] or stats.unknown~=0 then
    failures=failures+1
    print('FAIL ['..tostring(cyro)..'] '..input..' -> '..result..' expected '..case[2]..' unknown '..stats.unknown)
   end
  end
 end
end
local function check(input,want)
    local got=T.Translate(input)
    checks=checks+1
    if got~=want then failures=failures+1;print('FAIL context '..input..' -> '..got..' expected '..want) end
end
T.SetCyrodiilPriority(false)
check('LF11M fresh prog','あと11人募集、最初からの攻略練習')
check('TYT, brb bio','ゆっくりでいいよ、トイレ休憩')
check('fake tank, no taunt','タンク役を偽ったプレイヤー、挑発なし')
check('hard stack, save ults','同じ位置にぴったり重なって集合、アルティメットを温存')
check('LF healer for a learning run','練習の回のためにヒーラーを探しています')
check('WTB mats, OBO','素材を買いたいです、価格相談可')
check('I need a pocket healer','私は専属ヒーラーが必要です')
check('first time here, still learning','ここは初めてです、まだ練習中です')
check('no cap, nice clutch','嘘じゃないよ、ナイス逆転')
check('LF crafter, have mats','クラフターを探しています、素材は持っています')
check('stop dps then rez me','攻撃を止めて、それから蘇生してください')
check('dont ignore adds','追加の敵を無視しないでください')
check('do not stop dps','攻撃を止めないでください')
check('no fake tank','タンク役を偽ったプレイヤーなし')
check('dont hard stack','同じ位置に密集しないでください')
check('we should hard stack','私たちは同じ位置に密集するべきです')
check('dont burn the boss','ボスに火力を集中しないでください')
check('no hard stack','密集しないでください')
check('I like cheese','私はチーズが好きです')
check('my cat is sleeping','私の猫は寝ています')
check('I want to go to a dungeon.','私はダンジョンに行きたいです。')
check('dw','二刀流')
T.SetCyrodiilPriority(true)
check('ult dump then push roe','アルティメットを一斉に使って、それからローベック砦を攻めてください')
check('break los then rez me','障害物で敵の射線を切って、それから蘇生してください')
check('save ults then hard stack','アルティメットを温存、それから同じ位置にぴったり重なって集合')
check('dont ult dump','アルティメットを一斉に使わないでください')
check('we should ult dump','私たちはアルティメットを一斉に使うべきです')
check('do not break los','障害物で敵の射線を切らないでください')
check('no ult dump','アルティメットを一斉に使わないでください')
check('bomb inc, spread','範囲バースト攻撃が来る、散開')
check('ms ls fs','鉱山サイドの製材所サイドの農場サイド')
check('bb','ブラックブート砦')
checks=checks+1;assert(T.Exact('wp').ja=='ウィンターズ・ピークス基地','Cyrodiil dictionary priority')
check('defend roe hk will bone','ローベック砦を防衛してください、砦を修理して味方を回復し、防衛を維持してください、全滅させます')
T.SetUserEntries({['ult dump']='x:合図A',['fresh prog']='n:練習会B'})
check('ult dump','合図A')
check('fresh prog','練習会B')
T.SetUserEntries({})
T.SetCyrodiilPriority(false)
-- Basic spellings must behave like the original words in sentences, too.
local spellings={w8='wait',gr8='great',rly='really',prolly='probably',plox='please',srs='serious',m8='mate'}
for _,cyro in ipairs({false,true}) do
    T.SetCyrodiilPriority(cyro)
    for short,full in pairs(spellings) do
        check(short,T.Translate(full))
        check(string.upper(short),T.Translate(full))
    end
end
T.SetCyrodiilPriority(false)
check('gtg, tc','もう行かないと、元気でね')
check('w8 for me','私を待ってください')
check('dont w8','待たないでください')
check('inv plox','招待してください')
check('rly good','本当にいい')
check('tcx','tcx')
T.SetUserEntries({tc='x:ユーザーの訳'})
check('tc','ユーザーの訳')
T.SetUserEntries({})
print('slang: '..checks..' checks, '..failures..' failures')
os.exit(failures==0 and 0 or 1)
