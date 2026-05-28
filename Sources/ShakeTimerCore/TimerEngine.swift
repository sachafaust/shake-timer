import Foundation

public struct CountdownSnapshot: Equatable {
    public enum State: Equatable {
        case idle
        case running
        case paused
        case fired
    }

    public var state: State
    public var duration: TimeInterval
    public var remaining: TimeInterval
    public var targetDate: Date?

    public init(
        state: State = .idle,
        duration: TimeInterval = 0,
        remaining: TimeInterval = 0,
        targetDate: Date? = nil
    ) {
        self.state = state
        self.duration = duration
        self.remaining = remaining
        self.targetDate = targetDate
    }
}

public final class TimerEngine {
    private(set) public var snapshot = CountdownSnapshot()

    public init() {}

    public func start(duration: TimeInterval, now: Date = Date()) {
        let clampedDuration = max(1, duration)
        snapshot = CountdownSnapshot(
            state: .running,
            duration: clampedDuration,
            remaining: clampedDuration,
            targetDate: now.addingTimeInterval(clampedDuration)
        )
    }

    public func pause(now: Date = Date()) {
        guard snapshot.state == .running else { return }
        snapshot.remaining = remaining(now: now)
        snapshot.targetDate = nil
        snapshot.state = .paused
    }

    public func resume(now: Date = Date()) {
        guard snapshot.state == .paused, snapshot.remaining > 0 else { return }
        snapshot.targetDate = now.addingTimeInterval(snapshot.remaining)
        snapshot.state = .running
    }

    public func cancel() {
        snapshot = CountdownSnapshot()
    }

    public func snooze(duration: TimeInterval, now: Date = Date()) {
        start(duration: duration, now: now)
    }

    @discardableResult
    public func tick(now: Date = Date()) -> Bool {
        guard snapshot.state == .running else { return false }
        let newRemaining = remaining(now: now)
        snapshot.remaining = newRemaining
        if newRemaining <= 0 {
            snapshot.remaining = 0
            snapshot.targetDate = nil
            snapshot.state = .fired
            return true
        }
        return false
    }

    public func remaining(now: Date = Date()) -> TimeInterval {
        guard let targetDate = snapshot.targetDate else {
            return max(0, snapshot.remaining)
        }
        return max(0, targetDate.timeIntervalSince(now))
    }
}
