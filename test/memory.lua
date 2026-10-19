-- Full addon in stub client, both directions, max user entry count, sustained input.
-- Counts Lua-managed bytes above the empty test process, not ESO's whole Lua VM.
collectgarbage('collect')
local base=collectgarbage('count')
local peak=base
local function sample()
 local current=collectgarbage('count')
 if current>peak then peak=current end
end
-- Sample real collector behavior without disabling collection or changing its tuning.
debug.sethook(sample,'',1000)
ADDON_DIR='.'
dofile('test/harness.lua')
local T=PBsTranslate
T.TranslateJaToEn('ヒーラーいますか')
local words={}
for i=1,T.USER_WORD_LIMIT do words['custom word '..i]='n:登録した用語'..i end
assert(T.SetUserEntries(words))
T.TranslateJaToEn('登録した用語1')
local lines={
 'I am out of magicka at roe',
 'we need you not to attack',
 'unless the healer is not ready attack',
 'if you need healing come here',
 'there are two enemies left at the gate',
 'can someone tell me where the group is',
 string.rep('the item that ',40)..'we have',
 string.rep('unknown ',250),
 string.rep('if we can heal ',35)..'wait',
}
local longest=0
for i=1,2000 do
 local start=os.clock()
 local result=T.Translate(lines[(i-1)%#lines+1])
 assert(type(result)=='string')
 longest=math.max(longest,os.clock()-start)
 sample()
 if i%500==0 then
  words['custom word 1']='n:更新'..i
  assert(T.SetUserEntries(words))
  T.TranslateJaToEn('ヒーラーいますか');sample()
 end
end
-- Verb entries expand into many reverse forms; test the supported weighted limit.
local verbs={}
local verbCount=math.floor(T.USER_WORD_LIMIT/12)
for i=1,verbCount do verbs['custom verb '..i]='v:仮登録'..i..'する/s' end
for i=1,T.USER_WORD_LIMIT-verbCount*12 do verbs['extra noun '..i]='n:追加名詞'..i end
assert(T.SetUserEntries(verbs))
T.TranslateJaToEn('ヒーラーいますか')
sample();debug.sethook()
collectgarbage('collect')
local retained=math.ceil((collectgarbage('count')-base)*1024)
local high=math.ceil((peak-base)*1024)
print(('memory: retained=%d bytes, sampled peak=%d bytes, longest instrumented translation=%.3f ms'):format(retained,high,longest*1000))
assert(high<=10000000,'sampled addon peak exceeds the 10 MB budget')
assert(retained<=8000000,'insufficient headroom for temporary translation memory')
