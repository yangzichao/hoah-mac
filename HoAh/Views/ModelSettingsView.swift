import SwiftUI

struct ModelSettingsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var appSettings: AppSettingsStore
    @ObservedObject var whisperPrompt: WhisperPrompt
    @State private var customPrompt: String = ""
    @State private var isEditing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Output Format")
                    .font(theme.typography.headline)
                
                InfoTip(
                    title: "Output Format Guide",
                    message: "Unlike GPT, Voice Models(whisper) follows the style of your prompt rather than instructions. Use examples of your desired output format instead of commands.",
                    learnMoreURL: "https://cookbook.openai.com/examples/whisper_prompting_guide#comparison-with-gpt-prompting"
                )
                
                Spacer()
                
                Button(action: {
                    if isEditing {
                        // Save changes
                        whisperPrompt.setCustomPrompt(customPrompt, for: appSettings.selectedLanguage)
                        isEditing = false
                    } else {
                        // Enter edit mode
                        customPrompt = whisperPrompt.getLanguagePrompt(for: appSettings.selectedLanguage)
                        isEditing = true
                    }
                }) {
                    Text(isEditing ? "Save" : "Edit")
                        .font(theme.typography.caption)
                }
            }
            
            if isEditing {
                TextEditor(text: $customPrompt)
                    .font(theme.typography.caption)
                    .padding(8)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.inputBorder, lineWidth: 1)
                    )
                
            } else {
                Text(whisperPrompt.getLanguagePrompt(for: appSettings.selectedLanguage))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.inputBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.inputBorder, lineWidth: 1)
                    )
            }

            Divider().padding(.vertical, 4)

            HStack {
                Toggle(isOn: $appSettings.appendTrailingSpace) {
                    Text("Add space after paste")
                }
                .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                
                InfoTip(
                    title: "Trailing Space",
                    message: "Automatically add a space after pasted text. Useful for space-delimited languages."
                )
            }

            HStack {
                Toggle(isOn: $appSettings.isTextFormattingEnabled) {
                    Text("Automatic text formatting")
                }
                .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                
                InfoTip(
                    title: "Automatic Text Formatting",
                    message: "Apply intelligent text formatting to break large block of text into paragraphs."
                )
            }

            HStack {
                Toggle(isOn: $appSettings.isVADEnabled) {
                    Text("Voice Activity Detection (VAD)")
                }
                .toggleStyle(ThemedSwitchToggleStyle(theme: theme))
                
                InfoTip(
                    title: "Voice Activity Detection",
                    message: "Detect speech segments and filter out silence to improve accuracy of local models."
                )
            }

        }
        .padding()
        .background(theme.controlBackground)
        .cornerRadius(10)
        // Reset the editor when language changes
        .onChange(of: appSettings.selectedLanguage) { oldValue, newValue in
            if isEditing {
                customPrompt = whisperPrompt.getLanguagePrompt(for: newValue)
            }
        }
    }
}
