dofile('test/engine.lua')
local T=LoadEngine()
local cases=dofile('test/refresh_cases.lua')
local checks,failures=0,0
local function check(ok,label)
 checks=checks+1
 if not ok then failures=failures+1;print('FAIL '..label) end
end
for _,cyro in ipairs({false,true}) do
 T.SetCyrodiilPriority(cyro)
 for _,c in ipairs(cases) do
  for _,s in ipairs({c[1],string.upper(c[1])}) do
   local got,stats=T.Translate(s);local want=cyro and c[3] or c[2]
   check(got==want and stats.unknown==0,s..' -> '..got..' expected '..want)
  end
 end
end
-- Unsupported input must not disappear or be assigned a confident invented meaning.
for _,s in ipairs({'out of zqxv','we are low on zqxv','tell me where zqxv is','we need zqxv to attack'}) do
 local got,stats=T.Translate(s)
 check(got:find('zqxv',1,true) and stats.unknown>0,'unknown preserved: '..s)
end
local link='|H1:item:123|h[Example Item]|h'
check(T.Translate('I need '..link):find(link,1,true)~=nil,'item link remains intact')
-- Speculation must be side-effect-free and not poison later calls or user priorities.
local items=T.Tag(T.Tokenize('we need you not to attack'))
local a=T.Semantic.Analyze(items,{});local b=T.Semantic.Analyze(items,{})
check(a and b and a.actionNegative and T.Semantic.Render(a,{})==T.Semantic.Render(b,{}),'repeatable semantic plans')
for _,item in ipairs(items) do check(not item.counted,'analysis did not mutate token counters') end
for key,value in pairs({['out of']='外側指定',left='左側指定',need='必要指定',down='下側指定'}) do
 T.SetUserEntries({[key]='n:'..value})
 check(T.Translate(key)==value,'user key '..key)
 local input=key=='need' and 'we need healing' or key=='down' and 'the gate is down' or key=='left' and 'two enemies left' or 'out of magicka'
 local _,stats=T.Translate(input)
 check(not stats.structured,'custom word bypasses inference '..key)
end
T.SetUserEntries({})
local big=string.rep('word ',900);local got,stats=T.Translate(big)
check(got==big and stats.limited=='bytes','oversize text is kept whole')
big=string.rep('a ',257);got,stats=T.Translate(big)
check(got==big and stats.limited=='tokens','token limit keeps original')
local words={};for i=1,T.USER_WORD_LIMIT do words['custom '..i]='n:用語'..i end
check(T.SetUserEntries(words)==true,'user dictionary at limit accepted')
words.extra='n:超過'
local previous=T.userLexicon
check(T.SetUserEntries(words)==false and T.userLexicon==previous,'oversize user dictionary rejected atomically')
check(not T.CheckUserWordBudget({key=string.rep('x',769)}),'value length limit')
local bytes={};for i=1,200 do bytes['long '..i]=string.rep('x',700) end
check(not T.CheckUserWordBudget(bytes),'total byte limit')
local verbs={};for i=1,167 do verbs['custom verb '..i]='v:仮登録'..i..'する/s' end
check(not T.CheckUserWordBudget(verbs),'conjugation expansion budget')
T.SetUserEntries({})
check(T.Translate('none of us can heal')=='私たちの誰も回復できません','dictionary reset restores baseline')
print(('refresh: %d fixtures, %d checks, %d failures'):format(#cases,checks,failures))
if failures>0 then os.exit(1) end
