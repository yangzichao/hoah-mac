import SwiftUI

/// A collapsible section that lets users test a prompt against sample text
/// and see the AI-processed result in real time.
struct PromptTestSection: View {
    let promptText: String
    let title: String
    let icon: PromptIcon
    let description: String?

    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.theme) private var theme

    @State private var isExpanded = false
    @State private var inputText = ""
    @State private var resultText = ""
    @State private var isRunning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            toggleButton
            if isExpanded {
                expandedContent
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Subviews

    private var toggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                Image(systemName: "play.circle")
                Text(NSLocalizedString("Test Prompt", comment: ""))
                    .font(theme.typography.headline)
            }
            .foregroundColor(theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Enter text to test how this prompt processes it", comment: ""))
                .font(theme.typography.subheadline)
                .foregroundColor(theme.textSecondary)

            inputEditor
            actionRow
            errorBanner
            resultView
        }
    }

    private var inputEditor: some View {
        TextEditor(text: $inputText)
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: 80, maxHeight: 120)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.inputBorder, lineWidth: 1)
            )
    }

    private var actionRow: some View {
        HStack {
            Button {
                runTest()
            } label: {
                HStack(spacing: 6) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(isRunning
                         ? NSLocalizedString("Running...", comment: "")
                         : NSLocalizedString("Run Test", comment: ""))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning || !enhancementService.isConfigured)

            if !enhancementService.isConfigured {
                Text(NSLocalizedString("AI provider not configured", comment: ""))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.statusError)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(theme.typography.caption)
                .foregroundColor(theme.statusError)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.statusError.opacity(0.08))
                )
        }
    }

    @ViewBuilder
    private var resultView: some View {
        if !resultText.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Result", comment: ""))
                    .font(theme.typography.headline)
                    .foregroundColor(theme.textSecondary)

                Text(resultText)
                    .font(.system(.body))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.accentColor.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(theme.accentColor.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Actions

    private func runTest() {
        let input = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        let testPrompt = CustomPrompt(
            id: UUID(),
            title: title,
            promptText: promptText,
            icon: icon,
            description: description,
            isPredefined: false
        )

        isRunning = true
        errorMessage = nil
        resultText = ""

        Task {
            do {
                let (result, _, _) = try await enhancementService.enhance(input, promptOverride: testPrompt)
                await MainActor.run {
                    resultText = result
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
}
