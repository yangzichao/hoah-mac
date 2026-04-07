import SwiftUI

/// Editable tag list for prompt trigger words.
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

            if !triggerWords.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220))], spacing: 8) {
                    ForEach(triggerWords, id: \.self) { word in
                        TriggerWordItemView(word: word) {
                            triggerWords.removeAll { $0 == word }
                        }
                    }
                }
            }

            HStack {
                TextField(NSLocalizedString("Add trigger word", comment: ""), text: $newTriggerWord)
                    .textFieldStyle(.roundedBorder)
                    .font(theme.typography.body)
                    .onSubmit { addTriggerWord() }

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
