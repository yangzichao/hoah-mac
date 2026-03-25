import SwiftUI

/// A reusable grid component for selecting prompts with a plus button to add new ones
struct PromptSelectionGrid: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme
    
    let prompts: [CustomPrompt]
    let selectedPromptId: UUID?
    let onPromptSelected: (CustomPrompt) -> Void
    let onEditPrompt: ((CustomPrompt) -> Void)?
    let onDeletePrompt: ((CustomPrompt) -> Void)?
    let onAddNewPrompt: (() -> Void)?
    
    init(
        prompts: [CustomPrompt],
        selectedPromptId: UUID?,
        onPromptSelected: @escaping (CustomPrompt) -> Void,
        onEditPrompt: ((CustomPrompt) -> Void)? = nil,
        onDeletePrompt: ((CustomPrompt) -> Void)? = nil,
        onAddNewPrompt: (() -> Void)? = nil
    ) {
        self.prompts = prompts
        self.selectedPromptId = selectedPromptId
        self.onPromptSelected = onPromptSelected
        self.onEditPrompt = onEditPrompt
        self.onDeletePrompt = onDeletePrompt
        self.onAddNewPrompt = onAddNewPrompt
    }
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if prompts.isEmpty {
                Text(LocalizedStringKey("No prompts available"))
                    .foregroundColor(theme.textSecondary)
                    .font(theme.typography.caption)
            } else {
                let columns = [
                    GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 36)
                ]
                
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(prompts) { prompt in
                        prompt.promptIcon(
                            isSelected: selectedPromptId == prompt.id,
                            onTap: { 
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onPromptSelected(prompt)
                                }
                            },
                            onEdit: onEditPrompt,
                            onDelete: onDeletePrompt
                        )
                    }
                    
                    if let onAddNewPrompt = onAddNewPrompt {
                        CustomPrompt.addNewButton {
                            onAddNewPrompt()
                        }
                        .help(NSLocalizedString("Add new prompt", comment: ""))
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                
                // Helpful tip for users
                HStack {
                    Image(systemName: "info.circle")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                    
                    Text(LocalizedStringKey("Double-click to edit • Right-click for more options"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }
        }
    }
}
