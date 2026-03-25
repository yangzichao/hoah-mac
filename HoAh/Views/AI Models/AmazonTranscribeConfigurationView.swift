import SwiftUI

struct AmazonTranscribeConfigurationView: View {
    let onSave: () -> Void

    @Environment(\.theme) private var theme
    @State private var configuration = AmazonTranscribeConfigurationStore.shared.load()
    @State private var secretAccessKey = AmazonTranscribeConfigurationStore.shared.secretAccessKey()
    @State private var availableProfiles = AmazonTranscribeConfigurationStore.shared.availableProfiles()
    @State private var errorMessage: String?

    private var regionOptions: [String] {
        let currentRegion = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        var options = AmazonTranscribeConfigurationStore.supportedRegions
        if !currentRegion.isEmpty, !options.contains(currentRegion) {
            options.append(currentRegion)
        }
        return options
    }

    private var selectedLanguageOptions: [AmazonTranscribeLanguageOption] {
        AmazonTranscribeConfigurationStore.supportedLanguageOptions.filter {
            configuration.preferredLanguageCodes.contains($0.code)
        }
        .sorted { left, right in
            guard let leftIndex = configuration.preferredLanguageCodes.firstIndex(of: left.code),
                  let rightIndex = configuration.preferredLanguageCodes.firstIndex(of: right.code) else {
                return left.name < right.name
            }
            return leftIndex < rightIndex
        }
    }

    private var availableLanguageOptions: [AmazonTranscribeLanguageOption] {
        AmazonTranscribeConfigurationStore.supportedLanguageOptions.filter {
            !configuration.preferredLanguageCodes.contains($0.code)
        }
    }

    private var quickAddLanguageOptions: [AmazonTranscribeLanguageOption] {
        let quickAddCodes = [
            "en-US",
            "zh-CN",
            "ja-JP",
            "ko-KR",
            "fr-FR",
            "de-DE",
            "es-US",
            "it-IT"
        ]

        return quickAddCodes.compactMap { code in
            AmazonTranscribeConfigurationStore.supportedLanguageOptions.first(where: { $0.code == code })
        }
    }

    private var canAddMoreLanguages: Bool {
        configuration.preferredLanguageCodes.count < AmazonTranscribeConfigurationStore.maxPreferredLanguageCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Amazon Transcribe Configuration")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("AWS Region")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                Picker("AWS Region", selection: $configuration.region) {
                    ForEach(regionOptions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Authentication")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                Picker("Authentication", selection: $configuration.authMethod) {
                    Text("AWS Profile").tag(AmazonTranscribeConfiguration.AuthMethod.profile)
                    Text("Access Key").tag(AmazonTranscribeConfiguration.AuthMethod.accessKey)
                }
                .pickerStyle(.segmented)
            }

            if configuration.authMethod == .profile {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AWS Profile")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textSecondary)

                        Spacer()

                        Button("Reload Profiles") {
                            availableProfiles = AmazonTranscribeConfigurationStore.shared.availableProfiles()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11))
                    }

                    if !availableProfiles.isEmpty {
                        Picker("AWS Profile", selection: $configuration.profileName) {
                            Text("Select profile").tag("")
                            ForEach(availableProfiles, id: \.self) { profile in
                                Text(profile).tag(profile)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    TextField("default", text: $configuration.profileName)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AWS Access Key ID")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    TextField("AKIA...", text: $configuration.accessKeyId)
                        .textFieldStyle(.roundedBorder)

                    Text("AWS Secret Access Key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    SecureField("Secret access key", text: $secretAccessKey)
                        .textFieldStyle(.roundedBorder)

                    Text("Session Token (Optional)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    SecureField("Session token", text: $configuration.sessionToken)
                        .textFieldStyle(.roundedBorder)
                }
            }

            preferredLanguagesSection

            if configuration.authMethod == .profile, !availableProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Detected Profiles")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    Text(availableProfiles.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(theme.typography.caption)
                    .foregroundColor(theme.statusError)
            }

            HStack {
                Button("Save Configuration") {
                    saveConfiguration()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()
            }
        }
    }

    private var preferredLanguagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Language Hints")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)

                Spacer()

                Text("\(configuration.preferredLanguageCodes.count)/\(AmazonTranscribeConfigurationStore.maxPreferredLanguageCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
            }

            Text("Used when Dictation Language is set to Auto-detect. Select 2-5 likely languages to improve Amazon Transcribe accuracy. The first language is sent as AWS's primary hint.")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)

            Text("If you choose a specific dictation language elsewhere, Amazon uses that exact language and ignores this list.")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)

            if selectedLanguageOptions.isEmpty {
                Text("No language hints selected yet.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.panelBackground)
                    .cornerRadius(10)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(selectedLanguageOptions.enumerated()), id: \.element.code) { index, option in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(option.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(theme.textPrimary)

                                    Text(index == 0 ? "Primary" : "#\(index + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(index == 0 ? theme.primaryButtonText : theme.textSecondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(index == 0 ? theme.accentColor : theme.controlBackground)
                                        )
                                }

                                Text(option.code)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Button {
                                    movePreferredLanguage(from: index, offset: -1)
                                } label: {
                                    Image(systemName: "arrow.up")
                                }
                                .buttonStyle(.borderless)
                                .disabled(index == 0)

                                Button {
                                    movePreferredLanguage(from: index, offset: 1)
                                } label: {
                                    Image(systemName: "arrow.down")
                                }
                                .buttonStyle(.borderless)
                                .disabled(index == selectedLanguageOptions.count - 1)

                                Button {
                                    removePreferredLanguage(option.code)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(theme.statusError)
                            }
                        }
                        .padding(10)
                        .background(theme.panelBackground)
                        .cornerRadius(10)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Menu {
                    if availableLanguageOptions.isEmpty {
                        Button("All supported languages are already selected") {}
                            .disabled(true)
                    } else {
                        ForEach(availableLanguageOptions) { option in
                            Button("\(option.name) (\(option.code))") {
                                addPreferredLanguage(option.code)
                            }
                            .disabled(!canAddMoreLanguages)
                        }
                    }
                } label: {
                    Label(canAddMoreLanguages ? "Add Language Hint" : "Maximum Reached", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .medium))
                }
                .disabled(!canAddMoreLanguages || availableLanguageOptions.isEmpty)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 8)], spacing: 8) {
                    ForEach(quickAddLanguageOptions) { option in
                        Button {
                            addPreferredLanguage(option.code)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: configuration.preferredLanguageCodes.contains(option.code) ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(option.name)
                                    .lineLimit(1)
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(configuration.preferredLanguageCodes.contains(option.code) ? theme.statusSuccess : theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(theme.controlBackground)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(configuration.preferredLanguageCodes.contains(option.code) || !canAddMoreLanguages)
                    }
                }
            }

            if configuration.preferredLanguageCodes.count < 2 {
                Text("AWS recommends at least 2 candidate languages for automatic language identification.")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.statusWarning)
            }
        }
    }

    private func saveConfiguration() {
        let trimmedRegion = configuration.region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRegion.isEmpty else {
            errorMessage = "AWS region is required."
            return
        }

        configuration.region = trimmedRegion

        switch configuration.authMethod {
        case .profile:
            let trimmedProfile = configuration.profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedProfile.isEmpty else {
                errorMessage = "AWS profile name is required."
                return
            }
            configuration.profileName = trimmedProfile
            configuration.accessKeyId = ""
            configuration.sessionToken = ""
            secretAccessKey = ""

        case .accessKey:
            let trimmedAccessKey = configuration.accessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSecret = secretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAccessKey.isEmpty else {
                errorMessage = "AWS access key ID is required."
                return
            }
            guard !trimmedSecret.isEmpty else {
                errorMessage = "AWS secret access key is required."
                return
            }
            configuration.accessKeyId = trimmedAccessKey
            configuration.profileName = ""
            configuration.sessionToken = configuration.sessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        configuration.preferredLanguageCodes = AmazonTranscribeConfigurationStore.normalizedPreferredLanguageCodes(configuration.preferredLanguageCodes)
        guard !configuration.preferredLanguageCodes.isEmpty else {
            errorMessage = "Add at least one language hint for Amazon Transcribe."
            return
        }

        AmazonTranscribeConfigurationStore.shared.save(configuration, secretAccessKey: secretAccessKey)
        availableProfiles = AmazonTranscribeConfigurationStore.shared.availableProfiles()
        errorMessage = nil
        onSave()
    }

    private func addPreferredLanguage(_ languageCode: String) {
        guard canAddMoreLanguages, !configuration.preferredLanguageCodes.contains(languageCode) else {
            return
        }
        configuration.preferredLanguageCodes.append(languageCode)
    }

    private func removePreferredLanguage(_ languageCode: String) {
        configuration.preferredLanguageCodes.removeAll { $0 == languageCode }
    }

    private func movePreferredLanguage(from index: Int, offset: Int) {
        let destination = index + offset
        guard configuration.preferredLanguageCodes.indices.contains(index),
              configuration.preferredLanguageCodes.indices.contains(destination) else {
            return
        }

        let moved = configuration.preferredLanguageCodes.remove(at: index)
        configuration.preferredLanguageCodes.insert(moved, at: destination)
    }
}
