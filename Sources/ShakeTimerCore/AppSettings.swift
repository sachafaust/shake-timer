import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var defaultSnoozeSeconds: TimeInterval
    public var meetingLeadSeconds: TimeInterval
    public var visualIntensity: Double
    public var maxAlarmSeconds: TimeInterval
    public var calendarPollSeconds: TimeInterval
    public var googleClientID: String
    public var selectedCalendarID: String
    public var respectReduceMotion: Bool

    public init(
        defaultSnoozeSeconds: TimeInterval = 5 * 60,
        meetingLeadSeconds: TimeInterval = 2 * 60,
        visualIntensity: Double = 0.8,
        maxAlarmSeconds: TimeInterval = 30,
        calendarPollSeconds: TimeInterval = 60,
        googleClientID: String = "",
        selectedCalendarID: String = "primary",
        respectReduceMotion: Bool = true
    ) {
        self.defaultSnoozeSeconds = defaultSnoozeSeconds
        self.meetingLeadSeconds = meetingLeadSeconds
        self.visualIntensity = visualIntensity
        self.maxAlarmSeconds = maxAlarmSeconds
        self.calendarPollSeconds = calendarPollSeconds
        self.googleClientID = googleClientID
        self.selectedCalendarID = selectedCalendarID
        self.respectReduceMotion = respectReduceMotion
    }

    public static let defaults = AppSettings()
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
