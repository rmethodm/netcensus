import Foundation

enum ScanSchedule: String, CaseIterable, Identifiable {
    case off
    case hourly
    case sixHours
    case daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .hourly: "Every hour"
        case .sixHours: "Every 6 hours"
        case .daily: "Daily"
        }
    }

    var interval: Duration? {
        switch self {
        case .off: nil
        case .hourly: .seconds(60 * 60)
        case .sixHours: .seconds(6 * 60 * 60)
        case .daily: .seconds(24 * 60 * 60)
        }
    }
}

struct ScanPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var schedule: ScanSchedule {
        get { ScanSchedule(rawValue: defaults.string(forKey: "scanSchedule") ?? "") ?? .off }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "scanSchedule") }
    }

    var retentionDays: Int {
        get {
            let value = defaults.integer(forKey: "retentionDays")
            return value == 0 ? 30 : value
        }
        nonmutating set { defaults.set(newValue, forKey: "retentionDays") }
    }

    var hideIgnoredFindings: Bool {
        get { defaults.object(forKey: "hideIgnoredFindings") as? Bool ?? true }
        nonmutating set { defaults.set(newValue, forKey: "hideIgnoredFindings") }
    }

    var scanOnLaunch: Bool {
        get { defaults.bool(forKey: "scanOnLaunch") }
        nonmutating set { defaults.set(newValue, forKey: "scanOnLaunch") }
    }
}
