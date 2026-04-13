import Foundation

@MainActor
extension AIEnhancementService {
    var promptShortcutPrompts: [CustomPrompt] {
        let shouldShowSecondTranslation = appSettings?.isSecondTranslationEnabled ?? false
        return activePrompts.filter { prompt in
            shouldShowSecondTranslation || prompt.id != PredefinedPrompts.translatePrompt2Id
        }
    }

    func addPrompt(title: String, promptText: String, icon: PromptIcon = "doc.text.fill", description: String? = nil, triggerWords: [String] = [], useSystemInstructions: Bool = false, kind: PromptKind) {
        let newPrompt = CustomPrompt(title: title, promptText: promptText, isActive: true, icon: icon, description: description, isPredefined: false, triggerWords: triggerWords, useSystemInstructions: useSystemInstructions)
        activePrompts.append(newPrompt)
        if selectedPromptId == nil {
            selectedPromptId = newPrompt.id
        }
    }

    func updatePrompt(_ prompt: CustomPrompt) {
        if let index = activePrompts.firstIndex(where: { $0.id == prompt.id }) {
            activePrompts[index] = prompt
        }
    }

    func deletePrompt(_ prompt: CustomPrompt) {
        if activePrompts.contains(where: { $0.id == prompt.id }) {
            activePrompts.removeAll { $0.id == prompt.id }
            if selectedPromptId == prompt.id {
                selectedPromptId = activePrompts.first?.id
            }
        }
    }

    func setActivePrompt(_ prompt: CustomPrompt) {
        guard activePrompts.contains(where: { $0.id == prompt.id }) else { return }
        selectedPromptId = prompt.id
    }

    func resetPromptToDefault(_ prompt: CustomPrompt) {
        guard prompt.isPredefined,
              let template = PredefinedPrompts.createDefaultPrompts().first(where: { $0.id == prompt.id }) else { return }
        
        if let index = activePrompts.firstIndex(where: { $0.id == prompt.id }) {
            let restoredPrompt = CustomPrompt(
                id: template.id,
                title: template.title,
                promptText: template.promptText,
                isActive: activePrompts[index].isActive,
                icon: template.icon,
                description: template.description,
                isPredefined: true,
                triggerWords: template.triggerWords,
                useSystemInstructions: template.useSystemInstructions,
                isReadOnly: template.isReadOnly,
                hasUserModifiedTemplate: false
            )
            activePrompts[index] = restoredPrompt
            if selectedPromptId == nil {
                selectedPromptId = restoredPrompt.id
            }
            return
        }
    }

    func resetPredefinedPrompts() {
        let templates = PredefinedPrompts.createDefaultPrompts()
        var updatedActive = activePrompts

        for template in templates {
            if let index = updatedActive.firstIndex(where: { $0.id == template.id }) {
                let existing = updatedActive[index]
                updatedActive[index] = CustomPrompt(
                    id: template.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: existing.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: template.triggerWords,
                    useSystemInstructions: template.useSystemInstructions,
                    isReadOnly: template.isReadOnly,
                    hasUserModifiedTemplate: false
                )
            } else {
                updatedActive.append(template)
            }
        }

        // Remove predefined prompts that are no longer shipped
        let templateIDs = Set(templates.map { $0.id })
        updatedActive.removeAll { prompt in
            prompt.isPredefined && !templateIDs.contains(prompt.id)
        }

        activePrompts = updatedActive

        if selectedPromptId == nil || !activePrompts.contains(where: { $0.id == selectedPromptId }) {
            selectedPromptId = activePrompts.first?.id
        }
    }

    func initializePredefinedPrompts() {
        let predefinedTemplates = PredefinedPrompts.createDefaultPrompts()
        let templateIDs = Set(predefinedTemplates.map { $0.id })
        activePrompts.removeAll { prompt in
            prompt.isPredefined && !templateIDs.contains(prompt.id)
        }

        for template in predefinedTemplates {
            if let existingIndex = activePrompts.firstIndex(where: { $0.id == template.id }) {
                let existingPrompt = activePrompts[existingIndex]
                activePrompts[existingIndex] = mergedPredefinedPrompt(existing: existingPrompt, template: template)
            } else {
                activePrompts.append(template)
            }
        }
    }
}
