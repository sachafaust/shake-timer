import Foundation
import ShakeTimerCore
import Testing

struct EventAlarmPlannerTests {
    @Test
    func findsNextAlarmBeforeEventStart() {
        let planner = EventAlarmPlanner()
        let now = Date(timeIntervalSince1970: 1_000)
        let event = CalendarEvent(
            id: "meeting",
            title: "Standup",
            startDate: now.addingTimeInterval(600)
        )

        let alarm = planner.nextAlarm(from: [event], now: now, leadSeconds: 120)

        #expect(alarm?.event.id == "meeting")
        #expect(alarm?.alarmDate == now.addingTimeInterval(480))
    }

    @Test
    func dueAlarmIgnoresTriggeredEvents() {
        let planner = EventAlarmPlanner()
        let now = Date(timeIntervalSince1970: 1_000)
        let event = CalendarEvent(
            id: "meeting",
            title: "Standup",
            startDate: now.addingTimeInterval(60)
        )

        let due = planner.dueAlarms(
            from: [event],
            now: now,
            leadSeconds: 120,
            excludingTriggeredIDs: ["meeting"]
        )

        #expect(due.isEmpty)
    }
}
