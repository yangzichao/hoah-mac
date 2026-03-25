import Testing
@testable import HoAh
import Foundation

// MARK: - String+WordCount Tests

@Suite("String Word Count Tests")
struct StringWordCountTests {
    
    // MARK: - English Text Tests
    
    @Test("Empty string has zero word count")
    func emptyStringWordCount() {
        let text = ""
        #expect(text.smartWordCount == 0)
    }
    
    @Test("Single English word")
    func singleEnglishWord() {
        let text = "Hello"
        #expect(text.smartWordCount == 1)
    }
    
    @Test("Multiple English words")
    func multipleEnglishWords() {
        let text = "Hello world this is a test"
        #expect(text.smartWordCount == 6)
    }
    
    @Test("English words with punctuation")
    func englishWordsWithPunctuation() {
        let text = "Hello, world! How are you?"
        #expect(text.smartWordCount == 5)
    }
    
    @Test("English words with numbers")
    func englishWordsWithNumbers() {
        let text = "I have 3 apples and 5 oranges"
        #expect(text.smartWordCount == 7)
    }
    
    @Test("English text with extra spaces")
    func englishTextWithExtraSpaces() {
        let text = "Hello   world    test"
        #expect(text.smartWordCount == 3)
    }
    
    @Test("English text with newlines")
    func englishTextWithNewlines() {
        let text = "Hello\nworld\ntest"
        #expect(text.smartWordCount == 3)
    }
    
    // MARK: - CJK Text Tests
    
    @Test("Single Chinese character")
    func singleChineseCharacter() {
        let text = "你"
        #expect(text.smartWordCount == 1)
    }
    
    @Test("Multiple Chinese characters")
    func multipleChineseCharacters() {
        let text = "你好世界"
        #expect(text.smartWordCount == 4) // Each character counts as a word
    }
    
    @Test("Chinese sentence")
    func chineseSentence() {
        let text = "今天天气很好"
        #expect(text.smartWordCount == 6)
    }
    
    @Test("Japanese hiragana")
    func japaneseHiragana() {
        let text = "こんにちは"
        #expect(text.smartWordCount == 5) // Each character counts
    }
    
    @Test("Japanese katakana")
    func japaneseKatakana() {
        let text = "コンピュータ"
        #expect(text.smartWordCount == 6)
    }
    
    @Test("Korean hangul")
    func koreanHangul() {
        let text = "안녕하세요"
        #expect(text.smartWordCount == 5)
    }
    
    // MARK: - Mixed Language Tests
    
    @Test("Mixed Chinese and English")
    func mixedChineseEnglish() {
        let text = "Hello你好World世界"
        // "Hello" (1) + "你" (1) + "好" (1) + "World" (1) + "世" (1) + "界" (1) = 6
        #expect(text.smartWordCount == 6)
    }
    
    @Test("Mixed Chinese and English with spaces")
    func mixedChineseEnglishWithSpaces() {
        let text = "Hello 你好 World 世界"
        // "Hello" (1) + "你" (1) + "好" (1) + "World" (1) + "世" (1) + "界" (1) = 6
        #expect(text.smartWordCount == 6)
    }
    
    @Test("English sentence with Chinese words")
    func englishWithChineseWords() {
        let text = "I love 北京 and 上海"
        // "I" (1) + "love" (1) + "北" (1) + "京" (1) + "and" (1) + "上" (1) + "海" (1) = 7
        #expect(text.smartWordCount == 7)
    }
    
    // MARK: - Edge Cases
    
    @Test("Only spaces")
    func onlySpaces() {
        let text = "     "
        #expect(text.smartWordCount == 0)
    }
    
    @Test("Only punctuation")
    func onlyPunctuation() {
        let text = "...!!!"
        #expect(text.smartWordCount == 0)
    }
    
    @Test("Numbers only")
    func numbersOnly() {
        let text = "123 456 789"
        #expect(text.smartWordCount == 3)
    }
    
    @Test("Single number")
    func singleNumber() {
        let text = "42"
        #expect(text.smartWordCount == 1)
    }
    
    @Test("Alphanumeric mixed")
    func alphanumericMixed() {
        let text = "test123 hello456"
        #expect(text.smartWordCount == 2)
    }
}

// MARK: - Character.isCJK Tests

@Suite("Character CJK Detection Tests")
struct CharacterCJKTests {
    
    @Test("Chinese characters are CJK")
    func chineseCharactersAreCJK() {
        #expect(Character("中").isCJK)
        #expect(Character("国").isCJK)
        #expect(Character("你").isCJK)
        #expect(Character("好").isCJK)
    }
    
    @Test("Japanese hiragana is CJK")
    func japaneseHiraganaIsCJK() {
        #expect(Character("あ").isCJK)
        #expect(Character("い").isCJK)
        #expect(Character("う").isCJK)
    }
    
    @Test("Japanese katakana is CJK")
    func japaneseKatakanaIsCJK() {
        #expect(Character("ア").isCJK)
        #expect(Character("イ").isCJK)
        #expect(Character("ウ").isCJK)
    }
    
    @Test("Korean hangul is CJK")
    func koreanHangulIsCJK() {
        #expect(Character("한").isCJK)
        #expect(Character("글").isCJK)
        #expect(Character("안").isCJK)
    }
    
    @Test("English letters are not CJK")
    func englishLettersNotCJK() {
        #expect(!Character("a").isCJK)
        #expect(!Character("Z").isCJK)
        #expect(!Character("m").isCJK)
    }
    
    @Test("Numbers are not CJK")
    func numbersNotCJK() {
        #expect(!Character("0").isCJK)
        #expect(!Character("5").isCJK)
        #expect(!Character("9").isCJK)
    }
    
    @Test("Punctuation is not CJK")
    func punctuationNotCJK() {
        #expect(!Character(".").isCJK)
        #expect(!Character(",").isCJK)
        #expect(!Character("!").isCJK)
        #expect(!Character("?").isCJK)
    }
    
    @Test("Space is not CJK")
    func spaceNotCJK() {
        #expect(!Character(" ").isCJK)
    }
}

// MARK: - ClipboardManager Tests
// NOTE: ClipboardManager tests are disabled because NSPasteboard has concurrency issues
// when running tests in parallel. The clipboard is a shared system resource that
// cannot be safely accessed from multiple test threads simultaneously.
// These tests work correctly when run individually but crash when run in parallel.

// To test ClipboardManager manually:
// 1. Run the app
// 2. Use the clipboard functionality
// 3. Verify content is correctly set and retrieved
