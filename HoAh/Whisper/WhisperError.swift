import Foundation

enum WhisperStateError: Error, Identifiable {
    case modelLoadFailed
    case transcriptionFailed
    case whisperCoreFailed
    case unzipFailed
    case unknownError
    
    var id: String { UUID().uuidString }
}

extension WhisperStateError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .modelLoadFailed:
            return "Failed to load the dictation model."
        case .transcriptionFailed:
            return "Failed to transcribe the audio."
        case .whisperCoreFailed:
            return "The core transcription engine failed."
        case .unzipFailed:
            return "Failed to unzip the downloaded Core ML model."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelLoadFailed:
            return "Try selecting a different model or redownloading the current model."
        case .transcriptionFailed:
            return "Check the default model try again. If the problem persists, try a different model."
        case .whisperCoreFailed:
            return "This can happen due to an issue with the audio recording or insufficient system resources. Please try again, or restart the app."
        case .unzipFailed:
            return "The downloaded Core ML model archive might be corrupted. Try deleting the model and downloading it again. Check available disk space."
        case .unknownError:
            return "Please restart the application. If the problem persists, contact support."
        }
    }
} 

extension Error {
    var isNetworkConnectivityFailure: Bool {
        NetworkConnectivityErrorClassifier.containsConnectivityFailure(in: self)
    }
}

extension String {
    var isNetworkConnectivityFailureMessage: Bool {
        NetworkConnectivityErrorClassifier.containsConnectivityFailure(in: self)
    }
}

private enum NetworkConnectivityErrorClassifier {
    static func containsConnectivityFailure(in error: Error) -> Bool {
        containsConnectivityFailure(in: error as NSError, depth: 0)
    }

    static func containsConnectivityFailure(in message: String) -> Bool {
        let normalized = message.lowercased()
        let patterns = [
            "not connected",
            "offline",
            "network connection lost",
            "network is down",
            "cannot connect to host",
            "cannot find host",
            "dns lookup",
            "dns resolution",
            "timed out",
            "internet connection appears to be offline"
        ]

        return patterns.contains { normalized.contains($0) }
    }

    private static func containsConnectivityFailure(in error: NSError, depth: Int) -> Bool {
        guard depth < 6 else { return false }

        if error.domain == NSURLErrorDomain {
            let code = URLError.Code(rawValue: error.code)
            switch code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed,
                 .internationalRoamingOff,
                 .callIsActive,
                 .dataNotAllowed:
                return true
            default:
                break
            }
        }

        if error.domain == NSPOSIXErrorDomain,
           let code = POSIXErrorCode(rawValue: Int32(error.code)) {
            switch code {
            case .ENETDOWN, .ENETUNREACH, .EHOSTDOWN, .EHOSTUNREACH, .ETIMEDOUT:
                return true
            default:
                break
            }
        }

        if containsConnectivityFailure(in: error.localizedDescription) {
            return true
        }

        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
           containsConnectivityFailure(in: underlying, depth: depth + 1) {
            return true
        }

        return false
    }
}
