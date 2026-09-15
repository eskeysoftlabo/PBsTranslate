-- Reviewed short-chat regressions: polarity, target, quantity and PvP context.
-- Run from the add-on folder: lua test/accuracy.lua (also supports LuaJIT/5.1).
local HERE = (debug.getinfo(1, "S").source:match("^@(.*)/") or ".")
dofile(HERE .. "/engine.lua")
local T = LoadEngine()
local checks, failures = 0, 0
local function check(label, got, want)
    checks = checks + 1
    if got ~= want then
        failures = failures + 1
        print("FAIL " .. label .. "\n  got: " .. tostring(got) .. "\n want: " .. tostring(want))
    end
end

T.SetCyrodiilPriority(true)
local cases = {
    -- Short questions only infer existence when the noun and tail are fully parsed.
    { "any healers?", "ヒーラーはいますか？" },
    { "any tanks online?", "オンラインのタンクはいますか？" },
    { "any repair kits?", "修理キットはありますか？" },
    { "any healers at roe?", "ローベック砦にヒーラーはいますか？" },
    { "any healer here?", "ここにヒーラーはいますか？" },
    { "any healers there?", "そこにヒーラーはいますか？" },
    { "anyone need a healer?", "誰か、ヒーラーが必要ですか？" },
    { "take any repair kits", "どれかの修理キットを取ってください" },
    { "any ZqxvPlayer?", "どれかのZqxvPlayer？" },
    { "healer here", "ここにヒーラーがいます" },
    { "enemy here", "ここに敵がいます" },
    { "repair kits here", "ここに修理キットがあります" },
    { "no healer here", "ここにヒーラーはいません" },
    { "no enemies here", "ここに敵はいません" },
    { "no repair kits here", "ここに修理キットはありません" },
    { "I am here", "私はここにいます" },
    { "Roe Southern wall", "ローベック砦の南の壁" },
    { "repair roe south wall", "ローベック砦の南の壁を修理してください" },
    { "repair roe north gate", "ローベック砦の北の門を修理してください" },
    { "roe east door", "ローベック砦の東の門" },
    { "go north", "北に行ってください" },
    { "two wardens", "ワーデン×2" },
    { "three wardens", "ワーデン×3" },
    { "go to warden", "ウォーデン砦に行ってください" },
    { "warden keep", "ウォーデン砦" },
    { "wait until everyone is ready", "みんなが準備できるまで、待ってください" },
    { "dont push until everyone is ready", "みんなが準備できるまで、攻めないでください" },
    { "if you are ready push fd", "もしあなたが準備できたら、正門を攻めてください" },
    { "if you are ready, push fd", "もしあなたが準備できたら、正門を攻めてください" },
    { "if you are not ready wait", "もしあなたが準備できなかったら、待ってください" },
    { "when everyone is ready push", "みんなが準備できるとき、攻めてください" },
    { "unless you are ready wait", "あなたが準備できなかったら、待ってください" },
    { "repair fd heal allies then defend roe", "正門を修理してください、味方を回復してください、それからローベック砦を防衛してください" },
    { "defend roe heal allies repair fd", "ローベック砦を防衛してください、味方を回復してください、正門を修理してください" },
    { "dont repair fd heal allies", "正門を修理しないでください、味方を回復してください" },
    { "if we defend roe we can win", "もし私たちがローベック砦を防衛したら、私たちは勝てます" },
    { "wait for heals then push fd", "回復を待ってください、それから正門を攻めてください" },

    { "I wanted you to wait", "私はあなたに待ってほしかったです" },
    { "I do not want you to wait", "私はあなたに待ってほしくないです" },
    { "dont be late", "遅くならないでください" },
    { "be careful", "気をつけて" },
    { "don't push fd", "正門を攻めないでください" },
    { "never attack the guards", "NPC衛兵を攻撃しないでください" },
    { "no siege", "包囲攻撃なし" },
    { "no more tanks", "これ以上のタンクなし" },
    { "no", "いいえ" },
    { "no thanks", "結構です" },
    { "no worries", "気にしないで" },
    { "we need no more healers", "私たちはこれ以上のヒーラーが必要ではありません" },
    { "nobody is defending roe", "誰もローベック砦を防衛していません" },
    { "nobody can heal", "誰も回復できません" },
    { "nothing is broken", "何も壊れていません" },
    { "I see nobody", "私は誰も見ません" },
    { "I know nothing", "私は何も知りません" },
    { "there are no enemies here", "ここに敵がいません" },
    { "I have no repair kits", "私は修理キットを持っていません" },
    { "not enough players", "プレイヤーが足りません" },
    { "stop attacking", "攻撃しないでください" },
    { "stop healing me", "私を回復しないでください" },
    { "stop attacking the guards", "NPC衛兵を攻撃しないでください" },
    { "keep healing", "回復し続けてください" },
    { "keep defending roe", "ローベック砦を防衛し続けてください" },
    { "keep moving", "動き続けてください" },
    { "dont stop healing", "回復するのをやめないでください" },
    { "we stopped attacking", "私たちは攻撃するのをやめました" },
    { "never stop healing", "回復するのをやめないでください" },
    { "we are not going to push", "私たちは攻めるつもりはありません" },
    { "we cannot defend roe", "私たちはローベック砦を防衛できません" },
    { "we should not push yet", "私たちはまだ攻めるべきではありません" },
    { "you must not be late", "あなたは遅くてはいけません" },
    { "you don't have to be a tank", "あなたはタンクでなくてもいいです" },
    { "Roe needs more help", "ローベック砦はもっと助けが必要です" },
    { "we need two more healers", "私たちはあとヒーラー×2が必要です" },
    { "need 2 tanks and 1 healer", "タンク×2とヒーラー×1が必要です" },
    { "lf 1 tank 2 dps", "タンク×1とDPS×2を探しています" },
    { "I'm a warden", "私はワーデンです" },
    { "we need a warden healer", "私たちはワーデンヒーラーが必要です" },
    { "warden lit", "ウォーデン砦は攻撃されています" },
    { "warden fd", "ウォーデン砦の正門" },
    { "don't stand in the red", "赤い範囲内に立たないでください" },
    { "wait for me", "私を待ってください" },
    { "I want you to wait", "私はあなたに待ってほしいです" },
    { "we want them to heal us", "私たちは彼らに私たちを回復してほしいです" },
    { "only attack the guards", "NPC衛兵だけを攻撃してください" },
    { "attack only the guards", "NPC衛兵だけを攻撃してください" },
    { "go to roe don't push", "ローベック砦に行ってください、攻めないでください" },
    { "we are outnumbered", "私たちは数で劣勢です" },
    { "don't leave me", "私を置き去りにしないでください" },
    { "don't hk", "砦の修理・味方の回復・防衛維持を行わないでください" },
    { "we will hk", "私たちは砦の修理・味方の回復・防衛維持を行います" },
    { "hk at roe", "ローベック砦で砦の修理・味方の回復・防衛維持を行ってください" },
    { "defend roe hk will bone", "ローベック砦を防衛してください、砦を修理して味方を回復し、防衛を維持してください、全滅させます" },
    { "defend roe - hk - will bone", "ローベック砦を防衛してください、砦を修理して味方を回復し、防衛を維持してください、全滅させます" },
    { "defend roe—hk—will bone", "ローベック砦を防衛してください、砦を修理して味方を回復し、防衛を維持してください、全滅させます" },
}
for _, case in ipairs(cases) do check(case[1], T.Translate(case[1]), case[2]) end

-- Polarity pairs must never collapse into the same instruction.
for _, pair in ipairs({
    { "push fd", "don't push fd" }, { "keep healing", "stop healing" },
    { "we are going to push", "we are not going to push" },
    { "we have repair kits", "we have no repair kits" },
    { "there are enemies here", "there are no enemies here" },
    { "hk", "don't hk" }, { "I know something", "I know nothing" },
}) do check(pair[1] .. " differs from its negative", T.Translate(pair[1]) ~= T.Translate(pair[2]), true) end

local markup = "|H1:item:12345|h[My Sword—Test]|h"
local result = T.Translate("please take " .. markup)
check("item link survives byte for byte", result:find(markup, 1, true) ~= nil, true)
check("unknown player name survives", T.Translate("heal ZqxvPlayer"):find("ZqxvPlayer", 1, true) ~= nil, true)
for _, text in ipairs({ "DON'T PUSH FD", "Don't Push Fd" }) do
    check("case " .. text, T.Translate(text), T.Translate("don't push fd"))
end

for _, cyrodiil in ipairs({ false, true }) do
    T.SetCyrodiilPriority(cyrodiil)
    check("warden context " .. tostring(cyrodiil), T.Translate("warden"), cyrodiil and "ウォーデン砦" or "ワーデン")
    T.SetUserEntries({ warden = "n:ユーザー指定", hk = "v:待つ/5", nobody = "n:登録名" })
    check("user warden has priority", T.Translate("warden"), "ユーザー指定")
    check("user hk has priority", T.Translate("don't hk"), "待たないでください")
    check("user negative-looking name has priority", T.Translate("nobody"), "登録名")
    T.SetUserEntries({})
end

-- Explicit user definitions must also survive the new context heuristics.
T.SetCyrodiilPriority(true)
T.SetUserEntries({ warden = "n:特別クラス", ready = "v:待つ/5", ["any healers"] = "x:登録した質問" })
check("custom quantified warden", T.Translate("two wardens"), "特別クラス×2")
check("custom complete question", T.Translate("any healers?"), "登録した質問？")
check("custom readiness predicate", T.Translate("wait until everyone is ready"), "みんなが待つまで、待ってください")
T.SetUserEntries({})

-- Stress noisy/malformed input and check useful output/stats, rather than its wording.
for _, text in ipairs({
    "", "???", "|Hbroken", "日本語🙂", string.rep("unknownword ", 100),
    string.rep("don't push fd; ", 40), "dont heal |cFF0000ZqxvPlayer|r!!!",
    "not enough mysterious supplies near roe", "5-10 players", "well-known player",
}) do
    local ok, ja, stats = pcall(T.Translate, text)
    check("input handled: " .. text:sub(1, 30), ok and type(ja) == "string" and type(stats) == "table", true)
    if ok then check("valid counts", stats.known >= 0 and stats.unknown >= 0, true) end
end
print(string.format("accuracy: %d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
