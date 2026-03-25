import Testing
import Foundation

// MARK: - AI Enhancement Integration Tests
// 这些测试通过 HoAh 的 AIService 验证 AI Enhancement 功能

/// 测试配置 - 从环境变量或 .env.test 文件加载 API Keys
struct TestConfiguration {
    let ociGenerativeAIKey: String?
    let ociGenerativeAIRegion: String
    let openAIKey: String?
    let geminiKey: String?
    let groqKey: String?
    let cerebrasKey: String?
    let openRouterKey: String?
    let awsBedrockKey: String?
    let awsBedrockRegion: String
    let awsProfile: String?
    let awsAccessKeyId: String?
    let awsSecretAccessKey: String?
    let awsSessionToken: String?
    // Chinese providers
    let doubaoKey: String?
    
    static func load() -> TestConfiguration {
        // 优先从环境变量加载
        let openAI = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
        let ociGenerativeAI = ProcessInfo.processInfo.environment["OCI_GENERATIVE_AI_API_KEY"]
        let ociGenerativeAIRegion = ProcessInfo.processInfo.environment["OCI_GENERATIVE_AI_REGION"] ?? "us-chicago-1"
        let gemini = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        let groq = ProcessInfo.processInfo.environment["GROQ_API_KEY"]
        let cerebras = ProcessInfo.processInfo.environment["CEREBRAS_API_KEY"]
        let openRouter = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"]
        let awsBedrock = ProcessInfo.processInfo.environment["AWS_BEDROCK_API_KEY"]
        let awsRegion = ProcessInfo.processInfo.environment["AWS_BEDROCK_REGION"] ?? "us-east-1"
        let awsProfile = ProcessInfo.processInfo.environment["AWS_PROFILE"]
        let awsAccessKeyId = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]
        let awsSecretAccessKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]
        let awsSessionToken = ProcessInfo.processInfo.environment["AWS_SESSION_TOKEN"]
        // Chinese providers
        let doubao = ProcessInfo.processInfo.environment["DOUBAO_API_KEY"]

        // 如果环境变量为空，尝试从 .env.test 文件加载
        if openAI == nil && ociGenerativeAI == nil && gemini == nil && groq == nil && cerebras == nil && openRouter == nil && awsBedrock == nil && doubao == nil {
            return loadFromEnvFile() ?? TestConfiguration(
                ociGenerativeAIKey: nil,
                ociGenerativeAIRegion: "us-chicago-1",
                openAIKey: nil,
                geminiKey: nil,
                groqKey: nil,
                cerebrasKey: nil,
                openRouterKey: nil,
                awsBedrockKey: nil,
                awsBedrockRegion: "us-east-1",
                awsProfile: nil,
                awsAccessKeyId: nil,
                awsSecretAccessKey: nil,
                awsSessionToken: nil,
                doubaoKey: nil
            )
        }

        return TestConfiguration(
            ociGenerativeAIKey: ociGenerativeAI,
            ociGenerativeAIRegion: ociGenerativeAIRegion,
            openAIKey: openAI,
            geminiKey: gemini,
            groqKey: groq,
            cerebrasKey: cerebras,
            openRouterKey: openRouter,
            awsBedrockKey: awsBedrock,
            awsBedrockRegion: awsRegion,
            awsProfile: awsProfile,
            awsAccessKeyId: awsAccessKeyId,
            awsSecretAccessKey: awsSecretAccessKey,
            awsSessionToken: awsSessionToken,
            doubaoKey: doubao
        )
    }
    
    private static func loadFromEnvFile() -> TestConfiguration? {
        // 查找项目根目录的 .env.test 文件
        let fileManager = FileManager.default
        
        // 尝试多个可能的路径
        let possiblePaths = [
            // 从 Bundle 获取项目路径
            Bundle.main.bundlePath + "/../../../../.env.test",
            // 当前目录
            fileManager.currentDirectoryPath + "/.env.test",
            // 源代码目录 (通过 #file)
            URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path + "/.env.test"
        ]
        
        var envFilePath: String? = nil
        for path in possiblePaths {
            let standardizedPath = (path as NSString).standardizingPath
            if fileManager.fileExists(atPath: standardizedPath) {
                envFilePath = standardizedPath
                break
            }
        }
        
        guard let envFilePath = envFilePath else {
            print("⚠️ .env.test file not found in any of the expected locations")
            return nil
        }
        
        print("📁 Loading .env.test from: \(envFilePath)")
        
        guard let content = try? String(contentsOfFile: envFilePath, encoding: .utf8) else {
            print("⚠️ Failed to read .env.test file")
            return nil
        }
        
        var config: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed.components(separatedBy: "=")
            guard parts.count >= 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            config[key] = value
        }
        
        return TestConfiguration(
            ociGenerativeAIKey: config["OCI_GENERATIVE_AI_API_KEY"],
            ociGenerativeAIRegion: config["OCI_GENERATIVE_AI_REGION"] ?? "us-chicago-1",
            openAIKey: config["OPENAI_API_KEY"],
            geminiKey: config["GEMINI_API_KEY"],
            groqKey: config["GROQ_API_KEY"],
            cerebrasKey: config["CEREBRAS_API_KEY"],
            openRouterKey: config["OPENROUTER_API_KEY"],
            awsBedrockKey: config["AWS_BEDROCK_API_KEY"],
            awsBedrockRegion: config["AWS_BEDROCK_REGION"] ?? "us-east-1",
            awsProfile: config["AWS_PROFILE"],
            awsAccessKeyId: config["AWS_ACCESS_KEY_ID"],
            awsSecretAccessKey: config["AWS_SECRET_ACCESS_KEY"],
            awsSessionToken: config["AWS_SESSION_TOKEN"],
            doubaoKey: config["DOUBAO_API_KEY"]
        )
    }
    
    /// 掩码 API Key 用于日志输出
    static func mask(_ key: String) -> String {
        guard key.count >= 8 else { return "****" }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)****\(suffix)"
    }
    
    func isConfigured(for provider: String) -> Bool {
        switch provider {
        case "OCI Generative AI": return ociGenerativeAIKey != nil && !ociGenerativeAIKey!.isEmpty
        case "OpenAI": return openAIKey != nil && !openAIKey!.isEmpty
        case "Gemini": return geminiKey != nil && !geminiKey!.isEmpty
        case "GROQ": return groqKey != nil && !groqKey!.isEmpty
        case "Cerebras": return cerebrasKey != nil && !cerebrasKey!.isEmpty
        case "OpenRouter": return openRouterKey != nil && !openRouterKey!.isEmpty
        case "AWS Bedrock": return hasBedrockAPIKey || hasAWSProfile
        case "字节豆包": return doubaoKey != nil && !doubaoKey!.isEmpty
        default: return false
        }
    }
    
    /// 是否配置了 AWS Bedrock API Key (Bearer Token)
    var hasBedrockAPIKey: Bool {
        return awsBedrockKey != nil && !awsBedrockKey!.isEmpty
    }
    
    /// 是否配置了 AWS Profile (用于 SigV4 认证)
    var hasAWSProfile: Bool {
        return awsProfile != nil && !awsProfile!.isEmpty
    }
}

/// 测试 Fixtures
struct TestFixtures {
    /// 简单文本增强测试
    static let simpleText = "hello world this is a test"
    
    /// 包含标点的文本
    static let textWithPunctuation = "hello, world! this is a test."
    
    /// 多语言文本
    static let multiLanguageText = "Hello 你好 こんにちは"
    
    /// 系统提示
    static let systemPrompt = "You are a helpful assistant that improves text clarity. Return only the improved text without any explanation."
}

/// 测试结果
struct TestResult {
    let testName: String
    let provider: String
    let model: String
    let status: TestStatus
    let duration: TimeInterval
    let errorMessage: String?
    let responsePreview: String?
    
    enum TestStatus: String {
        case passed = "✅ PASSED"
        case failed = "❌ FAILED"
        case skipped = "⏭️ SKIPPED"
    }
}

/// 测试报告
struct TestReport {
    let results: [TestResult]
    let startTime: Date
    let endTime: Date
    
    var passedCount: Int { results.filter { $0.status == .passed }.count }
    var failedCount: Int { results.filter { $0.status == .failed }.count }
    var skippedCount: Int { results.filter { $0.status == .skipped }.count }
    
    func toConsoleOutput() -> String {
        var output = "\n" + String(repeating: "=", count: 60) + "\n"
        output += "AI Enhancement Integration Test Report\n"
        output += String(repeating: "=", count: 60) + "\n\n"
        
        // Group by provider
        let grouped = Dictionary(grouping: results) { $0.provider }
        for (provider, providerResults) in grouped.sorted(by: { $0.key < $1.key }) {
            output += "📦 \(provider)\n"
            for result in providerResults {
                output += "  \(result.status.rawValue) \(result.model) (\(String(format: "%.2f", result.duration))s)\n"
                if let error = result.errorMessage {
                    output += "    Error: \(error)\n"
                }
            }
            output += "\n"
        }
        
        output += String(repeating: "-", count: 60) + "\n"
        output += "Summary: \(passedCount) passed, \(failedCount) failed, \(skippedCount) skipped\n"
        output += "Duration: \(String(format: "%.2f", endTime.timeIntervalSince(startTime)))s\n"
        output += String(repeating: "=", count: 60) + "\n"
        
        return output
    }
}
