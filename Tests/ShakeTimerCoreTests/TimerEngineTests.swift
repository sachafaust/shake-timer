import Foundation
import ShakeTimerCore
import Testing

struct TimerEngineTests {
    @Test
    func timerFiresOnceAtTargetDate() {
        let engine = TimerEngine()
        let now = Date(timeIntervalSince1970: 1_000)

        engine.start(duration: 10, now: now)

        #expect(engine.snapshot.state == .running)
        #expect(engine.tick(now: now.addingTimeInterval(9)) == false)
        #expect(engine.tick(now: now.addingTimeInterval(10)) == true)
        #expect(engine.snapshot.state == .fired)
        #expect(engine.tick(now: now.addingTimeInterval(11)) == false)
    }

    @Test
    func pauseResumePreservesRemainingTime() {
        let engine = TimerEngine()
        let now = Date(timeIntervalSince1970: 1_000)

        engine.start(duration: 20, now: now)
        engine.pause(now: now.addingTimeInterval(5))

        #expect(engine.snapshot.state == .paused)
        #expect(abs(engine.snapshot.remaining - 15) < 0.01)

        engine.resume(now: now.addingTimeInterval(10))
        #expect(engine.tick(now: now.addingTimeInterval(24)) == false)
        #expect(engine.tick(now: now.addingTimeInterval(25)) == true)
    }
}
