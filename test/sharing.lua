-- Two simulated players. Queue transport models asynchronous LGB delivery.
dofile('test/engine.lua');LoadEngine();dofile('ShareSession.lua')
local S=PBsTranslateShare
local checks=0
local function check(label,got,want)
    checks=checks+1
    assert(got==want,label..': got '..tostring(got)..', want '..tostring(want))
end
local function Pair()
    local now,queue,events,joined=0,{}, {},true
    local peers={}
    for _,name in ipairs({'@Alice','@Bob','@Observer'}) do
        local n=name
        peers[n]=S.New({now=function() return now end,name=function() return n end,
            member=function(p) return joined and peers[p]~=nil end,
            send=function(p) queue[#queue+1]={from=n,p=p};return true end,
            notify=function(event,state) events[#events+1]={name=n,event=event,state=state} end})
    end
    local function pump(filter)
        local iterations=0
        while #queue>0 do
            iterations=iterations+1;assert(iterations<2000,'unbounded queue')
            local item=table.remove(queue,1)
            if not filter or filter(item) then
                for name,peer in pairs(peers) do if name~=item.from then peer:Receive(item.from,item.p) end end
            end
        end
    end
    return peers['@Alice'],peers['@Bob'],peers['@Observer'],pump,
        function(n) now=now+n;for _,p in pairs(peers) do p:Tick() end end,
        function() joined=false end,events
end
local words={hk='v:防衛する/s',lessy='n:アレッシア砦',ham='n:ヴォレンドラング'}
local data,count=S.Encode(words)
check('entry count',count,3)
check('round trip Japanese',S.Decode(data,count).ham,words.ham)
check('duplicate key rejected',S.Decode('a\t訳\na\t別訳\n',2),nil)
check('truncated record rejected',S.Decode('a\t訳',1),nil)
check('wrong count rejected',S.Decode(data,2),nil)
for _,bad in ipairs({'x:|Hbad|h','v:壊す/invalid','\255','\237\160\128','a\nline'}) do
    check('reject unsafe entry',S.ValidEntry('test',bad),false)
end
check('empty dictionary',S.Encode({}),nil)
local large={};for i=1,201 do large['word'..i]='訳' end
check('entry limit',S.Encode(large),nil)
check('value length',S.ValidEntry('test',string.rep('あ',81)),false)
local merged,added,replaced,same,skip=S.Merge({a='古い',b='同じ'},{a='新しい',b='同じ',c='追加'},false)
check('keep conflict',merged.a,'古い');check('new count',added,1);check('same',same,1);check('skipped',skip,1)
merged,added,replaced=S.Merge({a='古い',manual='保持'},{a='新しい'},true)
check('overwrite choice',merged.a,'新しい');check('unrelated survives',merged.manual,'保持');check('overwrite count',replaced,1)

local a,b,observer,pump,tick,leave=Pair()
check('start',a:Start('@Bob',words),true);pump()
check('offer pending',b.active.accepted,nil);check('no data before consent',b.active.size,0)
check('not imported before acceptance',b.review,nil);check('observer excluded',observer.active,nil)
b:Accept();pump()
check('sender completes',a.active,nil);check('receiver ready for review',b.review.words.hk,words.hk)
check('no state retained as active',b.active,nil);check('observer has no review',observer.review,nil)
check('block incoming while review pending',b:Start('@Alice',words),false)

-- Packet and ACK loss, including the final ACK, are recovered without duplicate entries.
a,b,observer,pump,tick=Pair();a:Start('@Bob',words);pump();b:Accept()
local dropped=false
pump(function(item) if item.p.kind==S.DATA and not dropped then dropped=true;return false end;return true end)
check('data loss delays completion',b.review,nil);tick(31);pump()
check('data retry recovers',b.review.words.lessy,words.lessy)
a,b,observer,pump,tick=Pair();a:Start('@Bob',words);pump();b:Accept()
local droppedFinal=false
pump(function(item)
    if item.p.kind==S.ACK and item.p.seq>0 and item.p.seq*S.CHUNK>=#data and not droppedFinal then droppedFinal=true;return false end
    return true
end)
check('final ACK lost',a.active~=nil,true);tick(31);pump();check('final ACK retry completes',a.active,nil)
check('review still intact',b.review.words.ham,words.ham)

-- Decline, timeout, group departure and corrupted payloads never produce a review.
a,b,observer,pump,tick,leave=Pair();a:Start('@Bob',words);pump();b:Cancel();pump();check('decline stops sender',a.active,nil);check('decline no review',b.review,nil)
a,b,observer,pump,tick=Pair();a:Start('@Bob',words)
for i=1,5 do tick(31) end
check('bounded retries',a.active,nil)
a,b,observer,pump,tick,leave=Pair();a:Start('@Bob',words);pump();leave();tick(1);check('group departure',a.active,nil);check('no review after departure',b.review,nil)
a,b,observer,pump,tick=Pair();a:Start('@Bob',words);pump();b:Accept()
pump(function(item)
    if item.p.kind==S.DATA then item.p.text='X'..item.p.text:sub(2) end
    return true
end)
check('checksum failure',b.review,nil);check('checksum aborts sender',a.active,nil)

-- A third party cannot acknowledge another player's transaction.
a,b,observer,pump=Pair();a:Start('@Bob',words);pump()
a:Receive('@Observer',a:Packet('@Alice',a.active.sid,S.ACK,0))
check('ACK sender bound to peer',a.active.seq,0)
b:Receive('@Alice',{magic=S.MAGIC,target=S.Hash('@bob'),sid=a.active.sid,kind=S.DATA,seq=1,text='x'})
check('data before acceptance ignored',b.active.size,0)
b:Accept();pump()
local old=b.review
b:Receive('@Alice',a:Packet('@Bob',old.sid,S.DATA,999,'junk'))
check('late packet cannot replace review',b.review,old)

-- UTF-8 may straddle transport fragments; only complete dictionaries are decoded.
local boundary={['x']=string.rep('あ',70),['y']=string.rep('い',70)}
a,b,observer,pump=Pair();a:Start('@Bob',boundary);pump();b:Accept();pump()
check('split UTF8 reconstructed',b.review.words.x,boundary.x)
check('split UTF8 second entry',b.review.words.y,boundary.y)
print('sharing session: '..checks..' checks passed')
