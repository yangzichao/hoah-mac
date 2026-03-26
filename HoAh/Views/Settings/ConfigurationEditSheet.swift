import SwiftUI

/// Sheet for creating or editing AI Configuration
/// Designed with a focus on modern, premium aesthetics using clean typography, content grouping, and distinct interactive elements.
struct ConfigurationEditSheet: View {
    enum Mode: Equatable {
        case add
        case edit(AIEnhancementConfiguration)
        
        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.add, .add):
                return true
            case let (.edit(config1), .edit(config2)):
                return config1.id == config2.id
            default:
                return false
            }
        }
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appSettings: AppSettingsStore
    @EnvironmentObject private var aiService: AIService
    @Environment(\.theme) private var theme
    
    // Form state
    @State private var name: String
    @State private var selectedProvider: AIProvider
    @State private var apiKey: String
    @State private var selectedModel: String
    @State private var region: String
    @State private var enableCrossRegion: Bool
    @State private var doubaoModelGroup: DoubaoModelGroup
    @State private var azureEndpoint: String
    @State private var ociRegion: String
    @State private var ollamaEndpoint: String
    
    // AWS Authentication state
    enum AWSAuthMethod: String, CaseIterable {
        case apiKey = "API Key"
        case accessKey = "Access Key"
        case profile = "AWS Profile"
        
        var localizedName: String {
            switch self {
            case .apiKey: return NSLocalizedString("API Key", comment: "Auth method")
            case .accessKey: return NSLocalizedString("Access Key", comment: "Auth method")
            case .profile: return NSLocalizedString("AWS Profile", comment: "Auth method")
            }
        }
    }
    @State private var awsAuthMethod: AWSAuthMethod = .apiKey
    @State private var selectedAWSProfile: String = ""
    @State private var availableAWSProfiles: [String] = []
    @State private var awsAccessKeyId: String = ""
    @State private var awsSecretAccessKey: String = ""
    
    // Verification state
    @State private var isVerifying = false
    @State private var verificationError: String?
    @State private var showError = false
    
    // UI Helpers
    @FocusState private var focusedField: String?
    @State private var hoveredProvider: Bool = false
    
    private let awsProfileService = AWSProfileService()
    
    init(mode: Mode) {
        self.mode = mode
        
        switch mode {
        case .add:
            let defaultProvider = AIProvider.groq
            _name = State(initialValue: "")
            _selectedProvider = State(initialValue: defaultProvider)
            _apiKey = State(initialValue: "")
            _selectedModel = State(initialValue: defaultProvider.defaultModel)
            _region = State(initialValue: "us-east-1")
            _enableCrossRegion = State(initialValue: true)
            _doubaoModelGroup = State(initialValue: .seedFlash)
            _azureEndpoint = State(initialValue: "")
            _ociRegion = State(initialValue: "us-chicago-1")
            _ollamaEndpoint = State(initialValue: "http://localhost:11434")
        case .edit(let config):
            let provider = AIProvider(rawValue: config.provider) ?? .gemini
            _name = State(initialValue: config.name)
            _selectedProvider = State(initialValue: provider)
            _apiKey = State(initialValue: config.getApiKey() ?? "")
            _selectedModel = State(initialValue: config.model)
            _region = State(initialValue: config.region ?? "us-east-1")
            _enableCrossRegion = State(initialValue: true)
            _doubaoModelGroup = State(initialValue: provider == .doubao ? DoubaoModelGroup.infer(from: config.model) : .seedFlash)
            _azureEndpoint = State(initialValue: provider == .azureOpenAI ? (config.customEndpoint ?? "") : "")
            _ociRegion = State(initialValue: provider == .ociGenerativeAI ? (config.region ?? "us-chicago-1") : "us-chicago-1")
            _ollamaEndpoint = State(initialValue: provider == .ollama ? (config.customEndpoint ?? "http://localhost:11434") : "http://localhost:11434")

            if let profileName = config.awsProfileName, !profileName.isEmpty {
                _awsAuthMethod = State(initialValue: .profile)
                _selectedAWSProfile = State(initialValue: profileName)
            } else if let accessKey = config.awsAccessKeyId, !accessKey.isEmpty {
                _awsAuthMethod = State(initialValue: .accessKey)
                _awsAccessKeyId = State(initialValue: accessKey)
                _awsSecretAccessKey = State(initialValue: config.getAwsSecretAccessKey() ?? "")
            } else {
                _awsAuthMethod = State(initialValue: .apiKey)
            }
        }
    }
    
    private var headerTitle: String {
        mode == .add 
            ? NSLocalizedString("New AI Configuration", comment: "Header title for adding configuration")
            : NSLocalizedString("Edit Configuration", comment: "Header title for editing configuration")
    }
    
    private var canVerify: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasModel = selectedProvider == .doubao
            ? true
            : !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasName && hasModel && hasValidAuthentication
    }
    
    private var hasValidAuthentication: Bool {
        switch selectedProvider {
        case .awsBedrock:
            let hasRegion = !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            switch awsAuthMethod {
            case .apiKey:
                return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasRegion
            case .accessKey:
                return !awsAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                       !awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasRegion
            case .profile:
                if availableAWSProfiles.isEmpty {
                    // Lazy load when user flips to profile auth after switching provider
                    availableAWSProfiles = awsProfileService.listProfiles()
                }
                return !selectedAWSProfile.isEmpty && hasRegion
            }
        case .ollama:
            // Local provider, no API key needed
            return true
        case .azureOpenAI:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !azureEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .ociGenerativeAI:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !ociRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: Hero Header
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [theme.accentColor.opacity(0.12), theme.accentColor.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [theme.accentColor, theme.accentColor.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(theme.typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textPrimary)
                    Text(NSLocalizedString("Configure your AI provider settings", comment: "Header subtitle"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
            }
            .padding(24)
            .background(theme.windowBackground)
            
            Divider()
                .opacity(0.5)
            
            // MARK: Scrollable Content
            ScrollView {
                VStack(spacing: 32) {
                    
                    // -- Section: Essentials --
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: NSLocalizedString("Essentials", comment: "Section header"), systemImage: "slider.horizontal.3")
                        
                        VStack(spacing: 16) {
                            // Name Input
                            PremiumLabeledInput(
                                label: NSLocalizedString("Name", comment: "Input label"),
                                description: NSLocalizedString("A friendly name for this configuration", comment: "Input description")
                            ) {
                                TextField(NSLocalizedString("e.g., My AI configuration", comment: "Placeholder"), text: $name)
                                    .focused($focusedField, equals: "name")
                                    .textFieldStyle(.plain)
                                    .modifier(PremiumInputModifier(isFocused: focusedField == "name"))
                            }
                            
                            // Provider Selection
                            PremiumLabeledInput(
                                label: NSLocalizedString("Provider", comment: "Input label"),
                                description: NSLocalizedString("The AI service backend", comment: "Input description")
                            ) {
                                PremiumPicker(
                                    selection: $selectedProvider,
                                    options: AIProvider.providers(forLanguage: appSettings.appInterfaceLanguage),
                                    labelMapper: { $0.pickerDisplayName }
                                )
                            }
                        }
                    }
                    
                    // -- Section: Authentication --
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: NSLocalizedString("Authentication", comment: "Section header"), systemImage: "key.fill")
                        
                        // Auth Method Picker for Bedrock (if applicable)
                        if selectedProvider == .awsBedrock {
                            Picker("", selection: $awsAuthMethod) {
                                ForEach(AWSAuthMethod.allCases, id: \.self) { method in
                                    Text(method.localizedName).tag(method)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 8)
                        }
                        
                        authenticationContent
                    }
                    
                    // -- Section: Model & Capabilities --
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: NSLocalizedString("Model & Capabilities", comment: "Section header"), systemImage: "cpu.fill")
                        
                        VStack(spacing: 16) {
                             if selectedProvider == .awsBedrock {
                                 HStack(spacing: 16) {
                                     // Region Selector
                                     PremiumLabeledInput(label: NSLocalizedString("Region", comment: "Input label")) {
                                         PremiumPicker(
                                            selection: $region,
                                            options: awsRegions,
                                            labelMapper: { $0 }
                                         )
                                     }
                                 }
                             } else if selectedProvider == .ociGenerativeAI {
                                 PremiumLabeledInput(
                                    label: NSLocalizedString("Region", comment: "Input label"),
                                    description: NSLocalizedString("OCI region that hosts both the API key and model endpoint", comment: "Input description")
                                 ) {
                                     PremiumPicker(
                                        selection: $ociRegion,
                                        options: ociRegions,
                                        labelMapper: { $0 }
                                     )
                                 }
                             }
                            
                            // Model Input
                            modelContent
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
            .background(theme.controlBackground.opacity(0.5))
            
            Divider()
                .opacity(0.5)
            
            // MARK: Footer Actions
            HStack(spacing: 16) {
                Button(NSLocalizedString("Cancel", comment: "Button title")) { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.controlBackground)
                            .shadow(color: theme.shadowColor.opacity(0.05), radius: 1, x: 0, y: 1)
                    )
                    .overlay(
                         RoundedRectangle(cornerRadius: 8)
                             .stroke(theme.panelBorder, lineWidth: 1)
                    )
                
                Spacer()
                
                Button(action: verifyAndSave) {
                    HStack(spacing: 8) {
                        if isVerifying {
                            ProgressView()
                                .controlSize(.small)
                                .colorInvert()
                                .brightness(1)
                        }
                        Text(isVerifying ? NSLocalizedString("Verifying...", comment: "Button state") : NSLocalizedString("Verify & Save", comment: "Button title"))
                    }
                    .font(theme.typography.body.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [theme.accentColor, theme.accentColor.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                            .opacity(canVerify ? 1 : 0.5)
                    )
                    .cornerRadius(8)
                    .shadow(color: theme.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(!canVerify || isVerifying)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(20)
            .background(theme.windowBackground)
        }
        .frame(width: 550, height: 700)
        .onChange(of: selectedProvider) { oldProvider, newProvider in
            // Only reset model if provider actually changed
            if oldProvider != newProvider {
                // In edit mode, preserve model if it's compatible with new provider
                // For providers with empty availableModels (like OpenRouter), always preserve user input
                let availableModels = modelsForProvider(newProvider)
                if availableModels.isEmpty {
                    // OpenRouter or similar - keep user's custom model unless switching from a different provider
                    if case .add = mode {
                        selectedModel = defaultModel(for: newProvider)
                    }
                    // In edit mode, preserve the model for custom input providers
                } else if !availableModels.contains(selectedModel) {
                    // Model not available in new provider, reset to default
                    selectedModel = defaultModel(for: newProvider)
                }
                // If model is available in new provider, keep it
            }
            
            if newProvider != .awsBedrock {
                awsAuthMethod = .apiKey
            }
            if newProvider == .awsBedrock {
                // Refresh profiles when switching to AWS provider
                availableAWSProfiles = awsProfileService.listProfiles()
            }
            if newProvider == .doubao {
                doubaoModelGroup = .seedFlash
                selectedModel = ""
            }
            if newProvider != .azureOpenAI {
                azureEndpoint = ""
            }
            if newProvider == .ollama && oldProvider != .ollama {
                ollamaEndpoint = "http://localhost:11434"
            }
            if newProvider == .openRouter {
                Task { await aiService.fetchOpenRouterModels() }
            }
            if newProvider == .cerebras {
                Task { await aiService.fetchCerebrasModels(apiKey: apiKey) }
            }
            verificationError = nil
        }
        .onChange(of: region) { _, _ in
            normalizeBedrockSelectionIfNeeded()
        }
        .onChange(of: enableCrossRegion) { _, _ in
            normalizeBedrockSelectionIfNeeded()
        }
        .onChange(of: doubaoModelGroup) { _, _ in
            if selectedProvider == .doubao {
                selectedModel = ""
            }
        }
        .onAppear {
            if selectedProvider == .awsBedrock {
                availableAWSProfiles = awsProfileService.listProfiles()
            }
            if selectedProvider == .openRouter {
                Task { await aiService.fetchOpenRouterModels() }
            }
            if selectedProvider == .cerebras {
                Task { await aiService.fetchCerebrasModels(apiKey: apiKey) }
            }
            if case .add = mode { focusedField = "name" }
        }
        .alert(NSLocalizedString("Verification Failed", comment: "Alert title"), isPresented: $showError) {
            Button(NSLocalizedString("OK", comment: "Button title"), role: .cancel) {}
            Button(NSLocalizedString("Save Anyway", comment: "Button title")) {
                saveConfiguration()
                dismiss()
            }
        } message: {
            Text(verificationError ?? NSLocalizedString("Unknown error", comment: "Error message"))
        }
    }
    
    // MARK: - Subviews & Helpers
    
    @ViewBuilder
    private var authenticationContent: some View {
        Group {
            if selectedProvider == .awsBedrock {
                switch awsAuthMethod {
                case .apiKey:
                    SecureInputView(
                        text: $apiKey,
                        placeholder: "sk-...",
                        label: NSLocalizedString("Bearer Token", comment: "Input label")
                    )
                case .accessKey:
                    VStack(spacing: 16) {
                        PremiumLabeledInput(label: NSLocalizedString("Access Key ID", comment: "Input label")) {
                            TextField("AKIA...", text: $awsAccessKeyId)
                                .textFieldStyle(.plain)
                                .modifier(PremiumInputModifier())
                        }
                        SecureInputView(
                            text: $awsSecretAccessKey,
                            placeholder: NSLocalizedString("Secret Access Key", comment: "Placeholder"),
                            label: NSLocalizedString("Secret Key", comment: "Input label")
                        )
                    }
                case .profile:
                    PremiumLabeledInput(
                        label: NSLocalizedString("Profile", comment: "Input label"), // Localized
                        description: NSLocalizedString("From ~/.aws/credentials or ~/.aws/config", comment: "Description")
                    ) {
                         if availableAWSProfiles.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(theme.statusWarning)
                                Text(NSLocalizedString("No profiles found", comment: "Error message"))
                                    .font(theme.typography.subheadline)
                                    .foregroundColor(theme.textSecondary)
                            }
                            .modifier(PremiumInputModifier())
                        } else {
                            PremiumPicker(
                                selection: $selectedAWSProfile,
                                options: availableAWSProfiles,
                                labelMapper: { $0.isEmpty ? NSLocalizedString("Select Profile", comment: "Placeholder") : $0 }
                            )
                        }
                    }
                }
            } else if selectedProvider == .ollama {
                // Ollama is local, no API key needed
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(theme.statusSuccess)
                        Text(NSLocalizedString("No authentication required", comment: "Ollama auth info"))
                            .font(theme.typography.subheadline)
                            .foregroundColor(theme.textSecondary)
                    }
                    .modifier(PremiumInputModifier())

                    // Custom endpoint input
                    PremiumLabeledInput(
                        label: NSLocalizedString("Endpoint", comment: "Input label"),
                        description: NSLocalizedString("Default: http://localhost:11434", comment: "Endpoint description")
                    ) {
                        TextField("http://localhost:11434", text: $ollamaEndpoint)
                            .textFieldStyle(.plain)
                            .modifier(PremiumInputModifier())
                    }

                    Text(NSLocalizedString("Ollama runs locally. Make sure it's running with 'ollama serve'.", comment: "Ollama help"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                        .padding(.leading, 2)
                }
            } else if selectedProvider == .azureOpenAI {
                VStack(alignment: .leading, spacing: 12) {
                    SecureInputView(
                        text: $apiKey,
                        placeholder: "AZURE_OPENAI_API_KEY",
                        label: NSLocalizedString("API Key", comment: "Input label")
                    )

                    PremiumLabeledInput(
                        label: NSLocalizedString("Endpoint", comment: "Input label"),
                        description: NSLocalizedString("Azure resource URL, e.g. https://YOUR-RESOURCE.openai.azure.com", comment: "Endpoint description")
                    ) {
                        TextField("https://YOUR-RESOURCE.openai.azure.com", text: $azureEndpoint)
                            .textFieldStyle(.plain)
                            .modifier(PremiumInputModifier())
                    }

                    Text(NSLocalizedString("Azure OpenAI uses your deployment name as the model value. The app normalizes the endpoint to /openai/v1 automatically.", comment: "Azure OpenAI help"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                        .padding(.leading, 2)

                    if let url = selectedProvider.apiKeyURL {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("Open Azure AI Foundry", comment: "Button title"))
                                Image(systemName: "arrow.up.right")
                            }
                            .font(theme.typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.accentColor)
                        }
                        .padding(.leading, 2)
                    }
                }
            } else if selectedProvider == .ociGenerativeAI {
                VStack(alignment: .leading, spacing: 12) {
                    SecureInputView(
                        text: $apiKey,
                        placeholder: "sk-...",
                        label: NSLocalizedString("API Key", comment: "Input label")
                    )

                    Text(NSLocalizedString("HoAh will call OCI Generative AI via Oracle's OpenAI-compatible chat completions endpoint. The API key and model must be in the same OCI region.", comment: "OCI auth help"))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                        .padding(.leading, 2)

                    if let url = selectedProvider.apiKeyURL {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("Open OCI Console", comment: "Button title"))
                                Image(systemName: "arrow.up.right")
                            }
                            .font(theme.typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.accentColor)
                        }
                        .padding(.leading, 2)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    SecureInputView(
                        text: $apiKey,
                        placeholder: "st-...",
                        label: NSLocalizedString("API Key", comment: "Input label")
                    )

                    if let url = selectedProvider.apiKeyURL {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("Get API Key", comment: "Button title"))
                                Image(systemName: "arrow.up.right")
                            }
                            .font(theme.typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(theme.accentColor)
                        }
                        .padding(.top, 4)
                        .padding(.leading, 2)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var modelContent: some View {
        let availableModels = modelsForProvider(selectedProvider)
        VStack(alignment: .leading, spacing: 12) {
            if selectedProvider == .doubao {
                PremiumLabeledInput(
                    label: NSLocalizedString("Model", comment: "Input label"),
                    description: NSLocalizedString("Choose a Doubao/DeepSeek model group. The app will auto-resolve a working Model ID.", comment: "Input description")
                ) {
                    PremiumPicker(
                        selection: $doubaoModelGroup,
                        options: DoubaoModelGroup.allCases,
                        labelMapper: { $0.displayName }
                    )
                }
                
                if !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(String(format: NSLocalizedString("Resolved Model ID: %@", comment: "Doubao resolved model"), selectedModel))
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary)
                        .padding(.leading, 2)
                }
            } else if selectedProvider == .ollama {
                // Ollama: show recommended models + custom input
                PremiumLabeledInput(
                    label: NSLocalizedString("Model", comment: "Input label"),
                    description: NSLocalizedString("Select or enter your local model name", comment: "Input description")
                ) {
                    VStack(spacing: 12) {
                        // Recommended models picker
                        PremiumPicker(
                            selection: $selectedModel,
                            options: availableModels,
                            labelMapper: { $0.isEmpty ? NSLocalizedString("Select Model", comment: "Placeholder") : $0 }
                        )

                        // Custom input
                        HStack(spacing: 8) {
                            Text(NSLocalizedString("Or custom:", comment: "Custom model label"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                            TextField("mistral:7b, deepseek-r1:8b...", text: $selectedModel)
                                .textFieldStyle(.plain)
                                .modifier(PremiumInputModifier())
                        }
                    }
                }

                Text(NSLocalizedString("Run 'ollama list' to see your installed models", comment: "Ollama help"))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.leading, 2)
            } else if selectedProvider == .openRouter {
                PremiumLabeledInput(
                    label: NSLocalizedString("Model", comment: "Input label"),
                    description: NSLocalizedString("Pick a recommended OpenRouter model or enter any model ID", comment: "Input description")
                ) {
                    VStack(spacing: 12) {
                        PremiumPicker(
                            selection: $selectedModel,
                            options: availableModels,
                            labelMapper: { $0.isEmpty ? NSLocalizedString("Select Model", comment: "Placeholder") : $0 }
                        )

                        HStack(spacing: 8) {
                            Text(NSLocalizedString("Or custom:", comment: "Custom model label"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                            TextField("openai/gpt-4.1-mini, google/gemini-2.5-flash-lite...", text: $selectedModel)
                                .textFieldStyle(.plain)
                                .modifier(PremiumInputModifier())
                        }
                    }
                }
            } else if selectedProvider == .azureOpenAI {
                PremiumLabeledInput(
                    label: NSLocalizedString("Model", comment: "Input label"),
                    description: NSLocalizedString("Enter the Azure deployment name, not just the base model family", comment: "Input description")
                ) {
                    TextField("gpt-4.1-prod", text: $selectedModel)
                        .textFieldStyle(.plain)
                        .modifier(PremiumInputModifier())
                }

                Text(NSLocalizedString("Azure returns 400/404 when the deployment name is wrong, even if the API key and resource endpoint are valid.", comment: "Azure deployment hint"))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.leading, 2)
            } else if selectedProvider == .ociGenerativeAI {
                PremiumLabeledInput(
                    label: NSLocalizedString("Model", comment: "Input label"),
                    description: NSLocalizedString("Choose a fast OCI-hosted model or enter any supported model ID", comment: "Input description")
                ) {
                    VStack(spacing: 12) {
                        PremiumPicker(
                            selection: $selectedModel,
                            options: availableModels,
                            labelMapper: { $0.isEmpty ? NSLocalizedString("Select Model", comment: "Placeholder") : $0 }
                        )

                        HStack(spacing: 8) {
                            Text(NSLocalizedString("Or custom:", comment: "Custom model label"))
                                .font(theme.typography.caption)
                                .foregroundColor(theme.textSecondary)
                            TextField("openai.gpt-oss-20b, xai.grok-4...", text: $selectedModel)
                                .textFieldStyle(.plain)
                                .modifier(PremiumInputModifier())
                        }
                    }
                }

                Text(NSLocalizedString("Oracle exposes Chat Completions at /20231130/actions/v1/chat/completions with Bearer auth. Responses API is not wired into HoAh yet.", comment: "OCI model hint"))
                    .font(theme.typography.caption)
                    .foregroundColor(theme.textSecondary)
                    .padding(.leading, 2)
            } else {
                PremiumLabeledInput(
                    label: NSLocalizedString("Model", comment: "Input label"),
                    description: NSLocalizedString("The specific model version to use", comment: "Input description")
                ) {
                    if availableModels.isEmpty {
                        TextField(NSLocalizedString("e.g. gpt-4-turbo", comment: "Placeholder"), text: $selectedModel)
                            .textFieldStyle(.plain)
                            .modifier(PremiumInputModifier())
                    } else {
                        PremiumPicker(
                            selection: $selectedModel,
                            options: availableModels,
                            labelMapper: { $0.isEmpty ? NSLocalizedString("Select Model", comment: "Placeholder") : $0 }
                        )
                    }
                }
            }
            
            if selectedProvider == .doubao {
                VStack(alignment: .leading, spacing: 6) {
                    Text(NSLocalizedString("Only API Key required. The app will try valid Model IDs automatically.", comment: "Doubao help"))
                    if let url = AIProvider.doubao.apiKeyURL {
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(NSLocalizedString("Open Ark Console", comment: "Button title"))
                                Image(systemName: "arrow.up.right")
                            }
                        }
                    }
                }
                .font(theme.typography.caption)
                .foregroundColor(theme.textSecondary)
                .padding(.leading, 2)
            }
        }
    }
    
    private var awsRegions: [String] {
        ["us-east-1", "us-east-2", "us-west-2", "eu-west-1", "eu-west-2", "eu-central-1", "ap-northeast-1", "ap-northeast-3", "ap-southeast-1", "ap-southeast-2", "ap-southeast-4"]
    }

    private var ociRegions: [String] {
        ["us-chicago-1", "us-ashburn-1", "us-phoenix-1", "sa-saopaulo-1", "eu-frankfurt-1", "uk-london-1", "me-riyadh-1", "me-dubai-1", "ap-hyderabad-1", "ap-osaka-1"]
    }

    private func modelsForProvider(_ provider: AIProvider) -> [String] {
        if provider == .awsBedrock {
            return AIService.bedrockNormalizedModels(
                provider.availableModels,
                region: region,
                enableCrossRegion: enableCrossRegion
            )
        }
        return aiService.availableModels(for: provider)
    }

    private func defaultModel(for provider: AIProvider) -> String {
        if provider == .awsBedrock {
            return AIService.bedrockNormalizedModelId(
                provider.defaultModel,
                region: region,
                enableCrossRegion: enableCrossRegion
            )
        }
        return provider.defaultModel
    }

    private func normalizeBedrockSelectionIfNeeded() {
        guard selectedProvider == .awsBedrock else { return }
        let normalized = AIService.bedrockNormalizedModelId(
            selectedModel,
            region: region,
            enableCrossRegion: enableCrossRegion
        )
        if normalized != selectedModel {
            selectedModel = normalized
        }
    }
    
    // MARK: - Verification Logic (Unchanged)
    
    private func verifyAndSave() {
        isVerifying = true
        verificationError = nil
        
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if selectedProvider == .awsBedrock {
            switch awsAuthMethod {
            case .profile:
                Task { await verifyAWSProfileWithSigV4(profile: selectedAWSProfile, region: region, model: trimmedModel) }
                return
            case .accessKey:
                Task {
                    await verifyAWSAccessKeyWithSigV4(
                        accessKeyId: awsAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines),
                        secretAccessKey: awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines),
                        region: region,
                        model: trimmedModel
                    )
                }
                return
            case .apiKey:
                Task {
                    let result = await AIConfigurationValidator.verifyBedrockBearerToken(
                        apiKey: trimmedApiKey,
                        region: region,
                        modelId: trimmedModel
                    )
                    await MainActor.run {
                        handleVerificationResult(success: result.success, errorMessage: result.errorMessage)
                    }
                }
                return
            }
        }
        
        switch selectedProvider {
        case .awsBedrock: break
        case .doubao: verifyDoubaoKey(trimmedApiKey, modelGroup: doubaoModelGroup)
        case .anthropic: verifyAnthropicKey(trimmedApiKey, model: trimmedModel)
        case .ollama: verifyOllamaConnection(model: trimmedModel)
        default: verifyOpenAICompatibleKey(trimmedApiKey, model: trimmedModel)
        }
    }
    
    private func verifyOpenAICompatibleKey(_ key: String, model: String) {
        Task {
            let endpoint: String?
            if selectedProvider == .azureOpenAI {
                endpoint = selectedProvider.normalizedCustomEndpoint(azureEndpoint)
            } else if selectedProvider == .ociGenerativeAI {
                endpoint = selectedProvider.normalizedCustomEndpoint(AIProvider.ociEndpoint(for: ociRegion))
            } else {
                endpoint = nil
            }
            let result = await AIConfigurationValidator.verifyOpenAICompatibleKey(
                apiKey: key,
                provider: selectedProvider,
                model: model,
                endpoint: endpoint
            )
            await MainActor.run { handleVerificationResult(success: result.success, errorMessage: result.errorMessage) }
        }
    }

    private func verifyDoubaoKey(_ key: String, modelGroup: DoubaoModelGroup) {
        Task {
            let result = await AIConfigurationValidator.verifyDoubaoKey(apiKey: key, modelGroup: modelGroup)
            await MainActor.run {
                if result.success, let resolved = result.resolvedModelId {
                    selectedModel = resolved
                }
                handleVerificationResult(success: result.success, errorMessage: result.errorMessage)
            }
        }
    }
    
    private func verifyAnthropicKey(_ key: String, model: String) {
        Task {
            let result = await AIConfigurationValidator.verifyAnthropicKey(apiKey: key, model: model)
            await MainActor.run { handleVerificationResult(success: result.success, errorMessage: result.errorMessage) }
        }
    }

    private func verifyOllamaConnection(model: String) {
        let endpoint = ollamaEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let result = await AIConfigurationValidator.verifyOllamaConnection(model: model, endpoint: endpoint)
            await MainActor.run { handleVerificationResult(success: result.success, errorMessage: result.errorMessage) }
        }
    }
    
    private func handleVerificationResult(success: Bool, errorMessage: String?) {
        isVerifying = false
        if success {
            saveConfiguration()
            dismiss()
        } else {
            var message = errorMessage ?? NSLocalizedString("Verification failed. Please check your API key and try again.", comment: "Error message")
            if selectedProvider == .doubao {
                let hint = NSLocalizedString("Tip: Auto-resolve may fail if your project doesn’t have a matching Model ID. Check Ark Console → Model list and ensure the API Key belongs to the same project.", comment: "Doubao verify hint")
                message = "\(message)\n\(hint)"
            }
            verificationError = message
            showError = true
        }
    }
    
    private func verifyAWSAccessKeyWithSigV4(accessKeyId: String, secretAccessKey: String, region: String, model: String) async {
        guard isVerifying else { return }
        let credentials = AWSCredentials(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, sessionToken: nil, region: region, expiration: nil, profileName: nil)
        let result = await AIConfigurationValidator.verifyAWSCredentials(credentials: credentials, region: region, modelId: model)
        await MainActor.run {
            guard isVerifying else { return }
            if result.success { isVerifying = false; saveConfiguration(); dismiss() }
            else { handleVerificationResult(success: false, errorMessage: result.errorMessage) }
        }
    }
    
    private func verifyAWSProfileWithSigV4(profile: String, region: String, model: String) async {
        guard isVerifying else { return }
        let credentials: AWSCredentials
        do { credentials = try await awsProfileService.resolveCredentials(for: profile) }
        catch {
            await MainActor.run {
                guard isVerifying else { return }
                isVerifying = false
                verificationError = String(format: NSLocalizedString("Failed to resolve credentials for AWS Profile '%@': %@", comment: "Error message"), profile, error.localizedDescription)
                showError = true
            }
            return
        }
        let result = await AIConfigurationValidator.verifyAWSCredentials(credentials: credentials, region: region, modelId: model)
        await MainActor.run {
            guard isVerifying else { return }
            if result.success { isVerifying = false; saveConfiguration(); dismiss() }
            else { handleVerificationResult(success: false, errorMessage: result.errorMessage) }
        }
    }
    
    private func saveConfiguration() {
        var awsProfile: String? = nil
        var finalApiKey: String? = nil
        var accessKeyId: String? = nil
        var secretAccessKey: String? = nil
        
        if selectedProvider == .awsBedrock {
            switch awsAuthMethod {
            case .apiKey: finalApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            case .accessKey:
                accessKeyId = awsAccessKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
                secretAccessKey = awsSecretAccessKey.trimmingCharacters(in: .whitespacesAndNewlines)
            case .profile: awsProfile = selectedAWSProfile
            }
        } else if selectedProvider == .ollama {
            // Ollama doesn't need API key
            finalApiKey = nil
        } else {
            finalApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Determine custom endpoint for Ollama
        let customEndpoint: String?
        if selectedProvider == .azureOpenAI {
            customEndpoint = selectedProvider.normalizedCustomEndpoint(azureEndpoint)
        } else if selectedProvider == .ociGenerativeAI {
            customEndpoint = selectedProvider.normalizedCustomEndpoint(AIProvider.ociEndpoint(for: ociRegion))
        } else if selectedProvider == .ollama {
            customEndpoint = selectedProvider.normalizedCustomEndpoint(ollamaEndpoint)
        } else {
            customEndpoint = nil
        }

        let config: AIEnhancementConfiguration
        switch mode {
        case .add:
            config = AIEnhancementConfiguration(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: selectedProvider.rawValue,
                model: selectedModel.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: finalApiKey,
                awsProfileName: awsProfile,
                awsAccessKeyId: accessKeyId,
                awsSecretAccessKey: secretAccessKey,
                region: selectedProvider == .awsBedrock ? region : (selectedProvider == .ociGenerativeAI ? ociRegion : nil),
                enableCrossRegion: selectedProvider == .awsBedrock ? enableCrossRegion : false,
                customEndpoint: customEndpoint
            )
            appSettings.addConfiguration(config)
        case .edit(let existingConfig):
            config = AIEnhancementConfiguration(
                id: existingConfig.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: selectedProvider.rawValue,
                model: selectedModel.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: finalApiKey,
                awsProfileName: awsProfile,
                awsAccessKeyId: accessKeyId,
                awsSecretAccessKey: secretAccessKey,
                region: selectedProvider == .awsBedrock ? region : (selectedProvider == .ociGenerativeAI ? ociRegion : nil),
                enableCrossRegion: selectedProvider == .awsBedrock ? enableCrossRegion : false,
                customEndpoint: customEndpoint,
                createdAt: existingConfig.createdAt,
                lastUsedAt: existingConfig.lastUsedAt
            )
            appSettings.updateConfiguration(config)
        }
    }
}

// MARK: - Premium UI Components

struct SectionHeader: View {
    let title: String
    let systemImage: String
    @Environment(\.theme) private var theme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(theme.accentColor)
                .frame(width: 24, height: 24)
                .background(theme.accentColor.opacity(0.1))
                .clipShape(Circle())
            
            Text(title.uppercased())
                .font(theme.typography.caption2)
                .fontWeight(.bold)
                .foregroundColor(theme.textSecondary)
                .tracking(0.5)
        }
    }
}

struct PremiumLabeledInput<Content: View>: View {
    let label: String
    var description: String? = nil
    @ViewBuilder let content: () -> Content
    @Environment(\.theme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(theme.typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textPrimary.opacity(0.9))
                
                if let description = description {
                    Spacer()
                    Text(description)
                        .font(theme.typography.caption)
                        .foregroundColor(theme.textSecondary.opacity(0.8))
                }
            }
            
            content()
        }
    }
}

struct SecureInputView: View {
    @Binding var text: String
    let placeholder: String
    let label: String
    
    @FocusState private var isFocused: Bool
    @State private var isVisible = false
    @Environment(\.theme) private var theme
    
    var body: some View {
        PremiumLabeledInput(label: label) {
            HStack(spacing: 0) {
                if isVisible {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                } else {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                }
                
                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.leading, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .modifier(PremiumInputModifier(isFocused: isFocused))
        }
    }
}

/// A consistent input style for the entire sheet
struct PremiumInputModifier: ViewModifier {
    @State private var isHovering = false
    var isFocused: Bool = false
    @Environment(\.theme) private var theme
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.inputBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? theme.accentColor : (isHovering ? theme.textPrimary.opacity(0.4) : theme.panelBorder), lineWidth: 1)
            )
            .shadow(color: theme.shadowColor.opacity(isFocused ? 0.05 : 0), radius: 2, x: 0, y: 1)
            .onHover { isHovering = $0 }
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

/// A highly styled picker component that mimics the look of a TextField
struct PremiumPicker<T: Hashable>: View {
    @Binding var selection: T
    var options: [T]
    var labelMapper: (T) -> String
    @Environment(\.theme) private var theme
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    HStack {
                        if selection == option {
                            Image(systemName: "checkmark")
                        }
                        Text(labelMapper(option))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(labelMapper(selection))
                    .font(theme.typography.body)
                    .foregroundColor(theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary.opacity(0.5))
            }
            .contentShape(Rectangle())
            .modifier(PremiumInputModifier())
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity)
    }
}
