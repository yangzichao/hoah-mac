import Testing
import Foundation
@testable import HoAh

// MARK: - Doubao Integration Tests
// 测试 HoAh 通过字节豆包 API 的 AI Enhancement 功能

@Suite("Doubao Integration Tests")
struct DoubaoIntegrationTests {
    let config = TestConfiguration.load()

    static let seedModelId = "doubao-seed-1-6-251015"

    // MARK: - Verification Tests

    @Test("Verify Doubao key (Seed)")
    func testDoubaoSeedKeyVerification() async throws {
        guard let apiKey = config.doubaoKey, !apiKey.isEmpty else {
            print("⏭️ Skipping Doubao verification - API key not configured")
            return
        }

        let result = await AIConfigurationValidator.verifyDoubaoKey(apiKey: apiKey, modelGroup: .seedFlash)
        #expect(result.success, "Doubao key verification should succeed")
        #expect(result.resolvedModelId != nil, "Resolved model id should not be nil")
    }

    // MARK: - Model Tests

    @Test("Test Doubao Seed text enhancement")
    func testDoubaoSeedEnhancement() async throws {
        try await testModelEnhancement(model: Self.seedModelId)
    }

    @MainActor
    private func testModelEnhancement(model: String) async throws {
        // Skip if not configured
        guard config.isConfigured(for: "字节豆包") else {
            print("⏭️ Skipping Doubao \(model) test - API key not configured")
            return
        }

        let helper = AIEnhancementTestHelper(config: config)

        let result = try await helper.testEnhancement(
            provider: .doubao,
            model: model,
            text: TestFixtures.simpleText,
            systemPrompt: TestFixtures.systemPrompt
        )

        // Verify response
        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        #expect(result.responseTime > 0, "Response time should be positive")
        #expect(result.provider == .doubao, "Provider should be Doubao")
        #expect(result.model == model, "Model should match")

        print("✅ Doubao \(model): \(String(format: "%.2f", result.responseTime))s")
        print("   Response preview: \(String(result.enhancedText.prefix(100)))...")
    }

    // MARK: - Chinese Text Tests

    @Test("Test Doubao Chinese text enhancement")
    @MainActor
    func testChineseTextEnhancement() async throws {
        guard config.isConfigured(for: "字节豆包") else {
            print("⏭️ Skipping Doubao Chinese text test - API key not configured")
            return
        }

        let helper = AIEnhancementTestHelper(config: config)

        let chineseText = "你好世界 这是一个测试"
        let result = try await helper.testEnhancement(
            provider: .doubao,
            model: Self.seedModelId,
            text: chineseText,
            systemPrompt: "你是一个文本优化助手，请优化以下文本的表达，只返回优化后的文本。"
        )

        #expect(!result.enhancedText.isEmpty, "Enhanced text should not be empty")
        print("✅ Doubao Chinese text: \(String(format: "%.2f", result.responseTime))s")
        print("   Response: \(result.enhancedText)")
    }

    // MARK: - Error Handling Tests

    @Test("Test Doubao error handling with empty input")
    @MainActor
    func testEmptyInputHandling() async throws {
        guard config.isConfigured(for: "字节豆包") else {
            print("⏭️ Skipping Doubao error handling test - API key not configured")
            return
        }

        let helper = AIEnhancementTestHelper(config: config)

        let result = try await helper.testEnhancement(
            provider: .doubao,
            model: Self.seedModelId,
            text: "",
            systemPrompt: TestFixtures.systemPrompt
        )

        #expect(result.responseTime > 0, "Should complete without error")
    }
}
