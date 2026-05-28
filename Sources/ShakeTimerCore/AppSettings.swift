import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var defaultSnoozeSeconds: TimeInterval
    public var meetingLeadSeconds: TimeInterval
    public var visualCueKind: VisualCueKind
    public var visualIntensity: Double
    public var maxAlarmSeconds: TimeInterval
    public var calendarPollSeconds: TimeInterval
    public var googleClientID: String
    public var selectedCalendarID: String
    public var respectReduceMotion: Bool

    public init(
        defaultSnoozeSeconds: TimeInterval = 5 * 60,
        meetingLeadSeconds: TimeInterval = 2 * 60,
        visualCueKind: VisualCueKind = .desktopShake,
        visualIntensity: Double = 0.8,
        maxAlarmSeconds: TimeInterval = 30,
        calendarPollSeconds: TimeInterval = 60,
        googleClientID: String = "",
        selectedCalendarID: String = "primary",
        respectReduceMotion: Bool = true
    ) {
        self.defaultSnoozeSeconds = defaultSnoozeSeconds
        self.meetingLeadSeconds = meetingLeadSeconds
        self.visualCueKind = visualCueKind
        self.visualIntensity = visualIntensity
        self.maxAlarmSeconds = maxAlarmSeconds
        self.calendarPollSeconds = calendarPollSeconds
        self.googleClientID = googleClientID
        self.selectedCalendarID = selectedCalendarID
        self.respectReduceMotion = respectReduceMotion
    }

    public static let defaults = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case defaultSnoozeSeconds
        case meetingLeadSeconds
        case visualCueKind
        case visualIntensity
        case maxAlarmSeconds
        case calendarPollSeconds
        case googleClientID
        case selectedCalendarID
        case respectReduceMotion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            defaultSnoozeSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .defaultSnoozeSeconds) ?? Self.defaults.defaultSnoozeSeconds,
            meetingLeadSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .meetingLeadSeconds) ?? Self.defaults.meetingLeadSeconds,
            visualCueKind: try container.decodeIfPresent(VisualCueKind.self, forKey: .visualCueKind) ?? Self.defaults.visualCueKind,
            visualIntensity: try container.decodeIfPresent(Double.self, forKey: .visualIntensity) ?? Self.defaults.visualIntensity,
            maxAlarmSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .maxAlarmSeconds) ?? Self.defaults.maxAlarmSeconds,
            calendarPollSeconds: try container.decodeIfPresent(TimeInterval.self, forKey: .calendarPollSeconds) ?? Self.defaults.calendarPollSeconds,
            googleClientID: try container.decodeIfPresent(String.self, forKey: .googleClientID) ?? Self.defaults.googleClientID,
            selectedCalendarID: try container.decodeIfPresent(String.self, forKey: .selectedCalendarID) ?? Self.defaults.selectedCalendarID,
            respectReduceMotion: try container.decodeIfPresent(Bool.self, forKey: .respectReduceMotion) ?? Self.defaults.respectReduceMotion
        )
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "ShakeTimer.settings") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaults
        }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
