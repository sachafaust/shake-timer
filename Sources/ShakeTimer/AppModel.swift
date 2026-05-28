import Foundation
import ShakeTimerCore

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var settings: AppSettings {
        didSet {
            settingsStore.save(settings)
            if overlayManager.isActive {
                overlayManager.refreshIfActive(
                    intensity: settings.visualIntensity,
                    maxDuration: settings.maxAlarmSeconds,
                    respectReduceMotion: settings.respectReduceMotion
                )
            }
        }
    }
    @Published private(set) var timerSnapshot = CountdownSnapshot()
    @Published private(set) var upcomingEvents: [CalendarEvent] = []
    @Published private(set) var nextCalendarAlarm: ScheduledCalendarAlarm?
    @Published private(set) var isAlarmActive = false
    @Published private(set) var activeAlarmTitle = ""
    @Published var lastError: String?
    @Published var googleClientSecret: String {
        didSet {
            try? keychain.save(googleClientSecret, account: googleClientSecretAccount)
        }
    }

    let googleCalendar = GoogleCalendarService()

    private let settingsStore = SettingsStore()
    private let keychain = KeychainStore()
    private let googleClientSecretAccount = "google-client-secret"
    private let timerEngine = TimerEngine()
    private let planner = EventAlarmPlanner()
    private let overlayManager = OverlayManager()
    private let hotKeyManager = HotKeyManager()
    private var tickTimer: Timer?
    private var calendarPollTimer: Timer?
    private var triggeredEventIDs = Set<String>()

    var statusTitle: String {
        if isAlarmActive { return "ALARM" }
        switch timerSnapshot.state {
        case .running:
            return format(seconds: timerSnapshot.remaining)
        case .paused:
            return "Paused"
        case .fired:
            return "Done"
        case .idle:
            return "Timer"
        }
    }

    private init() {
        settings = settingsStore.load()
        googleClientSecret = (try? keychain.load(account: googleClientSecretAccount)) ?? ""
        timerSnapshot = timerEngine.snapshot
        overlayManager.onAutoStop = { [weak self] in
            self?.isAlarmActive = false
            self?.activeAlarmTitle = ""
        }
        hotKeyManager.onStop = { [weak self] in
            self?.stopAlarm()
        }
        hotKeyManager.onSnooze = { [weak self] in
            self?.snoozeAlarm()
        }
    }

    func start() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        syncCalendarNow()
        rescheduleCalendarPolling()
    }

    func startTimer(minutes: Double) {
        timerEngine.start(duration: max(1, minutes * 60))
        timerSnapshot = timerEngine.snapshot
        stopAlarm()
    }

    func pauseOrResumeTimer() {
        switch timerSnapshot.state {
        case .running:
            timerEngine.pause()
        case .paused:
            timerEngine.resume()
        case .idle, .fired:
            break
        }
        timerSnapshot = timerEngine.snapshot
    }

    func cancelTimer() {
        overlayManager.stop()
        isAlarmActive = false
        activeAlarmTitle = ""
        timerEngine.cancel()
        timerSnapshot = timerEngine.snapshot
    }

    func stopAlarm() {
        overlayManager.stop()
        isAlarmActive = false
        activeAlarmTitle = ""
        if timerEngine.snapshot.state == .fired {
            timerEngine.cancel()
            timerSnapshot = timerEngine.snapshot
        }
    }

    func snoozeAlarm() {
        overlayManager.stop()
        isAlarmActive = false
        activeAlarmTitle = ""
        timerEngine.snooze(duration: settings.defaultSnoozeSeconds)
        timerSnapshot = timerEngine.snapshot
    }

    func connectGoogleCalendar() {
        Task {
            do {
                try await googleCalendar.connect(settings: settings, clientSecret: googleClientSecret)
                await refreshCalendarEvents()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func disconnectGoogleCalendar() {
        googleCalendar.disconnect()
        upcomingEvents = []
        nextCalendarAlarm = nil
        triggeredEventIDs = []
    }

    func syncCalendarNow() {
        Task {
            await refreshCalendarEvents()
        }
    }

    func rescheduleCalendarPolling() {
        calendarPollTimer?.invalidate()
        calendarPollTimer = Timer.scheduledTimer(
            withTimeInterval: max(15, settings.calendarPollSeconds),
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCalendarEvents()
            }
        }
    }

    func format(seconds: TimeInterval) -> String {
        let clamped = max(0, Int(seconds.rounded(.up)))
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func tick() {
        if timerEngine.tick() {
            fireAlarm(title: "Timer finished")
        }
        timerSnapshot = timerEngine.snapshot
        evaluateCalendarAlarms()
    }

    private func refreshCalendarEvents() async {
        guard googleCalendar.isConnected else { return }
        do {
            let events = try await googleCalendar.fetchUpcomingEvents(settings: settings, clientSecret: googleClientSecret)
            upcomingEvents = events
            evaluateCalendarAlarms()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func evaluateCalendarAlarms(now: Date = Date()) {
        let due = planner.dueAlarms(
            from: upcomingEvents,
            now: now,
            leadSeconds: settings.meetingLeadSeconds,
            excludingTriggeredIDs: triggeredEventIDs
        )
        if let alarm = due.first {
            triggeredEventIDs.formUnion(due.map(\.event.id))
            fireAlarm(title: "Meeting: \(alarm.event.title)")
        }
        nextCalendarAlarm = planner.nextAlarm(
            from: upcomingEvents,
            now: now,
            leadSeconds: settings.meetingLeadSeconds,
            excludingTriggeredIDs: triggeredEventIDs
        )
    }

    private func fireAlarm(title: String) {
        activeAlarmTitle = title
        isAlarmActive = true
        overlayManager.start(
            intensity: settings.visualIntensity,
            maxDuration: settings.maxAlarmSeconds,
            respectReduceMotion: settings.respectReduceMotion
        )
    }
}
