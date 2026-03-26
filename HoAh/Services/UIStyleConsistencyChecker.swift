import Foundation
import AppKit
import OSLog

struct ThemeSpacingSignature: Codable, Hashable {
    let windowCornerRadius: Double
    let windowInset: Double
    let cardCornerRadius: Double
    let windowBorderWidth: Double
}

struct UIStyleSignature: Codable, Hashable {
    let themeId: String
    let typography: ThemeTypographySignature
    let spacing: ThemeSpacingSignature
}

struct UIStyleSnapshot: Codable {
    let signature: UIStyleSignature
    let buildConfiguration: String
    let appVersion: String
    let buildNumber: String
    let timestamp: Date
}

enum UIStyleConsistencyChecker {
    private static let logger = Logger(subsystem: "com.yangzichao.hoah", category: "UIStyleConsistency")
    private static let debugKey = "UIStyleSnapshot.Debug"
    private static let releaseKey = "UIStyleSnapshot.Release"
    private static let mismatchKey = "UIStyleSnapshot.LastMismatch"

    static func recordAndCompare(theme: ThemePalette, defaults: UserDefaults = .hoah, bundle: Bundle = .main) {
        let configuration = currentBuildConfiguration()
        let signature = UIStyleSignature(
            themeId: theme.id.rawValue,
            typography: theme.typography.signature,
            spacing: theme.spacingSignature
        )

        let snapshot = UIStyleSnapshot(
            signature: signature,
            buildConfiguration: configuration,
            appVersion: bundle.shortVersion,
            buildNumber: bundle.buildNumber,
            timestamp: Date()
        )

        storeSnapshot(snapshot, key: key(for: configuration), defaults: defaults)

        #if DEBUG
        guard !isRunningInPreviewOrTests else { return }

        guard let releaseSnapshot = loadSnapshot(forKey: releaseKey, defaults: defaults) else { return }
        guard releaseSnapshot.appVersion == snapshot.appVersion,
              releaseSnapshot.buildNumber == snapshot.buildNumber else {
            return
        }

        guard releaseSnapshot.signature != snapshot.signature else { return }

        let mismatchDigest = mismatchDigest(debug: snapshot.signature, release: releaseSnapshot.signature)
        if defaults.string(forKey: mismatchKey) == mismatchDigest {
            return
        }
        defaults.set(mismatchDigest, forKey: mismatchKey)

        showMismatchAlert(debug: snapshot, release: releaseSnapshot)
        #endif
    }

    private static func storeSnapshot(_ snapshot: UIStyleSnapshot, key: String, defaults: UserDefaults) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: key)
        } else {
            logger.error("Failed to encode UIStyleSnapshot for \(key, privacy: .public)")
        }
    }

    private static func loadSnapshot(forKey key: String, defaults: UserDefaults) -> UIStyleSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UIStyleSnapshot.self, from: data)
    }

    private static func mismatchDigest(debug: UIStyleSignature, release: UIStyleSignature) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let debugData = (try? encoder.encode(debug)) ?? Data()
        let releaseData = (try? encoder.encode(release)) ?? Data()
        return debugData.base64EncodedString() + "|" + releaseData.base64EncodedString()
    }

    private static func showMismatchAlert(debug: UIStyleSnapshot, release: UIStyleSnapshot) {
        let summary = mismatchSummary(debug: debug.signature, release: release.signature)
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "UI Style Mismatch (Debug vs Release)"
            alert.informativeText = "\(summary)\n\nDebug: \(debug.appVersion) (\(debug.buildNumber))\nRelease: \(release.appVersion) (\(release.buildNumber))"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private static func mismatchSummary(debug: UIStyleSignature, release: UIStyleSignature) -> String {
        var lines: [String] = []
        if debug.themeId != release.themeId {
            lines.append("Theme: Debug=\(debug.themeId) Release=\(release.themeId)")
        }
        if debug.typography != release.typography {
            lines.append("Typography signature differs")
        }
        if debug.spacing != release.spacing {
            lines.append("Spacing signature differs")
        }
        if lines.isEmpty {
            lines.append("UI style signatures differ")
        }
        return lines.joined(separator: "\n")
    }

    private static func currentBuildConfiguration() -> String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }

    private static func key(for configuration: String) -> String {
        "UIStyleSnapshot.\(configuration)"
    }

    private static var isRunningInPreviewOrTests: Bool {
        RuntimeEnvironment.isRunningTestsOrPreviews
    }
}

private extension ThemePalette {
    var spacingSignature: ThemeSpacingSignature {
        ThemeSpacingSignature(
            windowCornerRadius: Double(windowCornerRadius),
            windowInset: Double(windowInset),
            cardCornerRadius: Double(cardCornerRadius),
            windowBorderWidth: Double(windowBorderWidth)
        )
    }
}

private extension Bundle {
    var shortVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }
}
