import Foundation

public struct EventAlarmPlanner: Sendable {
    public init() {}

    public func nextAlarm(
        from events: [CalendarEvent],
        now: Date,
        leadSeconds: TimeInterval,
        excludingTriggeredIDs triggeredIDs: Set<String> = []
    ) -> ScheduledCalendarAlarm? {
        events
            .filter { !triggeredIDs.contains($0.id) }
            .map { event in
                ScheduledCalendarAlarm(
                    event: event,
                    alarmDate: event.startDate.addingTimeInterval(-max(0, leadSeconds))
                )
            }
            .filter { $0.alarmDate >= now }
            .min { $0.alarmDate < $1.alarmDate }
    }

    public func dueAlarms(
        from events: [CalendarEvent],
        now: Date,
        leadSeconds: TimeInterval,
        excludingTriggeredIDs triggeredIDs: Set<String> = []
    ) -> [ScheduledCalendarAlarm] {
        events
            .filter { !triggeredIDs.contains($0.id) }
            .map { event in
                ScheduledCalendarAlarm(
                    event: event,
                    alarmDate: event.startDate.addingTimeInterval(-max(0, leadSeconds))
                )
            }
            .filter { $0.alarmDate <= now && $0.event.startDate >= now.addingTimeInterval(-60) }
            .sorted { $0.alarmDate < $1.alarmDate }
    }
}
