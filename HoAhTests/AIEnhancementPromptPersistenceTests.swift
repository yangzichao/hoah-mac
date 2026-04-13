import Testing
@testable import HoAh
import Foundation
import SwiftData

@MainActor
struct AIEnhancementPromptPersistenceTests {
    private let activePromptsKey = "activePrompts"
    private let legacyPromptsKey = "customPrompts"

    private func makeEnhancementService() throws -> AIEnhancementService {
        let container = try ModelContainer(
            for: Transcription.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        return AIEnhancementService(
            aiService: AIService(),
            modelContext: container.mainContext
        )
    }

    @Test("Customized built-in prompt survives relocalization and restart")
    func customizedBuiltInPromptSurvivesReload() throws {
        UserDefaults.hoah.removeObject(forKey: activePromptsKey)
        UserDefaults.hoah.removeObject(forKey: legacyPromptsKey)
        defer {
            UserDefaults.hoah.removeObject(forKey: activePromptsKey)
            UserDefaults.hoah.removeObject(forKey: legacyPromptsKey)
        }

        let service = try makeEnhancementService()
        guard let polishPrompt = service.activePrompts.first(where: { $0.id == PredefinedPrompts.polishPromptId }) else {
            Issue.record("Missing built-in Polish prompt")
            return
        }

        let customizedText = polishPrompt.promptText + "\n\n# Customized by user"
        service.updatePrompt(
            CustomPrompt(
                id: polishPrompt.id,
                title: polishPrompt.title,
                promptText: customizedText,
                isActive: polishPrompt.isActive,
                icon: polishPrompt.icon,
                description: polishPrompt.description,
                isPredefined: true,
                triggerWords: polishPrompt.triggerWords,
                useSystemInstructions: false,
                hasUserModifiedTemplate: true
            )
        )

        service.relocalizePredefinedPromptTitles()

        guard let relocalizedPrompt = service.activePrompts.first(where: { $0.id == PredefinedPrompts.polishPromptId }) else {
            Issue.record("Missing built-in Polish prompt after relocalization")
            return
        }

        #expect(relocalizedPrompt.promptText == customizedText)
        #expect(relocalizedPrompt.hasUserModifiedTemplate)

        let reloadedService = try makeEnhancementService()
        guard let reloadedPrompt = reloadedService.activePrompts.first(where: { $0.id == PredefinedPrompts.polishPromptId }) else {
            Issue.record("Missing built-in Polish prompt after restart")
            return
        }

        #expect(reloadedPrompt.promptText == customizedText)
        #expect(reloadedPrompt.hasUserModifiedTemplate)
    }

    @Test("Legacy customized built-in prompt is migrated without being overwritten")
    func legacyCustomizedBuiltInPromptMigratesWithoutOverwrite() throws {
        UserDefaults.hoah.removeObject(forKey: activePromptsKey)
        UserDefaults.hoah.removeObject(forKey: legacyPromptsKey)
        defer {
            UserDefaults.hoah.removeObject(forKey: activePromptsKey)
            UserDefaults.hoah.removeObject(forKey: legacyPromptsKey)
        }

        guard let template = PredefinedPrompts.createDefaultPrompts().first(where: { $0.id == PredefinedPrompts.polishPromptId }) else {
            Issue.record("Missing built-in Polish prompt template")
            return
        }

        let legacyCustomizedText = "User customized Polish prompt"
        let legacyPrompt = CustomPrompt(
            id: template.id,
            title: template.title,
            promptText: legacyCustomizedText,
            isActive: template.isActive,
            icon: template.icon,
            description: template.description,
            isPredefined: true,
            triggerWords: template.triggerWords,
            useSystemInstructions: template.useSystemInstructions,
            hasUserModifiedTemplate: false
        )

        let data = try JSONEncoder().encode([legacyPrompt])
        UserDefaults.hoah.set(data, forKey: activePromptsKey)

        let service = try makeEnhancementService()
        guard let migratedPrompt = service.activePrompts.first(where: { $0.id == PredefinedPrompts.polishPromptId }) else {
            Issue.record("Missing built-in Polish prompt after migration")
            return
        }

        #expect(migratedPrompt.promptText == legacyCustomizedText)
        #expect(migratedPrompt.hasUserModifiedTemplate)
    }
}
