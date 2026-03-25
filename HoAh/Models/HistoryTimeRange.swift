import SwiftUI

enum HistoryTimeRange: String, CaseIterable, Identifiable {
    case last24Hours
    case last3Days
    case last7Days
    case last30Days
    case lastYear
    case allTime

    var id: Self { self }

    var titleKey: LocalizedStringKey {
        switch self {
        case .last24Hours: return "Last 24 hours"
        case .last3Days: return "3 days"
        case .last7Days: return "7 days"
        case .last30Days: return "30 days"
        case .lastYear: return "Past year"
        case .allTime: return "All time"
        }
    }

    var cutoffDate: Date? {
        let now = Date()
        let calendar = Calendar.current
        switch self {
        case .last24Hours:
            return calendar.date(byAdding: .hour, value: -24, to: now)
        case .last3Days:
            return calendar.date(byAdding: .day, value: -3, to: now)
        case .last7Days:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .last30Days:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }

    var fileTag: String {
        switch self {
        case .last24Hours: return "last-24h"
        case .last3Days: return "last-3d"
        case .last7Days: return "last-7d"
        case .last30Days: return "last-30d"
        case .lastYear: return "last-year"
        case .allTime: return "all-time"
        }
    }
}
