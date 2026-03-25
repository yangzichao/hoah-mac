import Foundation

struct ReasoningConfig {
    static let noReasoningModels: Set<String> = [
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "google/gemini-2.5-flash",
        "google/gemini-2.5-flash-lite",
        "gpt-5.4-mini",
        "gpt-5.4-nano",
        "openai/gpt-5.4-mini"
    ]

    static let lowReasoningModels: Set<String> = [
        "gemini-3.1-pro-preview",
        "gemini-3.1-flash-lite-preview",
        "gemini-3-flash-preview",
        "gemini-2.5-pro",
        "gpt-oss-120b",
        "google/gemini-2.5-pro",
        "google/gemini-3-flash-preview",
        "openai/gpt-oss-120b"
    ]

    static let minimalReasoningModels: Set<String> = [
        "gpt-5-mini",
        "gpt-5-nano"
    ]

    static func getReasoningParameter(for modelName: String) -> String? {
        if noReasoningModels.contains(modelName) {
            return "none"
        } else if minimalReasoningModels.contains(modelName) {
            return "minimal"
        } else if lowReasoningModels.contains(modelName) {
            return "low"
        }
        return nil
    }
}
