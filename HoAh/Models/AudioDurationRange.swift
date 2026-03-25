import SwiftUI

enum AudioDurationRange: String, CaseIterable, Identifiable {
    case all
    case under30s
    case thirtySecTo2Min
    case over2Min

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: return "All durations"
        case .under30s: return "Under 30s"
        case .thirtySecTo2Min: return "30s - 2min"
        case .over2Min: return "Over 2min"
        }
    }

    var minDuration: TimeInterval? {
        switch self {
        case .all: return nil
        case .under30s: return nil
        case .thirtySecTo2Min: return 30
        case .over2Min: return 120
        }
    }

    var maxDuration: TimeInterval? {
        switch self {
        case .all: return nil
        case .under30s: return 30
        case .thirtySecTo2Min: return 120
        case .over2Min: return nil
        }
    }
}
