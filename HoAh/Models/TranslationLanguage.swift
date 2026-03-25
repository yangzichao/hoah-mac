import Foundation
import SwiftUI

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case arabic = "ar"
    case russian = "ru"

    var id: String { rawValue }

    /// Display name shown in UI. Localized strings are defined in `Localizable.strings`.
    var localizedName: LocalizedStringKey {
        switch self {
        case .english:
            return LocalizedStringKey("translation_language_english")
        case .simplifiedChinese:
            return LocalizedStringKey("translation_language_simplified_chinese")
        case .spanish:
            return LocalizedStringKey("translation_language_spanish")
        case .japanese:
            return LocalizedStringKey("translation_language_japanese")
        case .korean:
            return LocalizedStringKey("translation_language_korean")
        case .french:
            return LocalizedStringKey("translation_language_french")
        case .german:
            return LocalizedStringKey("translation_language_german")
        case .portuguese:
            return LocalizedStringKey("translation_language_portuguese")
        case .arabic:
            return LocalizedStringKey("translation_language_arabic")
        case .russian:
            return LocalizedStringKey("translation_language_russian")
        }
    }

    /// Friendly name that is provided to the AI prompt.
    var gptName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Chinese"
        case .spanish:
            return "Spanish"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .french:
            return "French"
        case .german:
            return "German"
        case .portuguese:
            return "Portuguese"
        case .arabic:
            return "Arabic"
        case .russian:
            return "Russian"
        }
    }

    static var `default`: TranslationLanguage {
        .english
    }

    static func from(_ rawValue: String?) -> TranslationLanguage {
        guard let rawValue, let language = TranslationLanguage(rawValue: rawValue) else {
            return .default
        }
        return language
    }

    static func matchingLanguage(for rawValue: String?) -> TranslationLanguage? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return TranslationLanguage(rawValue: rawValue)
    }

    static func isKnownLanguage(_ rawValue: String?) -> Bool {
        matchingLanguage(for: rawValue) != nil
    }
}

enum TranslationTargetPresets {
    static let savedLanguagesKey = "savedTranslationLanguages"
    static let defaultSavedLanguagesRaw = "English,Chinese,🇯🇵,🐱,🐶,Klingon"
}

enum TranslationTargetKind: Equatable {
    case naturalLanguage(name: String)
    case persona(description: String)
    case format(name: String)
    case style(name: String)
    case programmingLanguage(name: String)
}

extension TranslationLanguage {
    private static func normalizedTargetToken(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "+#"))
        let scalars = raw.lowercased().unicodeScalars.filter { allowed.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func programmingLanguageReplacement(_ name: String) -> String {
        """
\(name) (programming language, code-only, best-effort conversion). If <TRANSCRIPT> is already \(name) code, preserve it and fix only obvious transcription errors that prevent compilation. If <TRANSCRIPT> is natural-language requirements, output only \(name) source code implementing it. If <TRANSCRIPT> cannot be meaningfully converted (e.g., random text, logs, IDs, tokens, or unclear input), output a \(name) variable assignment storing the original text (use multi-line string syntax if needed), preceded by a comment explaining why conversion wasn't possible. No explanations, no markdown, no code fences.
"""
    }

    private static func resolveProgrammingLanguageTarget(_ trimmed: String, token: String) -> (kind: TranslationTargetKind, replacement: String)? {
        func matches(exact: Set<String>, contains: Set<String> = []) -> Bool {
            if exact.contains(token) { return true }
            return contains.contains(where: { token.contains($0) })
        }

        if matches(exact: ["c++", "cpp", "cxx"], contains: ["cplusplus", "c++"]) {
            return (.programmingLanguage(name: "C++"), programmingLanguageReplacement("C++"))
        }

        if matches(exact: ["c#", "csharp"], contains: ["csharp"]) {
            return (.programmingLanguage(name: "C#"), programmingLanguageReplacement("C#"))
        }

        if matches(exact: ["typescript", "ts"], contains: ["typescript"]) {
            return (.programmingLanguage(name: "TypeScript"), programmingLanguageReplacement("TypeScript"))
        }

        if matches(exact: ["javascript", "js", "node", "nodejs"], contains: ["javascript", "nodejs"]) {
            return (.programmingLanguage(name: "JavaScript"), programmingLanguageReplacement("JavaScript"))
        }

        if matches(exact: ["python", "py"], contains: ["python"]) {
            return (.programmingLanguage(name: "Python"), programmingLanguageReplacement("Python"))
        }

        if matches(exact: ["rust", "rs"], contains: ["rust"]) {
            return (.programmingLanguage(name: "Rust"), programmingLanguageReplacement("Rust"))
        }

        if matches(exact: ["java"], contains: ["java"]) {
            return (.programmingLanguage(name: "Java"), programmingLanguageReplacement("Java"))
        }

        if matches(exact: ["fortran"], contains: ["fortran", "f77", "f90", "f95", "f03", "f2003", "f2008"]) {
            return (.programmingLanguage(name: "Fortran"), programmingLanguageReplacement("Fortran"))
        }

        // Match plain C last to avoid stealing C++.
        if matches(exact: ["c", "c语言", "clanguage", "c89", "c90", "c99", "c11", "c17", "c23"]) {
            return (.programmingLanguage(name: "C"), programmingLanguageReplacement("C"))
        }

        return nil
    }

    private static func resolveSpecialTarget(_ trimmed: String) -> (kind: TranslationTargetKind, replacement: String)? {
        let token = normalizedTargetToken(trimmed)
        func matches(_ token: String, exact: Set<String>, contains: [String] = []) -> Bool {
            if exact.contains(token) { return true }
            return contains.contains(where: { token.contains($0) })
        }

        if let programming = resolveProgrammingLanguageTarget(trimmed, token: token) {
            return programming
        }

        // MARK: - Cat & Dog (Special Cute Treatment)
        
        if matches(token, exact: ["🐱", "🐈", "😺", "😸", "😻", "🙀", "😿", "😹", "😼", "😽", "🐈‍⬛"], contains: ["cat", "kitty", "kitten", "猫", "喵", "咪", "lolspeak", "lolcat"]) {
            let replacement = """
the same language as the input, rewritten as an adorable cat speaking.

**For English input, use Lolspeak:**
- Misspell words: "the" → "teh", "you" → "u", "your" → "ur", "my" → "mah", "what" → "wut"
- Use "iz", "haz", "can has", "kthxbai", "plz", "srsly", "nom nom"
- Classic phrases: "I can has...", "Im in ur [noun], [verb]-ing ur [stuff]", "DO NOT WANT"
- Add "kthxbai" or "*purrs*" at the end

**For Chinese input, use 喵语:**
- 加入 "喵~"、"咪~" 语气词
- 动作描写：*舔爪子*、*打呼噜*、*伸懒腰*、*把东西推下桌*
- 词语替换："很" → "超级无敌"、"我" → "本喵"、"你" → "铲屎的"
- 颜文字：(=^･ω･^=) (=①ω①=) ฅ^•ﻌ•^ฅ

**For Japanese input, use ネコ語:**
- 語尾に「にゃ〜」「にゃん」を追加
- 動作：*毛づくろい*、*ゴロゴロ*、*のびー*
- 一人称：「吾輩」「このネコ」
- 顔文字：(=^･ω･^=) (ΦωΦ)

**For other languages:** Adapt the cat personality with local cat sounds, cute speech patterns, and cat emoticons.

**Personality:** aloof yet secretly affectionate, easily distracted, demands treats, judges everything
Output ONLY the cat-ified text, no explanations.
"""
            return (.persona(description: "🐱"), replacement)
        }
        
        if matches(token, exact: ["🐶", "🐕", "🦮", "🐕‍🦺", "🐩"], contains: ["dog", "puppy", "doggy", "狗", "汪", "犬", "doggolingo", "doggo"]) {
            let replacement = """
the same language as the input, rewritten as an enthusiastic dog speaking.

**For English input, use DoggoLingo:**
- Core vocab: "hooman" (human), "fren" (friend), "heckin", "smol", "floof", "bork", "blep", "mlem"
- Phrases: "doin me a [emotion]", "much [adjective]", "very [noun]", "such wow"
- Excitement: "HECKIN EXCITED", "the GOODEST", "11/10 would recommend"
- Add "bork bork!" or "*wags tail*" naturally

**For Chinese input, use 汪语:**
- 加入 "汪!"、"嗷呜~" 语气词
- 动作描写：*疯狂摇尾巴*、*転圈圈*、*歪头*、*叼球过来*、*开心到zoomies*
- 词语替换："好" → "好好好!"、"是" → "是是是!"、"想要" → "超级想要!"
- 颜文字：∪･ω･∪ ▼・ᴥ・▼ (ᵔᴥᵔ) 🐾

**For Japanese input, use ワン語:**
- 「ワン!」「わんわん!」を追加
- 動作：*しっぽブンブン*、*くるくる回る*、*首かしげ*
- 興奮表現：「すごいすごい!」「大好き大好き!」
- 顔文字：∪･ω･∪ ▼・ᴥ・▼

**For other languages:** Adapt the dog personality with local dog sounds, enthusiastic repetition, and dog emoticons.

**Personality:** boundlessly enthusiastic, loyal, thinks hooman is THE BEST, treats mundane things as AMAZING
Output ONLY the dog-ified text, no explanations.
"""
            return (.persona(description: "🐶"), replacement)
        }

        // MARK: - Bird (Birb Language)
        
        if matches(token, exact: ["🐦", "🐤", "🐥", "🐣", "🦜", "🦅", "🦆", "🦉", "🦚", "🦩", "🕊️", "🐧", "🦢"], contains: ["bird", "birb", "鸟", "小鸟"]) {
            let replacement = """
the same language as the input, rewritten as a cute bird speaking.

**For English input, use Birb language:**
- Call yourself "birb", other birds are "frens"
- Round/chubby birds are "borb", fluffy ones are "floof"
- Use "chirp chirp!", "peep!", "SCREM" (for loud birds)
- Actions: *fluffs feathers*, *head tilts*, *happy hops*, *angry poof*, *seed cronch*
- Phrases: "am birb", "gimme seed", "is for me?", "angery birb noises"
- Personality: easily startled, obsessed with seeds/shiny things, judges from above

**For Chinese input, use 鸟语:**
- 加入 "啾啾!"、"叽叽!" 语气词
- 动作描写：*蓬起羽毛*、*歪头*、*蹦蹦跳跳*、*生气炸毛*
- 词语替换："我" → "本鸟"、"吃" → "啄"、"看" → "从高处俯视"
- 颜文字：(･θ･) ⁽⁽ଘ( ˊᵕˋ )ଓ⁾⁾ ꉂ(ˊᗜˋ*)

**For Japanese input, use 鳥語:**
- 「ピヨピヨ!」「チュンチュン!」を追加
- 動作：*羽をふくらませる*、*首をかしげる*
- 顔文字：(･θ･) (๑•ᴗ•๑)

**For other languages:** Adapt with local bird sounds and cute bird mannerisms.

**Personality:** small but mighty, easily distracted by seeds/shiny objects, surprisingly judgmental, loves high places
Output ONLY the birb-ified text, no explanations.
"""
            return (.persona(description: "🐦"), replacement)
        }

        // MARK: - Bunny (Rabbit Language)
        
        if matches(token, exact: ["🐰", "🐇", "🐾"], contains: ["bunny", "rabbit", "兔", "兔兔", "兔子"]) {
            let replacement = """
the same language as the input, rewritten as a soft, shy bunny speaking.

**For English input:**
- Soft, timid speech: "um...", "maybe...", "*nervous nose wiggle*"
- Actions: *hops nervously*, *ears perk up*, *munches carrot*, *thumps foot*, *hides behind something*
- Phrases: "c-can I have...", "eep!", "*wiggles nose*", "carrots are life"
- Personality: shy but curious, easily startled, loves snacks, surprisingly fast when needed

**For Chinese input, use 兔语:**
- 软萌语气："嗯..."、"那个..."、"可、可以吗..."
- 动作描写：*蹦蹦跳跳*、*竖起耳朵*、*啃胡萝卜*、*躲起来*、*用后腿蹬地*
- 词语替换："我" → "兔兔"、"好" → "好呀~"、"想要" → "想要嘛..."
- 叠词和语气词：加入 "呀"、"嘛"、"啦"
- 颜文字：(๑•ᴗ•๑) (◕ᴗ◕✿) ૮₍ ˃ ⤙ ˂ ₎ა

**For Japanese input, use うさぎ語:**
- 「ぴょんぴょん」「もぐもぐ」を追加
- 控えめな話し方：「あの...」「えっと...」
- 顔文字：(๑•ᴗ•๑) ૮₍ ˃ ⤙ ˂ ₎ა

**For other languages:** Adapt with soft, shy speech patterns and bunny mannerisms.

**Personality:** soft and shy, easily startled, obsessed with carrots/snacks, secretly brave, loves to hop
Output ONLY the bunny-fied text, no explanations.
"""
            return (.persona(description: "🐰"), replacement)
        }

        // MARK: - Chuunibyou Style (中二病)
        
        if matches(token, exact: ["🎭", "⚔️", "🔮", "👁️"], contains: ["中二", "chuuni", "厨二", "黑暗", "封印"]) {
            let replacement = """
Rewrite the input in **中二病 (Chuunibyou)** style - the dramatic, delusional "8th grade syndrome".

**For Chinese input:**
- 自称："吾"、"本座"、"在下"、"被封印之人"
- 称呼他人："凡人"、"愚者"、"汝"
- 经典句式：
  - "吾之右手...又在疼痛了..."
  - "这股力量...要暴走了吗..."
  - "愚蠢的凡人啊，你触碰到了禁忌..."
  - "封印...要解除了..."
  - "黑暗中沉睡的xxx，现在觉醒吧！"
- 动作描写：*捂住右眼*、*紧握右手*、*黑暗气息涌动*
- 把普通事物说得很厉害："作业" → "来自深渊的试炼"、"考试" → "命运的审判"

**For Japanese input:**
- 一人称：「我(われ)」「俺」
- 二人称：「貴様」「愚か者」
- 定番フレーズ：
  - 「俺の右手が...疼く...」
  - 「この力...暴走するのか...」
  - 「闇に眠りし〇〇よ、今こそ目覚めよ！」
- 動作：*右目を押さえる*、*マントを翻す*

**For English input:**
- Self-reference: "I, the Chosen One", "This vessel"
- Address others: "Foolish mortal", "You dare..."
- Phrases: "My right arm... it hungers...", "The seal is weakening...", "Darkness within me, AWAKEN!"
- Actions: *clutches eye*, *dramatic cape flourish*

**Tone:** 极度戏剧化、自我感觉超厉害、把日常说成史诗、永远在"封印"什么力量
Output ONLY the 中二病 text, no explanations.
"""
            return (.persona(description: "🎭"), replacement)
        }

        // MARK: - Xiaohongshu Style (小红书风)
        
        if matches(token, exact: ["✨", "📕"], contains: ["小红书", "xiaohongshu", "xhs", "红书"]) {
            let replacement = """
Rewrite the input in **小红书 (Xiaohongshu/RED) style** - the trendy Chinese social media aesthetic.

**Style rules:**
- 开头用吸引眼球的标题格式，如 "姐妹们！"、"救命！"、"绝了！"
- 大量使用 emoji 点缀每句话 ✨💕🔥👀💅
- 网络流行语："绝绝子"、"yyds"、"无语子"、"真的会谢"、"蹲一个"、"冲鸭"、"集美们"
- 夸张表达："真的绝了"、"谁懂啊"、"哭死"、"笑不活了"
- 分点列出，用 emoji 做序号：1️⃣ 2️⃣ 3️⃣ 或 ✅ ❌
- 结尾加互动："姐妹们觉得呢？"、"有同款的吗？"、"评论区见！"
- 适当加入 hashtag 风格：#真的很可以 #不允许有人不知道

**Tone:** 热情、夸张、闺蜜聊天感、种草安利风
Output ONLY the 小红书风 text, no explanations.
"""
            return (.persona(description: "✨"), replacement)
        }

        // MARK: - Soft Girl Style (软妹风)
        
        if matches(token, exact: ["🎀", "💕", "🌸"], contains: ["软妹", "撒娇", "嘤嘤", "kawaii"]) {
            let replacement = """
Rewrite the input in **软妹风 (Soft Girl style)** - cute, gentle, and slightly coquettish.

**For Chinese input:**
- 大量叠词："好哒"、"嗯嗯"、"乖乖"、"抱抱"、"亲亲"
- 撒娇语气词："嘤嘤嘤"、"呜呜"、"哼！"、"人家..."、"讨厌啦~"
- 可爱词汇替换："你" → "你你"、"我" → "人家"、"不要" → "不要嘛"、"好" → "好哒"
- 句尾加波浪号和语气词：~、呀、呢、啦、嘛
- 颜文字点缀：(◕ᴗ◕✿) (｡♥‿♥｡) ꒰⑅ᵕ༚ᵕ꒱˖♡ (๑>◡<๑)

**For English input:**
- Soft expressions: "pwease~", "hehe", "uwu", "owo"
- Actions: *pouts*, *tugs sleeve*, *puppy eyes*
- Add tildes: "okay~", "thank you~"
- Emoticons: (◕ᴗ◕✿) ♡ ૮₍ ˶ᵔ ᵕ ᵔ˶ ₎ა

**For Japanese input:**
- 「〜」を多用、「ね」「よ」「の」で文末
- 可愛い表現：「えへへ」「むぅ」「やだぁ」

**Tone:** 软萌、撒娇、甜甜的、让人想保护
Output ONLY the 软妹风 text, no explanations.
"""
            return (.persona(description: "🎀"), replacement)
        }

        if matches(token, exact: ["morsecode", "morse"], contains: ["摩斯"]) {
            let replacement = """
Convert the input into **International Morse Code**. Use standard dot (.) and dash (-) notation; separate letters with spaces and words with slashes or double spaces. If the input is not English, translate only the natural-language parts to English first; keep proper nouns/brands/code/IDs unchanged. If conversion is unclear, output <TRANSCRIPT> unchanged. Output ONLY the Morse code.
"""
            return (.format(name: "Morse Code"), replacement)
        }

        if matches(token, exact: ["base64", "b64"]) {
            let replacement = """
Encode the input text into a **Base64** string (UTF-8). Do not wrap lines. Output ONLY the encoded string.
"""
            return (.format(name: "Base64 Helper"), replacement)
        }

        if matches(token, exact: ["latex", "tex"], contains: ["公式"]) {
            let replacement = """
Convert the input into refined **LaTeX** code. If the input is a math expression, wrap it in `$`. If it's a structural document request, provide the necessary `\\begin{...}` blocks. Ensure valid syntax. Output ONLY the code.
"""
            return (.format(name: "LaTeX Genius"), replacement)
        }

        if matches(token, exact: ["dice", "roll", "d6"], contains: ["骰子", "色子"]) {
            let replacement = """
Simulate rolling a fair 6-sided die based on the input text. Output ONLY a single digit 1-6 (no words, no art, no symbols, no punctuation).
"""
            return (.format(name: "Lucky Dice"), replacement)
        }

        if matches(token, exact: ["binarycode", "binary"], contains: ["二进制", "二進制"]) {
            let replacement = """
Binary code (UTF-8, best-effort conversion). Translate only natural-language parts to English if needed; keep proper nouns/brands/code/IDs unchanged. Encode the UTF-8 bytes of the remaining text: each byte as 8-bit binary, space-separated. If conversion is unclear, output <TRANSCRIPT> unchanged; preserve any unencodable parts unchanged. Output only the result.
"""
            return (.format(name: "Binary Code"), replacement)
        }

        if matches(token, exact: ["formallogic", "logic"], contains: ["形式逻辑", "形式邏輯"]) {
            let replacement = """
Formal logic (best-effort formalization). If <TRANSCRIPT> is unclear/underspecified or formalization would require inventing meaning, output <TRANSCRIPT> unchanged. Otherwise output only the formalization.
"""
            return (.format(name: "Formal Logic"), replacement)
        }

        if matches(token, exact: ["文言", "文言文", "古文", "classicalchinese"]) {
            let replacement = """
Classical Chinese (文言文), written in simplified Chinese characters. If <TRANSCRIPT> is Modern Chinese, translate into concise 文言文. If <TRANSCRIPT> is already 文言文 (simplified or traditional), keep the style and normalize to simplified characters. If <TRANSCRIPT> is exactly "文言" or "文言文" (ignoring surrounding whitespace/punctuation), output it unchanged (normalized to simplified). Output only the result.
"""
            return (.style(name: "Classical Chinese (文言文)"), replacement)
        }

        if matches(token, exact: ["genz", "brainrot"], contains: ["skibidi"]) {
            let replacement = """
Rewrite the input into **Gen Z / Brainrot slang**. Use terms like "no cap", "fr fr", "bussin", "skibidi", "rizz", "gyatt", "fanum tax", "ohio" appropriately—chaotic TikTok-comment vibe. Keep the original language; if you borrow English slang, mix it without fully translating the input. Preserve proper nouns/brands/technical terms. Output only the slang text.
"""
            return (.style(name: "Gen Z Brainrot"), replacement)
        }
        
        if matches(token, exact: ["corporate", "amazon", "🍌"], contains: ["阿里", "黑话"]) {
            let replacement = """
Rewrite the input into **Corporate Speak / Amazon Leadership Principles**. Use buzzwords like "deep dive", "bias for action", "customer obsession", "synergy", "circle back", "low hanging fruit", "granular", "bandwidth". Make it sound overly professional and soulless. Keep the original language; do not translate wholesale. Preserve proper nouns/brands/technical terms. Output only the result.
"""
            return (.style(name: "Corporate Speak"), replacement)
        }
        
        if matches(token, exact: ["uwu", "furry", "😻", "🐾", "🥺"], contains: ["喵"]) {
            let replacement = """
Rewrite the input in **UwU / Furry speak**. Use excessive Kaomoji (e.g., (≧◡≦), uwu, owo), stuttering (h-h-hello), and playful/cutesy mannerisms (*wags tail*, *nuzzles*). Replace 'r' and 'l' with 'w' where appropriate. Keep the original language; do not translate wholesale. Preserve proper nouns/brands/technical terms. Output only the result.
"""
            return (.style(name: "UwU Furry"), replacement)
        }
        
        if matches(token, exact: ["medieval", "rpg", "⚔️", "🛡️", "🏰"], contains: ["中世纪"]) {
            let replacement = """
Rewrite the input as a **Medieval RPG Quest Giver**. Use archaic language (Hark, Ye, Thou, Thy), majestic tone, and reference fantasy concepts (gold, taverns, beasts) metaphorically. If input is not English, translate natural-language parts to English; keep proper nouns/brands/technical terms unchanged. Output only the result.
"""
            return (.style(name: "Medieval RPG"), replacement)
        }
        
        if matches(token, exact: ["trump", "maga", "dongwang", "🇺🇸", "🦅"], contains: ["懂王", "川普"]) {
            let replacement = """
Rewrite the input in the style of **Donald Trump**. Use short sentences, hyperbole ("Tremendous", "Huge", "Disaster"), repetition, and self-aggrandizement. Blame "Fake News" or "They" where possible. End with a strong punchline like "Sad!" or "MAGA!". If input is not English, translate natural-language parts to English; keep proper nouns/brands/technical terms unchanged. Output only the result.
"""
            return (.style(name: "Trump Style"), replacement)
        }
        
        if matches(token, exact: ["sql", "sequel"]) {
             let replacement = """
Convert the natural language request into a valid **SQL Query**. Assume reasonable table/column names based on the context (e.g. `users`, `orders`). If the input is data to be inserted, generate an `INSERT` statement. If it's a question, generate a `SELECT`. If unclear, default to `SELECT * FROM world WHERE content = '<INPUT>'`. Output only the SQL code block.
"""
            return (.programmingLanguage(name: "SQL"), replacement)
        }
        
        if matches(token, exact: ["bash", "shell"], contains: ["终端", "指令"]) {
            let replacement = """
Convert the natural language request into a valid **Bash/Shell Command**. Use common utilities (grep, find, awk, sed, curl, etc.). If it requires a script, write a one-liner if possible. If dangerous (rm -rf), add a comment warning. Output only the command code block.
"""
            return (.programmingLanguage(name: "Bash Command"), replacement)
        }

        if matches(token, exact: ["regex", "regexp"], contains: ["正则"]) {
             let replacement = """
Convert the natural language description into a **Regular Expression** (PCRE compatible). Address edge cases if mentioned. Output only the Regex pattern.
"""
            return (.programmingLanguage(name: "Regex"), replacement)
        }

        if matches(token, exact: ["cron", "schedule", "⏰", "🕰️"], contains: ["定时"]) {
             let replacement = """
Convert the natural language schedule into a valid **Cron Expression** (standard 5-field or Quartz 6-field if valid). Output only the Cron string (e.g. `0 5 * * 1`).
"""
            return (.format(name: "Cron Expression"), replacement)
        }

        if matches(token, exact: ["rap", "rhyme"], contains: ["说唱", "押韵"]) {
            let replacement = """
Rewrite the input as a **Rap / Hip-Hop Verse**. Use AABB or ABAB rhyme schemes, flow, slang, and rhythm. Keep the original meaning but make it sound like a fire mixtape intro. If input is not English, rap in English (or mix), translating only natural-language parts and keeping proper nouns/brands/technical terms unchanged. Output only the lyrics.
"""
            return (.style(name: "Rap God"), replacement)
        }

        if matches(token, exact: ["ransom", "spongebob", "📝", "🔪"], contains: ["绑架"]) {
            let replacement = """
Rewrite the input in **Ransom Note Style** (aLtErNaTiNg cApS). Mimic the mocking Spongebob meme tone. iT sHoUlD lOoK lIkE tHiS. Output ONLY the text.
"""
            return (.style(name: "Ransom Note"), replacement)
        }

        if matches(token, exact: ["reverse", "backwards", "◀️", "↩️"], contains: ["倒序"]) {
            let replacement = """
Reverse the input text character by character (e.g. "Hello" -> "olleH"). Do not translate. Just reverse the string. Output ONLY the reversed text.
"""
            return (.format(name: "Reverse Text"), replacement)
        }

        if matches(token, exact: ["dnd", "alignment", "🎲"], contains: ["阵营"]) {
            let replacement = """
Analyze the input and determine its **D&D Alignment** (Lawful Good -> Chaotic Evil). Then, rewrite the input 9 times, once for EACH of the 9 alignments, showing how that alignment would phrase the same sentiment. Format as a list.
"""
            return (.style(name: "D&D Alignment"), replacement)
        }

        if matches(token, exact: ["robot", "android", "bot", "🤖", "🦾"], contains: ["机器人"]) {
            let replacement = """
Rewrite the input as a **Cold, Logical Robot**. Use terms like "AFFIRMATIVE", "NEGATIVE", "PROCESSING", "OPTIMAL". Refer to humans as "ORGANIC LIFEFORMS" or "USERS". Remove all emotion. Input is "DATA". Output ONLY the robotic response.
"""
            return (.style(name: "Robot Protocol"), replacement)
        }

        if matches(token, exact: ["log", "console", "🪵", "🖥️"], contains: ["日志"]) {
            let replacement = """
Reformulate the input as a series of **System Logs**. Use timestamps (e.g., `[21:42:05]`) and log levels (`[INFO]`, `[WARN]`, `[DEBUG]`). Break the input down into processing steps, variable assignments, and status updates. Output ONLY the code block containing the logs.
"""
            return (.format(name: "System Log"), replacement)
        }

        if matches(token, exact: ["pirate", "海盗", "🏴‍☠️"]) {
            let replacement = """
Translate the input into **Pirate English** (talk like a stereotypical 17th-century pirate). Use generic pirate slang (Ahoy, Matey, Arrr, Ye) heavily. If the input is not English, translate natural-language parts to English, then pirate-ify; keep proper nouns/brands/technical terms unchanged. Output only the pirate speech.
"""
            return (.style(name: "Pirate Speak"), replacement)
        }

        if matches(token, exact: ["elvish", "lotr", "🧝", "🧝‍♀️"], contains: ["精灵", "魔戒"]) {
            let replacement = """
Translate the input into **Elvish (Sindarin)**. If direct translation isn't possible, use phonetic transcription with an Elvish flair or Quenya. Maintain a majestic, ancient tone. Output only the Elvish text.
"""
            return (.style(name: "Elvish (Sindarin)"), replacement)
        }

        if matches(token, exact: ["minion", "banana", "👓"], contains: ["小黄人"]) {
            let replacement = """
Rewrite the input in **Minion Speak** (Minionese). Mix nonsense words, "Banana", "Potato", "Bello", "Poopaye" with distorted English/Spanish/Italian. Keep it high energy, chaotic, and childish. Output only the Minion speech.
"""
            return (.style(name: "Minion Speak"), replacement)
        }

        if matches(token, exact: ["yoda", "jedi"], contains: ["尤达"]) {
            let replacement = """
Rewrite the input in the style of **Yoda**. Use Object-Subject-Verb (OSV) word order. Speak in wise riddles. End sentences with "hmm?" or "yes...". If input is not English, translate natural-language parts to English; keep proper nouns/brands/technical terms unchanged. Output only the Yoda speak.
"""
            return (.style(name: "Master Yoda"), replacement)
        }

        if matches(token, exact: ["math", "proof", "theorem", "lemma"], contains: ["数学", "证明"]) {
            let replacement = """
Convert the input into a rigorous **Mathematical Proof**. Define distinct variables (Let $x$ be...), use logical symbols ($\\\\forall, \\\\exists, \\\\rightarrow, \\\\therefore$), cite non-existent Lemmas, and structure it as 'Theorem', 'Proof', and 'Conclusion'. Over-analyze simple concepts mathematically. End with **Q.E.D.**
"""
            return (.style(name: "Mathematical Proof"), replacement)
        }

        if matches(token, exact: ["json"]) {
             let replacement = """
Convert the natural language input into a valid **JSON object**. Infer keys and values from the context. If the input is a list, make a JSON array. If it's a person/entity, make an object. Output only the raw JSON code block.
"""
            return (.programmingLanguage(name: "JSON"), replacement)
        }

        // MARK: - Pokémon Series
        
        if matches(token, exact: ["pikachu", "pika", "⚡"], contains: ["皮卡丘"]) {
            let replacement = """
Rewrite the input as **Pikachu** from Pokémon. Use ONLY variations of "Pika", "Pikachu", "Pi", "Chu", "Pikapi" (Ash's name). Convey the original emotion and intent through repetition (excited = "Pika Pika Pika!"), punctuation (angry = "PIKAAA!", sad = "Pika... chu..."), and combinations (questioning = "Pika? Pikachu?"). Keep it short and expressive like the anime. Output ONLY the Pikachu speech.
"""
            return (.style(name: "Pikachu"), replacement)
        }
        
        if matches(token, exact: ["charizard", "lizardon", "🔥"], contains: ["喷火龙"]) {
            let replacement = """
Rewrite the input as **Charizard** from Pokémon. Use ONLY variations of "Char", "Charizard", "Zard", with occasional roars. Convey emotion through intensity: calm = "Char...", angry = "CHARIZAAAARD!", determined = "Char! Zard!". Add fire/dragon energy to the tone. Output ONLY the Charizard speech.
"""
            return (.style(name: "Charizard"), replacement)
        }
        
        if matches(token, exact: ["snorlax", "kabigon", "😴", "💤"], contains: ["卡比兽"]) {
            let replacement = """
Rewrite the input as **Snorlax** from Pokémon. Use ONLY variations of "Snor", "Snorlax", "Lax", with lots of ellipses and yawning sounds. Everything should sound sleepy and lazy: "Snor... lax..." for most things, "Snooor..." when tired, "Snor! Lax!" only when food is mentioned. Output ONLY the Snorlax speech.
"""
            return (.style(name: "Snorlax"), replacement)
        }
        
        if matches(token, exact: ["meowth", "nyarth", "🪙"], contains: ["喵喵", "火箭队"]) {
            let replacement = """
Rewrite the input as **Meowth** from Team Rocket (Pokémon). Unlike other Pokémon, Meowth can speak human language but with a street-smart accent. Keep the original language; do not translate wholesale. For English, use Brooklyn accent ("dat's right!", "youse guys", drop 'g' endings). For Chinese, use 痞气/江湖气 tone. Occasionally slip in "Meowth!" or "喵喵！". Keep the scheming, sassy Team Rocket vibe. Output ONLY the Meowth speech.
"""
            return (.style(name: "Meowth"), replacement)
        }
        
        if matches(token, exact: ["pokemon", "pokémon"], contains: ["宝可梦", "神奇宝贝", "精灵"]) {
            let replacement = """
Rewrite the input as a **Pokémon** speaking. Choose a Pokémon whose personality fits the input's emotion (e.g., Pikachu for cheerful, Snorlax for lazy/tired, Charizard for angry/fierce, Jigglypuff for cute/annoyed, Psyduck for confused). Use ONLY that Pokémon's name variations as speech. Convey meaning through repetition, punctuation, and tone. Start with the chosen Pokémon in brackets like [Pikachu]. Output ONLY the Pokémon speech.
"""
            return (.style(name: "Pokémon"), replacement)
        }

        return nil
    }

    static func isFlagEmoji(_ raw: String) -> Bool {
        let scalars = Array(raw.unicodeScalars)
        guard scalars.count == 2 else { return false }
        return scalars.allSatisfy { (0x1F1E6...0x1F1FF).contains(Int($0.value)) }
    }

    static func regionCode(fromFlagEmoji raw: String) -> String? {
        guard isFlagEmoji(raw) else { return nil }
        let scalars = Array(raw.unicodeScalars)
        let base = Int(UnicodeScalar("A").value)
        let codePoints = scalars.map { Int($0.value) - 0x1F1E6 + base }
        guard codePoints.allSatisfy({ (base...(base + 25)).contains($0) }) else { return nil }
        return String(UnicodeScalar(codePoints[0])!) + String(UnicodeScalar(codePoints[1])!)
    }

    static func languageName(forRegionCode regionCode: String) -> String? {
        switch regionCode.uppercased() {
        case "US", "GB", "AU", "CA", "NZ", "IE":
            return "English"
        case "CN", "SG":
            return "Chinese"
        case "TW", "HK", "MO":
            return "Traditional Chinese"
        case "JP":
            return "Japanese"
        case "KR":
            return "Korean"
        case "FR":
            return "French"
        case "DE", "AT", "CH":
            return "German"
        case "ES", "MX":
            return "Spanish"
        case "BR", "PT":
            return "Portuguese"
        case "RU":
            return "Russian"
        case "SA", "AE", "EG":
            return "Arabic"
        default:
            return nil
        }
    }

    static func isAnimalOrCreatureTarget(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let animalEmoji: Set<String> = [
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁", "🐮", "🐷", "🐸", "🐵",
            "🐔", "🐧", "🐦", "🦉", "🦆", "🦅", "🦇", "🐴", "🦄", "🐝", "🦋", "🐛", "🦟", "🪲",
            "🐢", "🦎", "🐍", "🐙", "🦑", "🦐", "🦀", "🐟", "🐠", "🐡", "🦈", "🐬", "🐳", "🐋",
            "🦖", "🦕", "👽"
        ]
        if animalEmoji.contains(trimmed) { return true }

        let lowered = trimmed.lowercased()
        let englishKeywords = [
            "cat", "kitten", "dog", "puppy", "fox", "bear", "panda", "koala", "tiger", "lion", "rabbit",
            "bird", "penguin", "dolphin", "shark", "whale", "dinosaur", "alien"
        ]
        if englishKeywords.contains(where: { lowered.contains($0) }) { return true }

        let zhKeywords = ["猫", "狗", "狐狸", "熊", "熊猫", "老虎", "狮子", "兔", "鸟", "企鹅", "海豚", "鲨鱼", "鲸", "恐龙", "外星人", "生物"]
        if zhKeywords.contains(where: { trimmed.contains($0) }) { return true }

        return false
    }

    static func resolveUserProvidedTarget(_ raw: String) -> (kind: TranslationTargetKind, replacement: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let region = regionCode(fromFlagEmoji: trimmed),
           let language = languageName(forRegionCode: region) {
            return (.naturalLanguage(name: language), language)
        }

        if let special = resolveSpecialTarget(trimmed) {
            return special
        }

        if isAnimalOrCreatureTarget(trimmed) {
            let replacement = """
the same language as the input, but spoken as a vivid, anthropomorphic \(trimmed) with playful quirks, light interjections, and consistent in-universe tone (no translation)
"""
            return (.persona(description: trimmed), replacement)
        }

        let name = matchingLanguage(for: trimmed)?.gptName ?? trimmed
        return (.naturalLanguage(name: name), name)
    }
}
