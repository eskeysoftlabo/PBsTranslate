-- Japanese -> English: the reverse dictionary, verb and adjective forms, and the reading of
-- particles and questions (JaToEn.lua).
--
--   lua test/ja_en.lua     (from the add-on folder; LuaJIT too)
--
-- Each line is what the reader makes of a chat line today. A change that alters one is either
-- a fix (update the line) or a regression. The hand-written /en callouts are in test/outgoing.lua.

ADDON_DIR = "."
dofile("test/harness.lua")
local T = PBsTranslate

local failures, checks = 0, 0
local function check(label, got, want)
	checks = checks + 1
	if got ~= want then
		failures = failures + 1
		print(string.format("FAIL %s  got=%s  want=%s", label, tostring(got), tostring(want)))
	end
end

local CASES = {
	{ "ケーキを食べたい", "I want to eat cake" },
	{ "今日はいい天気ですね", "good weather today" },
	{ "こんにちは、元気ですか", "hello, are you fine?" },
	{ "敵が来ている", "enemy is coming" },
	{ "私は日本人です", "I am japanese" },
	{ "明日行けますか", "can you go tomorrow?" },
	{ "昨日は忙しかった", "it was busy yesterday" },
	{ "それは強くない", "it is not strong" },
	{ "早く来て", "come early" },
	{ "一緒に行こう", "go together" },
	{ "何をしていますか", "what are you doing?" },
	{ "私はケーキが好きです", "I like cake" },
	{ "ケーキが好き", "I like cake" },
	{ "どこに行きますか", "where do you go?" },
	{ "何が欲しいですか", "what do you need?" },
	{ "誰が来ましたか", "who came?" },
	{ "遅れてごめん", "late, sorry" },
	{ "手伝ってくれませんか", "could you help?" },
	{ "このダンジョンは難しい", "this dungeon is hard" },
	{ "ヒーラーいますか", "any healer?" },
	{ "敵はいない", "no enemy" },
	{ "時間がありますか", "any time?" },
	{ "お金がない", "no money" },
	{ "馬に乗る", "ride horse" },
	{ "今日は楽しかった", "it was fun today" },
	{ "やばい", "omg" },
	{ "草", "lol" },
	{ "お腹すいた", "I'm hungry" },
	{ "準備できた", "ready" },
	{ "助かりました", "that helped, ty" },
	{ "何を買いたいですか", "what do you want to buy?" },
	{ "とても強い", "very strong" },
	{ "彼は強いです", "he is strong" },
	{ "装備を修理したい", "I want to repair gear" },
	{ "敵を倒した", "killed enemy" },
	{ "新しい剣を買った", "bought new sword" },
	{ "眠い", "sleepy" },
	{ "ダンジョンに行きたい", "I want to go to dungeon" },
	{ "少し待って", "wait a little" },
	{ "先に行って", "go ahead" },
	{ "後で戻ります", "return later" },
	{ "このクエストは難しいですか", "is this quest hard?" },
	{ "盾を持っています", "have shield" },
	{ "魔法を使えますか", "can you use magic?" },
	{ "日本から来ました", "came from japan" },
	{ "彼女はヒーラーです", "she is healer" },
	{ "明日は忙しい", "busy tomorrow" },
	{ "昨日ボスを倒しました", "killed boss yesterday" },
	{ "ありがとうございました", "thank you" },
	{ "最高", "awesome" },
	{ "ヒールお願いします", "heal" },
	{ "食べない", "don't eat" },
	{ "食べなかった", "didn't eat" },
	{ "食べています", "eating" },
	{ "食べられる", "can eat" },
	{ "食べよう", "let's eat" },
	{ "食べましょう", "let's eat" },
	{ "食べてください", "please eat" },
	{ "食べないでください", "don't eat" },
	{ "攻撃された", "was attacked" },
	{ "行かなければならない", "must go" },
	{ "彼はヒーラーですか", "is he healer?" },
	{ "食べたいですか", "do you want to eat?" },
	{ "食べましたか", "did you eat?" },
	{ "チャルマン砦の正門が攻撃されている", "chal fd lit" },
	{ "正門に破城槌が必要です", "need rams at fd" },
}

for _, case in ipairs(CASES) do
	local english, unknown = T.TranslateJaToEn(case[1])
	check(case[1], english, case[2])
	check(case[1] .. " fully read", #unknown, 0)
end

-- Unreadable text is reported, never guessed.
do
	local english, unknown, known = T.TranslateJaToEn("ホゲホゲ")
	check("unreadable gives nothing", english, "")
	check("unreadable reported", table.concat(unknown, "/"), "ホゲホゲ")
	check("unreadable counts nothing", known, 0)
	english, unknown = T.TranslateJaToEn("ありがとう、ホゲホゲ")
	check("partly readable keeps the rest", english, "ty")
	check("partly readable reports the rest", table.concat(unknown, "/"), "ホゲホゲ")
end

-- The cheapest reading wins: 今日|は|いい, not 今日|はい|い; 敵|は|いない, not 敵|はい|ない.
do
	local function Keys(text)
		local keys = {}
		for _, piece in ipairs(T.JaSegment(text)) do keys[#keys + 1] = piece.key end
		return table.concat(keys, "|")
	end
	check("segment today", Keys("今日はいい天気ですね"), "今日|は|いい|天気|です|ね")
	check("segment no enemy", Keys("敵はいない"), "敵|は|いない")
	check("segment yes alone", Keys("はい"), "はい")
end

-- The player's own words are read back too, and win; removing them gives the dictionary back.
do
	T.SetUserEntries({ ["hoge night"] = "n:ホゲホゲ", ["noodle"] = "n:ケーキ" })
	check("user noun read back", (T.TranslateJaToEn("ホゲホゲ")), "hoge night")
	check("user word wins", (T.TranslateJaToEn("ケーキを食べたい")), "I want to eat noodle")
	T.SetUserEntries({})
	check("user word removed", (T.TranslateJaToEn("ケーキを食べたい")), "I want to eat cake")
	check("user noun gone", (T.TranslateJaToEn("ホゲホゲ")), "")
end

-- English inflection of the verb forms.
check("irregular past", (T.TranslateJaToEn("行った")), "went")
check("regular past, doubled", (T.TranslateJaToEn("止めた")) ~= "", true)

-- Every result is valid UTF-8 and ASCII English, whatever goes in.
for _, text in ipairs({ "ぅぁ、だ", "ｗ", "。。。", "ー", "a", "日本語とEnglishのmix", string.rep("ケーキ", 40) }) do
	local english, unknown = T.TranslateJaToEn(text)
	local valid = T.IsValidUTF8(english)
	for _, piece in ipairs(unknown) do valid = valid and T.IsValidUTF8(piece) end
	check("valid UTF-8 for " .. text:sub(1, 30), valid, true)
	check("ASCII English for " .. text:sub(1, 30), english:find("[\128-\255]") == nil, true)
end

if failures > 0 then
	print(failures .. " FAILED")
	os.exit(1)
end
print("ja->en: " .. checks .. " checks, 0 failures")
