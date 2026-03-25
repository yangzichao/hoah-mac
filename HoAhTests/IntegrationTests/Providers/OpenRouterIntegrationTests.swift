import Testing
import Foundation
@testable import HoAh

// MARK: - OpenRouter Integration Tests
// 测试 HoAh 通过 OpenRouter API 的 AI Enhancement 功能

@Suite("OpenRouter Integration Tests")
struct OpenRouterIntegrationTests {
    let config = TestConfiguration.load()
    
    /// OpenRouter 测试模型列表
    /// OpenRouter 支持多种模型，这里选择一些常用的进行测试
    static let testModels = [
        "openai/gpt-4o-mini",
        "anthropic/claude-3-haiku",
        "google/gemini-2.5-flash-lite",
        "meta-llama/llama-3.1-8b-instruct"
    ]
    
    // MARK: - Model Tests
    
    @Test("Test openai/gpt-4o-mini text enhancement")
    func testGpt4oMiniEnhancement() async throws {
        try await testModelEnhancement(model: "openai/gpt-4o-mini")
    }
    
    @Test("Test anthropic/claude-3-haiku text enhancement")
    func testClaude3HaikuEnhancement() async throws {
        try await testModelEnhancement(model: "anthropic/claude-3-haiku")
    }
    
    @Test("Test google/gemini-2.5-flash-lite text enhancement")
    func testGeminiFlashEnhancement() async throws {
        try await testModelEnhancement(model: "google/gemini-2.5-flash-lite")
    }
    
    @Test("Test meta-llama/llama-3.1-8b-instruct text enhancement")
    func testLlama31Enhancement() async throws {
        try await testModelEnhancement(model: "meta-llama/llama-3.1-8b-instruct")
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if not configured
        guard config.isConfigured(for: "OpenRouter") else {
            print("⏭️ Skipping OpenRouter \(model) test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .openRouter,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )
        
        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .openRouter, "Provider should be OpenRouter")
        #expect(result.model == model, "Model should match")
        
        // 验证响应有实际语义内容
        let hasSemanticContent = result.enhancedText.lowercased().contains("hello") ||
                                  result.enhancedText.lowercased().contains("world") ||
                                  result.enhancedText.lowercased().contains("test")
        #expect(hasSemanticContent, "Response should contain meaningful content related to input")
        
        print("✅ OpenRouter \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Test OpenRouter error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        guard config.isConfigured(for: "OpenRouter") else {
            print("⏭️ Skipping OpenRouter error handling test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .openRouter,
            model: "openai/gpt-4o-mini",
            text: "",
            systemPrompt: TestFixtures.systemPrompt
        )
        
        #expect(result.responseTime > 0, "Should complete without error")
    }
    
    // MARK: - Multi-language Tests
    
    @Test("Test OpenRouter with Chinese text")
    @MainActor
    func testChineseTextEnhancement() async throws {
        guard config.isConfigured(for: "OpenRouter") else {
            print("⏭️ Skipping OpenRouter Chinese text test - API key not configured")
            return
        }
        
        let helper = AIEnhancementTestHelper(config: config)
        
        let result = try await helper.testEnhancement(
            provider: .openRouter,
            model: "openai/gpt-4o-mini",
            text: "你好世界这是一个测试",
            systemPrompt: "You are a helpful assistant that improves text clarity. Return only the improved text."
        )
        
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        print("✅ OpenRouter Chinese test: \(String(format: "%.2f", result.responseTime))s")
        print("   Response: \(result.enhancedText)")
    }
}
