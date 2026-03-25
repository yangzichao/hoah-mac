import Testing
@testable import HoAh
import Foundation

// MARK: - HistoryTimeRange Tests

@Suite("HistoryTimeRange Tests")
struct HistoryTimeRangeTests {
    
    @Test("All cases have unique IDs")
    func allCasesHaveUniqueIds() {
        let ids = HistoryTimeRange.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
    
    @Test("Last 24 hours cutoff is approximately 24 hours ago")
    func last24HoursCutoff() {
        let cutoff = HistoryTimeRange.last24Hours.cutoffDate
        #expect(cutoff != nil)
        
        if let cutoff = cutoff {
            let now = Date()
            let hoursDiff = now.timeIntervalSince(cutoff) / 3600
            // Should be approximately 24 hours (allow small tolerance)
            #expect(hoursDiff >= 23.9 && hoursDiff <= 24.1)
        }
    }
    
    @Test("Last 7 days cutoff is approximately 7 days ago")
    func last7DaysCutoff() {
        let cutoff = HistoryTimeRange.last7Days.cutoffDate
        #expect(cutoff != nil)
        
        if let cutoff = cutoff {
            let now = Date()
            let daysDiff = now.timeIntervalSince(cutoff) / 86400
            #expect(daysDiff >= 6.9 && daysDiff <= 7.1)
        }
    }
    
    @Test("Last 30 days cutoff is approximately 30 days ago")
    func last30DaysCutoff() {
        let cutoff = HistoryTimeRange.last30Days.cutoffDate
        #expect(cutoff != nil)
        
        if let cutoff = cutoff {
            let now = Date()
            let daysDiff = now.timeIntervalSince(cutoff) / 86400
            #expect(daysDiff >= 29.9 && daysDiff <= 30.1)
        }
    }
    
    @Test("All time has no cutoff date")
    func allTimeNoCutoff() {
        let cutoff = HistoryTimeRange.allTime.cutoffDate
        #expect(cutoff == nil)
    }
    
    @Test("File tags are unique and non-empty")
    func fileTagsAreValid() {
        let tags = HistoryTimeRange.allCases.map { $0.fileTag }
        
        // All tags should be non-empty
        for tag in tags {
            #expect(!tag.isEmpty)
        }
        
        // All tags should be unique
        let uniqueTags = Set(tags)
        #expect(tags.count == uniqueTags.count)
    }
    
    @Test("File tags have expected values")
    func fileTagValues() {
        #expect(HistoryTimeRange.last24Hours.fileTag == "last-24h")
        #expect(HistoryTimeRange.last7Days.fileTag == "last-7d")
        #expect(HistoryTimeRange.last30Days.fileTag == "last-30d")
        #expect(HistoryTimeRange.allTime.fileTag == "all-time")
    }
}

// MARK: - PredefinedModels Tests

@Suite("PredefinedModels Tests")
struct PredefinedModelsTests {
    
    @Test("Large v3 model order contains expected models")
    func largeV3ModelOrder() {
        let order = PredefinedModels.largeV3ModelOrder
        
        #expect(order.contains("ggml-large-v3-turbo-q5_0"))
        #expect(order.contains("ggml-large-v3-turbo"))
        #expect(order.contains("ggml-large-v3"))
        #expect(order.count == 3)
    }
    
    @Test("Large v3 model names set matches order array")
    func largeV3ModelNamesMatchOrder() {
        let names = PredefinedModels.largeV3ModelNames
        let order = PredefinedModels.largeV3ModelOrder
        
        #expect(names.count == order.count)
        for name in order {
            #expect(names.contains(name))
        }
    }
    
    @Test("All languages dictionary contains common languages")
    func allLanguagesContainsCommon() {
        let languages = PredefinedModels.allLanguages
        
        #expect(languages["en"] == "English")
        #expect(languages["zh"] == "Chinese")
        #expect(languages["ja"] == "Japanese")
        #expect(languages["ko"] == "Korean")
        #expect(languages["es"] == "Spanish")
        #expect(languages["fr"] == "French")
        #expect(languages["de"] == "German")
        #expect(languages["auto"] == "Auto-detect")
    }
    
    @Test("Language dictionary for non-multilingual returns only English")
    func nonMultilingualLanguages() {
        let languages = PredefinedModels.getLanguageDictionary(isMultilingual: false)
        
        #expect(languages.count == 1)
        #expect(languages["en"] == "English")
    }
    
    @Test("Language dictionary for multilingual returns all languages")
    func multilingualLanguages() {
        let languages = PredefinedModels.getLanguageDictionary(isMultilingual: true)
        
        #expect(languages.count > 50) // Should have many languages
        #expect(languages["en"] != nil)
        #expect(languages["zh"] != nil)
    }
    
    @Test("Apple native languages have proper BCP-47 format")
    func appleNativeLanguagesFormat() {
        let languages = PredefinedModels.appleNativeLanguages
        
        // Check some expected entries
        #expect(languages["en-US"] == "English (United States)")
        #expect(languages["zh-CN"] == "Chinese Simplified (China)")
        #expect(languages["ja-JP"] == "Japanese (Japan)")
        
        // All keys should contain a hyphen (BCP-47 format)
        for key in languages.keys {
            #expect(key.contains("-"), "Key '\(key)' should be in BCP-47 format")
        }
    }
    
    @Test("Models array is not empty")
    func modelsArrayNotEmpty() {
        let models = PredefinedModels.models
        #expect(!models.isEmpty)
    }
}

// MARK: - PredefinedPrompts Tests

@Suite("PredefinedPrompts Tests")
struct PredefinedPromptsTests {
    
    @Test("Predefined prompt IDs are valid UUIDs")
    func predefinedPromptIdsAreValid() {
        // These should not crash - they're valid UUIDs
        let _ = PredefinedPrompts.defaultPromptId
        let _ = PredefinedPrompts.polishPromptId
        let _ = PredefinedPrompts.formalPromptId
        let _ = PredefinedPrompts.professionalPromptId
        let _ = PredefinedPrompts.translatePromptId
        let _ = PredefinedPrompts.qnaPromptId
    }
    
    @Test("All predefined prompts have unique IDs")
    func allPromptsHaveUniqueIds() {
        let prompts = PredefinedPrompts.all
        let ids = prompts.map { $0.id }
        let uniqueIds = Set(ids)
        
        #expect(ids.count == uniqueIds.count)
    }
    
    @Test("All predefined prompts are marked as predefined")
    func allPromptsArePredefined() {
        let prompts = PredefinedPrompts.all
        
        for prompt in prompts {
            #expect(prompt.isPredefined, "Prompt '\(prompt.title)' should be marked as predefined")
        }
    }
    
    @Test("All predefined prompts have non-empty titles")
    func allPromptsHaveTitles() {
        let prompts = PredefinedPrompts.all
        
        for prompt in prompts {
            #expect(!prompt.title.isEmpty, "Prompt should have a title")
        }
    }
    
    @Test("All predefined prompts have non-empty prompt text")
    func allPromptsHavePromptText() {
        let prompts = PredefinedPrompts.all
        
        for prompt in prompts {
            #expect(!prompt.promptText.isEmpty, "Prompt '\(prompt.title)' should have prompt text")
        }
    }
    
    @Test("All predefined prompts have icons")
    func allPromptsHaveIcons() {
        let prompts = PredefinedPrompts.all
        
        for prompt in prompts {
            #expect(!prompt.icon.isEmpty, "Prompt '\(prompt.title)' should have an icon")
        }
    }
    
    @Test("Base polish prompt text is not empty")
    func basePolishPromptTextNotEmpty() {
        let text = PredefinedPrompts.basePolishPromptText
        #expect(!text.isEmpty)
        #expect(text.contains("ROLE"))
        #expect(text.contains("TASK"))
    }
    
    @Test("Formal writing prompt text is not empty")
    func formalWritingPromptTextNotEmpty() {
        let text = PredefinedPrompts.formalWritingPromptText
        #expect(!text.isEmpty)
        #expect(text.contains("Formal"))
    }
    
    @Test("Professional prompt text is not empty")
    func professionalPromptTextNotEmpty() {
        let text = PredefinedPrompts.professionalPromptText
        #expect(!text.isEmpty)
        #expect(text.contains("High-EQ"))
    }
    
    @Test("Generate polish prompt returns base when both toggles off")
    func generatePolishPromptBothOff() {
        let text = PredefinedPrompts.generatePolishPromptText(formalWriting: false, professional: false)
        #expect(text == PredefinedPrompts.basePolishPromptText)
    }
    
    @Test("Generate polish prompt returns formal when formal toggle on")
    func generatePolishPromptFormalOn() {
        let text = PredefinedPrompts.generatePolishPromptText(formalWriting: true, professional: false)
        #expect(text == PredefinedPrompts.formalWritingPromptText)
    }
    
    @Test("Generate polish prompt returns professional when professional toggle on")
    func generatePolishPromptProfessionalOn() {
        let text = PredefinedPrompts.generatePolishPromptText(formalWriting: false, professional: true)
        #expect(text == PredefinedPrompts.professionalPromptText)
    }
    
    @Test("Generate polish prompt returns combined when both toggles on")
    func generatePolishPromptBothOn() {
        let text = PredefinedPrompts.generatePolishPromptText(formalWriting: true, professional: true)
        #expect(text == PredefinedPrompts.combinedHighEQFormalWritingPromptText)
    }
    
    @Test("Q&A prompt does not use system instructions")
    func qnaPromptNoSystemInstructions() {
        let prompts = PredefinedPrompts.all
        let qnaPrompt = prompts.first { $0.id == PredefinedPrompts.qnaPromptId }
        
        #expect(qnaPrompt != nil)
        #expect(qnaPrompt?.useSystemInstructions == false)
    }
    
    @Test("Translate prompt does not use system instructions")
    func translatePromptNoSystemInstructions() {
        let prompts = PredefinedPrompts.all
        let translatePrompt = prompts.first { $0.id == PredefinedPrompts.translatePromptId }
        
        #expect(translatePrompt != nil)
        #expect(translatePrompt?.useSystemInstructions == false)
    }
}

// MARK: - Translation Target Resolution Tests

@Suite("Translation Target Resolution Tests")
struct TranslationTargetResolutionTests {
    @Test("Flag emojis map to language names")
    func flagEmojiMapping() {
        #expect(TranslationLanguage.regionCode(fromFlagEmoji: "🇯🇵") == "JP")
        #expect(TranslationLanguage.languageName(forRegionCode: "JP") == "Japanese")
        #expect(TranslationLanguage.resolveUserProvidedTarget("🇯🇵")?.replacement == "Japanese")

        #expect(TranslationLanguage.resolveUserProvidedTarget("🇺🇸")?.replacement == "English")
        #expect(TranslationLanguage.resolveUserProvidedTarget("🇨🇳")?.replacement == "Chinese")
    }

    @Test("Animal/creature targets become same-language personification")
    func animalPersonaTarget() {
        let resolvedDog = TranslationLanguage.resolveUserProvidedTarget("🐶")
        #expect(resolvedDog?.kind == .persona(description: "🐶"))
        #expect(resolvedDog?.replacement.contains("personified 🐶") == true)

        let resolvedCat = TranslationLanguage.resolveUserProvidedTarget("cat")
        #expect(resolvedCat?.kind == .persona(description: "cat"))
        #expect(resolvedCat?.replacement.contains("personified cat") == true)

        let resolvedAlien = TranslationLanguage.resolveUserProvidedTarget("外星人")
        #expect(resolvedAlien?.kind == .persona(description: "外星人"))
        #expect(resolvedAlien?.replacement.contains("personified 外星人") == true)
    }

    @Test("Special targets map to conversion/style instructions")
    func specialTargets() {
        let morse = TranslationLanguage.resolveUserProvidedTarget("Morse Code")
        #expect(morse?.kind == .format(name: "Morse Code"))
        #expect(morse?.replacement.contains("Morse") == true)

        let python = TranslationLanguage.resolveUserProvidedTarget("Python")
        #expect(python?.kind == .programmingLanguage(name: "Python"))
        #expect(python?.replacement.contains("Python") == true)

        let rust = TranslationLanguage.resolveUserProvidedTarget("rust")
        #expect(rust?.kind == .programmingLanguage(name: "Rust"))

        let java = TranslationLanguage.resolveUserProvidedTarget("Java")
        #expect(java?.kind == .programmingLanguage(name: "Java"))

        let cxx = TranslationLanguage.resolveUserProvidedTarget("C++")
        #expect(cxx?.kind == .programmingLanguage(name: "C++"))

        let cpp = TranslationLanguage.resolveUserProvidedTarget("cpp")
        #expect(cpp?.kind == .programmingLanguage(name: "C++"))

        let csharp = TranslationLanguage.resolveUserProvidedTarget("C#")
        #expect(csharp?.kind == .programmingLanguage(name: "C#"))

        let js = TranslationLanguage.resolveUserProvidedTarget("Java Script")
        #expect(js?.kind == .programmingLanguage(name: "JavaScript"))

        let ts = TranslationLanguage.resolveUserProvidedTarget("Type Script")
        #expect(ts?.kind == .programmingLanguage(name: "TypeScript"))

        let fortran = TranslationLanguage.resolveUserProvidedTarget("Fortran 90")
        #expect(fortran?.kind == .programmingLanguage(name: "Fortran"))

        let logic = TranslationLanguage.resolveUserProvidedTarget("Formal Logic")
        #expect(logic?.kind == .format(name: "Formal Logic"))
        #expect(logic?.replacement.contains("Formal") == true)

        let wenyan = TranslationLanguage.resolveUserProvidedTarget("文言文")
        #expect(wenyan?.kind == .style(name: "Classical Chinese (文言文)"))
        #expect(wenyan?.replacement.contains("文言文") == true)
    }
}

// MARK: - AIEnhancementConfiguration Tests

@Suite("AIEnhancementConfiguration Tests")
struct AIEnhancementConfigurationTests {
    
    @Test("Configuration initializes with correct values")
    func configurationInitialization() {
        let config = AIEnhancementConfiguration(
            name: "Test Config",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        
        #expect(config.name == "Test Config")
        #expect(config.provider == "OpenAI")
        #expect(config.model == "gpt-4.1")
        #expect(config.hasApiKey == false)
        #expect(config.region == nil)
        #expect(config.enableCrossRegion == false)
    }
    
    @Test("Configuration with AWS Bedrock settings")
    func configurationWithAWSBedrock() {
        let config = AIEnhancementConfiguration(
            name: "Bedrock Config",
            provider: "AWS Bedrock",
            model: "claude-3-sonnet",
            region: "us-east-1",
            enableCrossRegion: true
        )
        
        #expect(config.provider == "AWS Bedrock")
        #expect(config.region == "us-east-1")
        #expect(config.enableCrossRegion == true)
    }
    
    @Test("Configuration summary for non-AWS provider")
    func configurationSummaryNonAWS() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        
        let summary = config.summary
        #expect(summary.contains("OpenAI"))
        #expect(summary.contains("gpt-4.1"))
    }
    
    @Test("Configuration summary for AWS Bedrock includes region")
    func configurationSummaryAWSBedrock() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "AWS Bedrock",
            model: "claude-3-sonnet",
            region: "us-west-2"
        )
        
        let summary = config.summary
        #expect(summary.contains("AWS Bedrock"))
        #expect(summary.contains("us-west-2"))
        #expect(summary.contains("claude-3-sonnet"))
    }
    
    @Test("Provider icon returns valid SF Symbol names")
    func providerIconsAreValid() {
        let providers = ["AWS Bedrock", "OCI Generative AI", "OpenAI", "Azure OpenAI", "Gemini", "GROQ", "Cerebras"]
        
        for provider in providers {
            let config = AIEnhancementConfiguration(
                name: "Test",
                provider: provider,
                model: "test-model"
            )
            #expect(!config.providerIcon.isEmpty)
        }
    }
    
    @Test("Configuration validation errors for empty name")
    func validationErrorsEmptyName() {
        let config = AIEnhancementConfiguration(
            name: "",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("name") })
    }
    
    @Test("Configuration validation errors for empty model")
    func validationErrorsEmptyModel() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "OpenAI",
            model: ""
        )
        
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Model") })
    }
    
    @Test("Configuration validation errors for invalid provider")
    func validationErrorsInvalidProvider() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "InvalidProvider",
            model: "test-model"
        )
        
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Invalid provider") })
    }
    
    @Test("AWS Bedrock requires region")
    func awsBedrockRequiresRegion() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "AWS Bedrock",
            model: "claude-3-sonnet",
            region: nil
        )
        
        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Region") })
    }

    @Test("Azure OpenAI requires endpoint")
    func azureOpenAIRequiresEndpoint() {
        let config = AIEnhancementConfiguration(
            name: "Azure Test",
            provider: "Azure OpenAI",
            model: "gpt-4.1-prod"
        )

        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Endpoint") })
    }

    @Test("Azure OpenAI request URL normalizes resource endpoint")
    func azureOpenAIRequestURLNormalization() {
        let provider = AIProvider.azureOpenAI
        let url = provider.requestURL(customEndpoint: "https://example.openai.azure.com")
        #expect(url == "https://example.openai.azure.com/openai/v1/chat/completions")

        let normalized = provider.normalizedCustomEndpoint("https://example.openai.azure.com/openai/v1/chat/completions")
        #expect(normalized == "https://example.openai.azure.com/openai/v1")
    }

    @Test("OCI Generative AI requires region and endpoint")
    func ociGenerativeAIRequiresRegionAndEndpoint() {
        let config = AIEnhancementConfiguration(
            name: "OCI Test",
            provider: "OCI Generative AI",
            model: "openai.gpt-oss-20b",
            apiKey: "sk-test"
        )

        #expect(!config.isValid)
        #expect(config.validationErrors.contains { $0.contains("Region") })
        #expect(config.validationErrors.contains { $0.contains("Endpoint") })
    }

    @Test("OCI Generative AI request URL normalizes service endpoint")
    func ociGenerativeAIRequestURLNormalization() {
        let provider = AIProvider.ociGenerativeAI
        let url = provider.requestURL(customEndpoint: "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com")
        #expect(url == "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1/chat/completions")

        let normalized = provider.normalizedCustomEndpoint("https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1/chat/completions")
        #expect(normalized == "https://inference.generativeai.us-chicago-1.oci.oraclecloud.com/20231130/actions/v1")
    }
    
    @Test("Configuration is Equatable")
    func configurationEquatable() {
        let id = UUID()
        let config1 = AIEnhancementConfiguration(
            id: id,
            name: "Test",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        let config2 = AIEnhancementConfiguration(
            id: id,
            name: "Test",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        
        // Compare key properties (Keychain state may differ)
        #expect(config1.id == config2.id)
        #expect(config1.name == config2.name)
        #expect(config1.provider == config2.provider)
        #expect(config1.model == config2.model)
    }
    
    @Test("Configuration is Codable")
    func configurationCodable() throws {
        let config = AIEnhancementConfiguration(
            name: "Test Config",
            provider: "OpenAI",
            model: "gpt-4.1",
            region: "us-east-1"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AIEnhancementConfiguration.self, from: data)
        
        #expect(decoded.name == config.name)
        #expect(decoded.provider == config.provider)
        #expect(decoded.model == config.model)
        #expect(decoded.region == config.region)
    }
    
    @Test("Auth method returns none when no credentials")
    func authMethodNone() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "OpenAI",
            model: "gpt-4.1"
        )
        
        #expect(config.authMethod == .none)
    }
    
    @Test("Auth method returns awsProfile when profile name set")
    func authMethodAWSProfile() {
        let config = AIEnhancementConfiguration(
            name: "Test",
            provider: "AWS Bedrock",
            model: "claude-3-sonnet",
            awsProfileName: "default",
            region: "us-east-1"
        )
        
        if case .awsProfile(let profileName) = config.authMethod {
            #expect(profileName == "default")
        } else {
            Issue.record("Expected awsProfile auth method")
        }
    }
}
