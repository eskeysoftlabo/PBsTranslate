dofile('test/engine.lua')
local T=LoadEngine()
local cases=dofile('test/slangnet_cases.lua')
local failures,checks=0,0
local function check(ok,detail)
 checks=checks+1
 if not ok then failures=failures+1;print('FAIL '..detail) end
end
for _,cyro in ipairs({false,true}) do
 T.SetCyrodiilPriority(cyro)
 for _,c in ipairs(cases) do
  local entry=T.Exact(c[2])
  local ja=c[4]:match('^[^/]+')
  check(entry and entry.ja==ja and entry.pos==c[3],c[1]..' dictionary')
  for _,s in ipairs({c[1],string.upper(c[1])}) do
   local got,stats=T.Translate(s)
   check(stats.unknown==0,s..' unknown: '..got)
   if c[3]=='x' or c[3]=='n' then check(got==ja,s..' -> '..got..' expected '..ja) end
  end
 end
end
local context={
 {'afc, bbol','操作から離れています、後でログインします'},
 {'I need a freebie','私は無料の品が必要です'},
 {'dont pubstomp','野良チームを圧倒しないでください'},
 {'we should pubstomp','私たちは野良チームを圧倒するべきです'},
 {'2ez, ta','楽勝、改めてありがとう'},
 {'tc, nntr','元気でね、返事は不要です'},
 {'I want a freebie','私は無料の品が欲しいです'},
 {'I need a qrg','私は簡易ガイドが必要です'},
}
for _,c in ipairs(context) do check(T.Translate(c[1])==c[2],'context '..c[1]) end
T.SetUserEntries({afc='x:ユーザー指定の離席'})
check(T.Translate('AFC')=='ユーザー指定の離席','user override')
T.SetUserEntries({})
print(('slangnet: %d checks, %d failures'):format(checks,failures))
if failures>0 then os.exit(1) end
