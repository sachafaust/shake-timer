import Foundation

public struct CalendarEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date?
    public let calendarID: String

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        calendarID: String = "primary"
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarID = calendarID
    }
}

public struct ScheduledCalendarAlarm: Equatable, Sendable {
    public let event: CalendarEvent
    public let alarmDate: Date

    public init(event: CalendarEvent, alarmDate: Date) {
        self.event = event
        self.alarmDate = alarmDate
    }
}
