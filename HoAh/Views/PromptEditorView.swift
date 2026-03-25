import SwiftUI

struct PromptEditorView: View {
    enum Mode: Equatable {
        case add(kind: PromptKind)
        case edit(CustomPrompt)
        
        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case let (.add(kind1), .add(kind2)):
                return kind1 == kind2
            case let (.edit(prompt1), .edit(prompt2)):
                return prompt1.id == prompt2.id
            default:
                return false
            }
        }
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme
    @State private var title: String
    @State private var promptText: String
    @State private var selectedIcon: PromptIcon
    @State private var description: String
    @State private var triggerWords: [String]
    @State private var showingIconPicker = false

    private var isTriggerKind: Bool { false }
    private var shouldShowTriggerWordsEditor: Bool { false }

    private var isEditingPredefinedPrompt: Bool {
        if case .edit(let prompt) = mode {
            return prompt.isPredefined
        }
        return false
    }
    
    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _promptText = State(initialValue: "")
            _selectedIcon = State(initialValue: "doc.text.fill")
            _description = State(initialValue: "")
            _triggerWords = State(initialValue: [])
        case .edit(let prompt):
            _title = State(initialValue: prompt.title)
            _promptText = State(initialValue: prompt.promptText)
            _selectedIcon = State(initialValue: prompt.icon)
            _description = State(initialValue: prompt.description ?? "")
            _triggerWords = State(initialValue: prompt.triggerWords)
        }
    }
    
    private var headerTitle: String {
        switch mode {
        case .add:
            return NSLocalizedString("New Prompt", comment: "Title for creating a new prompt")
        case .edit:
            return isEditingPredefinedPrompt 
                ? NSLocalizedString("Edit Built-in Prompt", comment: "Title for editing a built-in prompt")
                : NSLocalizedString("Edit Prompt", comment: "Title for editing a custom prompt")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            ScrollView {
                contentSections
                    .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var headerBar: some View {
        HStack {
            Text(headerTitle)
                .font(theme.typography.title2)
                .fontWeight(.bold)
            Spacer()
            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "")) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.textSecondary)
                
                Button {
                    save()
                    dismiss()
                } label: {
                    Text(NSLocalizedString("Save", comment: ""))
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .background(
            theme.windowBackground
                .shadow(color: theme.shadowColor.opacity(0.1), radius: 8, y: 2)
        )
    }

    @ViewBuilder
    private var contentSections: some View {
        VStack(spacing: 24) {
            builtInNotice
            titleAndIcon
            descriptionField
            promptTextSection
            if shouldShowTriggerWordsEditor {
                TriggerWordsEditor(triggerWords: $triggerWords)
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var builtInNotice: some View {
        if isEditingPredefinedPrompt, case .edit(let prompt) = mode {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Built-in prompt", comment: ""))
                        .font(theme.typography.headline)
                    Text(NSLocalizedString("Default and other built-in prompts can be edited but not deleted. Reset anytime to restore the original text.", comment: ""))
                        .font(theme.typography.subheadline)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
                Button(NSLocalizedString("Reset to Default", comment: "")) {
                    resetToDefaultTemplate(for: prompt)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }

    private var titleAndIcon: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Title", comment: ""))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.textSecondary)
                TextField(NSLocalizedString("Enter a short, descriptive title", comment: ""), text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(theme.typography.body)
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("Icon", comment: ""))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.textSecondary)
                
                Button(action: {
                    showingIconPicker = true
                }) {
                    Image(systemName: selectedIcon)
                        .font(.system(size: 20))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 48, height: 48)
                        .background(theme.controlBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.panelBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                IconPickerPopover(selectedIcon: $selectedIcon, isPresented: $showingIconPicker)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Description", comment: ""))
                .font(theme.typography.headline)
                .foregroundColor(theme.textSecondary)
            
            Text(NSLocalizedString("Add a brief description of what this prompt does", comment: ""))
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textSecondary)
            
            TextField(NSLocalizedString("Enter a description", comment: ""), text: $description)
                .textFieldStyle(.roundedBorder)
                .font(theme.typography.body)
        }
        .padding(.horizontal)
    }

    private var promptTextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Prompt Instructions", comment: ""))
                .font(theme.typography.headline)
                .foregroundColor(theme.textSecondary)
            
            Text(NSLocalizedString("Define how AI should enhance your transcriptions", comment: ""))
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textSecondary)
            
            TextEditor(text: $promptText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var templatePicker: some View {
        EmptyView() // Removed as requested
    }

    
    private func save() {
        switch mode {
        case .add(let kind):
            let cleanedTriggers: [String] = []
            enhancementService.addPrompt(
                title: title,
                promptText: promptText,
                icon: selectedIcon,
                description: description.isEmpty ? nil : description,
                triggerWords: cleanedTriggers,
                useSystemInstructions: false,
                kind: kind
            )
        case .edit(let prompt):
            let cleanedTriggers: [String] = []
            let updatedPrompt = CustomPrompt(
                id: prompt.id,
                title: title,
                promptText: promptText,
                isActive: prompt.isActive,
                icon: selectedIcon,
                description: description.isEmpty ? nil : description,
                isPredefined: prompt.isPredefined,
                triggerWords: cleanedTriggers,
                useSystemInstructions: false
            )
            enhancementService.updatePrompt(updatedPrompt)
        }
    }

    private func resetToDefaultTemplate(for prompt: CustomPrompt) {
        guard let template = PredefinedPrompts.createDefaultPrompts().first(where: { $0.id == prompt.id }) else { return }

        title = template.title
        promptText = template.promptText
        selectedIcon = template.icon
        description = template.description ?? ""
        triggerWords = template.triggerWords
        // useSystemInstructions is deprecated/removed from view state, ignoring template value
        
        enhancementService.resetPromptToDefault(prompt)
    }
}

// Reusable Trigger Words Editor Component
struct TriggerWordsEditor: View {
    @Binding var triggerWords: [String]
    @State private var newTriggerWord: String = ""
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("Trigger Words", comment: ""))
                .font(theme.typography.headline)
                .foregroundColor(theme.textSecondary)
            
            Text(NSLocalizedString("Add multiple words that can activate this prompt", comment: ""))
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textSecondary)
            
            // Display existing trigger words as tags
            if !triggerWords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220))], spacing: 8) {
                    ForEach(triggerWords, id: \.self) { word in
                        TriggerWordItemView(word: word) {
                            triggerWords.removeAll { $0 == word }
                        }
                    }
                }
            }
            
            // Input for new trigger word
            HStack {
                TextField(NSLocalizedString("Add trigger word", comment: ""), text: $newTriggerWord)
                    .textFieldStyle(.roundedBorder)
                    .font(theme.typography.body)
                    .onSubmit {
                        addTriggerWord()
                    }
                
                Button(NSLocalizedString("Add", comment: "")) {
                    addTriggerWord()
                }
                .disabled(newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    private func addTriggerWord() {
        let trimmedWord = newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        
        // Check for duplicates (case insensitive)
        let lowerCaseWord = trimmedWord.lowercased()
        guard !triggerWords.contains(where: { $0.lowercased() == lowerCaseWord }) else { return }
        
        triggerWords.append(trimmedWord)
        newTriggerWord = ""
    }
}


struct TriggerWordItemView: View {
    let word: String
    let onDelete: () -> Void
    @State private var isHovered = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 6) {
            Text(word)
                .font(theme.typography.caption)
                .lineLimit(1)
                .foregroundColor(theme.textPrimary)
            
            Spacer(minLength: 8)
            
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isHovered ? theme.statusError : theme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .help(NSLocalizedString("Remove word", comment: ""))
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hover
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(theme.inputBackground)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.inputBorder, lineWidth: 1)
        }
    }
}

// Icon Picker Popover - shows icons in a grid format without category labels
struct IconPickerPopover: View {
    @Binding var selectedIcon: PromptIcon
    @Binding var isPresented: Bool
    @Environment(\.theme) private var theme
    
    var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: 45, maximum: 52), spacing: 14)
        ]
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(PromptIcon.allCases, id: \.self) { icon in
                    Button(action: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            selectedIcon = icon
                            isPresented = false
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedIcon == icon ? theme.windowBackground : theme.controlBackground)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == icon ? theme.separatorColor : theme.panelBorder, lineWidth: selectedIcon == icon ? 2 : 1)
                                )
                            
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(theme.textPrimary)
                        }
                        .scaleEffect(selectedIcon == icon ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedIcon == icon)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .frame(width: 400, height: 400)
    }
}
