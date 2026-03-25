import SwiftUI
import AppKit

// MARK: - Cloud Model Card View
struct CloudModelCardView: View {
    let model: CloudModel
    let isCurrent: Bool
    var setDefaultAction: () -> Void
    @Environment(\.theme) private var theme
    
    @EnvironmentObject private var whisperState: WhisperState
    @State private var isExpanded = false
    @State private var apiKey = ""
    @State private var isVerifying = false
    @State private var verificationStatus: VerificationStatus = .none
    @State private var isConfiguredState: Bool = false
    @State private var verificationError: String? = nil
    @State private var apiKeyEntries: [CloudAPIKeyEntry] = []
    @State private var activeKeyId: UUID? = nil
    
    enum VerificationStatus {
        case none, verifying, success, failure
    }
    
    private var isConfigured: Bool {
        if model.provider == .amazonTranscribe {
            return AmazonTranscribeConfigurationStore.shared.isConfigured()
        }
        return CloudAPIKeyManager.shared.hasKeys(for: providerKey)
    }
    
    private var providerKey: String {
        switch model.provider {
        case .groq:
            return "GROQ"
        case .elevenLabs:
            return "ElevenLabs"
        case .openAI:
            return "OpenAI"
        case .amazonTranscribe:
            return "Amazon Transcribe"
        default:
            return model.provider.rawValue
        }
    }
    
    private var sanitizedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    headerSection
                    metadataSection
                    descriptionSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                actionSection
            }
            .padding(16)
            
            // Expandable configuration section
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                configurationSection
                    .padding(16)
            }
        }
        .background(CardBackground(isSelected: isCurrent, useAccentGradientWhenSelected: isCurrent))
        .onAppear {
            loadKeys()
            isConfiguredState = isConfigured
        }
    }
    
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(model.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            statusBadge
            
            Spacer()
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            if isStreamingModel {
                Text("Realtime")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.statusInfo.opacity(0.18)))
                    .foregroundColor(theme.statusInfo)
            }

            if isCurrent {
                Text("Default")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.accentColor))
                    .foregroundColor(theme.primaryButtonText)
            } else if isConfiguredState {
                Text("Configured")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.statusSuccess.opacity(0.2)))
                    .foregroundColor(theme.statusSuccess)
            } else {
                Text("Setup Required")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(theme.statusWarning.opacity(0.2)))
                    .foregroundColor(theme.statusWarning)
            }
        }
    }
    
    private var metadataSection: some View {
        HStack(spacing: 12) {
            // Provider
            Label(model.provider.rawValue, systemImage: "cloud")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            
            // Language
            Label(model.language, systemImage: "globe")
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            
            Label(modelTypeLabel, systemImage: modelTypeIcon)
                .font(.system(size: 11))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
            
            // Accuracy
            HStack(spacing: 3) {
                Text("Accuracy")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                progressDotsWithNumber(value: model.accuracy * 10, theme: theme)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .lineLimit(1)
    }
    
    private var descriptionSection: some View {
        Text(model.description)
            .font(.system(size: 11))
            .foregroundColor(theme.textSecondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)
    }
    
    private var actionSection: some View {
        HStack(spacing: 8) {
            if isCurrent {
                Text("Default Model")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondary)
            } else if isConfiguredState {
                Button(action: setDefaultAction) {
                    Text("Set as Default")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button(action: {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Configure")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "gear")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(theme.accentColor)
                            .shadow(color: theme.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            
            if isConfiguredState {
                Menu {
                    Button {
                        withAnimation(.interpolatingSpring(stiffness: 170, damping: 20)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Label(managementMenuTitle, systemImage: managementMenuIcon)
                    }
                    
                    Button {
                        clearAPIKey()
                    } label: {
                        Label(removalMenuTitle, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 20, height: 20)
            }
        }
    }

    private var isStreamingModel: Bool {
        model.usesRealtimeStreaming
    }

    private var modelTypeLabel: String {
        isStreamingModel ? String(localized: "Cloud Streaming Model") : String(localized: "Cloud Batch Model")
    }

    private var modelTypeIcon: String {
        isStreamingModel ? "waveform.badge.magnifyingglass" : "icloud"
    }

    private var managementMenuTitle: String {
        model.provider == .amazonTranscribe ? "Manage AWS Config" : "Manage API Keys"
    }

    private var managementMenuIcon: String {
        model.provider == .amazonTranscribe ? "gearshape.2" : "key"
    }

    private var removalMenuTitle: String {
        model.provider == .amazonTranscribe ? "Remove Configuration" : "Remove API Key"
    }
    
    private var configurationSection: some View {
        if model.provider == .amazonTranscribe {
            AnyView(
                AmazonTranscribeConfigurationView {
                    loadKeys()
                    isConfiguredState = isConfigured
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded = false
                    }
                }
            )
        } else {
            AnyView(legacyAPIKeyConfigurationSection)
        }
    }

    private var legacyAPIKeyConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("API Key Configuration")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(theme.textPrimary)
            
            if apiKeyEntries.isEmpty {
                // Initial state: no keys yet, show simple input
                HStack(spacing: 8) {
                    SecureField("Enter your \(model.provider.rawValue) API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isVerifying)
                    
                    Button(action: verifyAPIKey) {
                        HStack(spacing: 4) {
                            if isVerifying {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: verificationStatus == .success ? "checkmark" : "checkmark.shield")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            Text(isVerifying ? "Verifying..." : "Verify")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(verificationStatus == .success ? theme.statusSuccess : theme.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(sanitizedAPIKey.isEmpty || isVerifying)
                }
            } else {
                // Multiple keys management
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(apiKeyEntries) { entry in
                        HStack(spacing: 8) {
                            if activeKeyId == entry.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(theme.statusSuccess)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Text(maskedKey(entry.value))
                                .font(.system(.body, design: .monospaced))
                            
                            Spacer()
                            
                            Text(formatLastUsed(entry.lastUsedAt))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                            
                            if activeKeyId != entry.id {
                                Button("Use") {
                                    selectKey(entry)
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            Button {
                                removeKey(entry)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(theme.statusError)
                        }
                    }
                }
                .padding(8)
                .background(theme.panelBackground)
                .cornerRadius(8)
                
                HStack {
                    Button {
                        rotateToNextKey()
                    } label: {
                        Label("Next Key", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Another API Key")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    
                    HStack(spacing: 8) {
                        SecureField("Enter your \(model.provider.rawValue) API key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isVerifying)
                        
                        Button(action: verifyAPIKey) {
                            HStack(spacing: 4) {
                                if isVerifying {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 12, height: 12)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                Text(isVerifying ? "Verifying..." : "Verify")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(theme.accentColor)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(sanitizedAPIKey.isEmpty || isVerifying)
                    }
                }
            }
            
            if verificationStatus == .failure {
                if let error = verificationError {
                    Text(error)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.statusError)
                } else {
                    Text("Verification failed")
                        .font(theme.typography.caption)
                        .foregroundColor(theme.statusError)
                }
            } else if verificationStatus == .success && apiKeyEntries.count == 1 {
                // Only show initial success message in the first-time flow
                Text("API key verified successfully!")
                    .font(theme.typography.caption)
                    .foregroundColor(theme.statusSuccess)
            }
        }
    }
    
    private func loadKeys() {
        if model.provider == .amazonTranscribe {
            apiKeyEntries = []
            activeKeyId = nil
            verificationStatus = .none
            verificationError = nil
            apiKey = ""
            return
        }

        let manager = CloudAPIKeyManager.shared
        apiKeyEntries = manager.keys(for: providerKey)
        activeKeyId = manager.activeKeyId(for: providerKey)
        verificationStatus = .none
        verificationError = nil
        apiKey = ""
    }
    
    private func verifyAPIKey() {
        guard model.provider != .amazonTranscribe else { return }

        let sanitizedKey = sanitizedAPIKey
        guard !sanitizedKey.isEmpty else { return }
        
        if apiKey != sanitizedKey {
            apiKey = sanitizedKey
        }
        
        isVerifying = true
        verificationStatus = .verifying
        
        // Verify the API key based on the provider type
        switch model.provider {
        case .groq:
            // For transcription providers, save key directly (no AIProvider mapping needed)
            handleVerificationResult(isValid: true, errorMessage: nil)
        case .elevenLabs:
            // ElevenLabs is a transcription-only provider, verify directly
            verifyElevenLabsAPIKey(sanitizedKey) { isValid, errorMessage in
                self.handleVerificationResult(isValid: isValid, errorMessage: errorMessage)
            }
        case .openAI:
            verifyOpenAIAPIKey(sanitizedKey) { isValid, errorMessage in
                self.handleVerificationResult(isValid: isValid, errorMessage: errorMessage)
            }
        default:
            // For other providers, just save the key without verification
            print("Warning: verifyAPIKey called for unsupported provider \(model.provider.rawValue)")
            self.handleVerificationResult(isValid: true, errorMessage: nil)
        }
    }
    
    private func handleVerificationResult(isValid: Bool, errorMessage: String?) {
        DispatchQueue.main.async {
            self.isVerifying = false
            if isValid {
                self.verificationStatus = .success
                self.verificationError = nil
                
                let manager = CloudAPIKeyManager.shared
                guard manager.addKey(self.apiKey, for: self.providerKey) != nil else {
                    self.verificationStatus = .failure
                    self.verificationError = "Failed to securely save API key to Keychain."
                    return
                }
                self.loadKeys()
                self.isConfiguredState = true
                
                // Collapse the configuration section after successful verification
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.isExpanded = false
                }
            } else {
                self.verificationStatus = .failure
                self.verificationError = errorMessage
            }
        }
    }
    
    private func verifyElevenLabsAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://api.elevenlabs.io/v1/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(key, forHTTPHeaderField: "xi-api-key")
        
        URLSession.shared.dataTask(with: request) { data, response, _ in
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200
            
            if let data = data, let body = String(data: data, encoding: .utf8) {
                if !isValid {
                    completion(false, body)
                    return
                }
            }
            
            completion(isValid, nil)
        }.resume()
    }

    private func verifyOpenAIAPIKey(_ key: String, completion: @escaping (Bool, String?) -> Void) {
        let modelID = model.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model.name
        let url = URL(string: "https://api.openai.com/v1/models/\(modelID)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let isValid = (response as? HTTPURLResponse)?.statusCode == 200

            if let data = data, let body = String(data: data, encoding: .utf8), !isValid {
                completion(false, body)
                return
            }

            completion(isValid, nil)
        }.resume()
    }
    
    private func clearAPIKey() {
        if model.provider == .amazonTranscribe {
            AmazonTranscribeConfigurationStore.shared.clear()
            apiKey = ""
            verificationStatus = .none
            verificationError = nil
            isConfiguredState = false
            apiKeyEntries = []
            activeKeyId = nil

            if isCurrent {
                Task {
                    await MainActor.run {
                        whisperState.currentTranscriptionModel = nil
                        UserDefaults.hoah.removeObject(forKey: "CurrentTranscriptionModel")
                    }
                }
            }

            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded = false
            }
            return
        }

        let manager = CloudAPIKeyManager.shared
        manager.removeAllKeys(for: providerKey)
        apiKey = ""
        verificationStatus = .none
        verificationError = nil
        isConfiguredState = false
        apiKeyEntries = []
        activeKeyId = nil
        
        // If this model is currently the default, clear it
        if isCurrent {
            Task {
                await MainActor.run {
                    whisperState.currentTranscriptionModel = nil
                    UserDefaults.hoah.removeObject(forKey: "CurrentTranscriptionModel")
                }
            }
        }
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isExpanded = false
        }
    }
    
    private func selectKey(_ entry: CloudAPIKeyEntry) {
        let manager = CloudAPIKeyManager.shared
        manager.selectKey(id: entry.id, for: providerKey)
        loadKeys()
    }
    
    private func removeKey(_ entry: CloudAPIKeyEntry) {
        let manager = CloudAPIKeyManager.shared
        manager.removeKey(id: entry.id, for: providerKey)
        loadKeys()
        isConfiguredState = !apiKeyEntries.isEmpty
    }
    
    private func rotateToNextKey() {
        let manager = CloudAPIKeyManager.shared
        if manager.rotateKey(for: providerKey) {
            loadKeys()
        }
    }
    
    private func maskedKey(_ key: String) -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return String(repeating: "•", count: 8) }
        let suffix = trimmed.suffix(4)
        return "••••\(suffix)"
    }
    
    private func formatLastUsed(_ date: Date?) -> String {
        guard let date = date else { return "Never used" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
