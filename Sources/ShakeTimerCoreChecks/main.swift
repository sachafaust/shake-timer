import Foundation
import ShakeTimerCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

let now = Date(timeIntervalSince1970: 1_000)

let timer = TimerEngine()
timer.start(duration: 10, now: now)
expect(timer.snapshot.state == .running, "Timer should start running")
expect(timer.tick(now: now.addingTimeInterval(9)) == false, "Timer fired too early")
expect(timer.tick(now: now.addingTimeInterval(10)) == true, "Timer did not fire at target")
expect(timer.snapshot.state == .fired, "Timer should enter fired state")

let paused = TimerEngine()
paused.start(duration: 20, now: now)
paused.pause(now: now.addingTimeInterval(5))
expect(abs(paused.snapshot.remaining - 15) < 0.01, "Pause should preserve remaining time")
paused.resume(now: now.addingTimeInterval(10))
expect(paused.tick(now: now.addingTimeInterval(25)) == true, "Resumed timer should fire after remaining time")

let planner = EventAlarmPlanner()
let event = CalendarEvent(id: "meeting", title: "Standup", startDate: now.addingTimeInterval(600))
let alarm = planner.nextAlarm(from: [event], now: now, leadSeconds: 120)
expect(alarm?.event.id == "meeting", "Planner should find the next event alarm")
expect(alarm?.alarmDate == now.addingTimeInterval(480), "Planner should subtract meeting lead time")

let due = planner.dueAlarms(
    from: [event],
    now: now,
    leadSeconds: 120,
    excludingTriggeredIDs: ["meeting"]
)
expect(due.isEmpty, "Planner should ignore already triggered events")

let encodedSettings = try JSONEncoder().encode(AppSettings(visualCueKind: .scanSweep))
let decodedSettings = try JSONDecoder().decode(AppSettings.self, from: encodedSettings)
expect(decodedSettings.visualCueKind == .scanSweep, "Settings should persist the selected visual cue")

let legacySettings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
expect(legacySettings.visualCueKind == .desktopShake, "Legacy settings should default to desktop shake")
expect(VisualCueKind.allCases.count >= 4, "Visual cue picker should offer multiple options")

print("ShakeTimerCoreChecks passed")
