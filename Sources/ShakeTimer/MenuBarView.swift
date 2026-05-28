import ShakeTimerCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var model: AppModel
    @State private var customMinutes = "15"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            display
            timerSection
            calendarSection
            footer
        }
        .padding(14)
        .background(TEPalette.shell)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SHAKE TIMER")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .tracking(1.5)
                Text(model.isAlarmActive ? model.activeAlarmTitle.uppercased() : "VISUAL MEETING + FOCUS ALARM")
                    .font(TEFonts.label)
                    .foregroundStyle(TEPalette.muted)
                    .lineLimit(1)
            }

            Spacer()

            StatusPill(
                title: model.isAlarmActive ? "SHAKE" : model.timerSnapshot.state == .running ? "ARMED" : "IDLE",
                color: model.isAlarmActive ? TEPalette.red : model.timerSnapshot.state == .running ? TEPalette.orange : TEPalette.blue
            )
        }
    }

    private var display: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.statusTitle.uppercased())
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(model.isAlarmActive ? TEPalette.red : TEPalette.lcd)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("STOP ⌃⌥⌘S")
                    Text("SNOOZE ⌃⌥⌘Z")
                }
                .font(TEFonts.micro)
                .foregroundStyle(TEPalette.lcd.opacity(0.75))
            }

            if let next = model.nextCalendarAlarm {
                Text("NEXT \(next.alarmDate.formatted(date: .omitted, time: .shortened))  \(next.event.title.uppercased())")
                    .font(TEFonts.label)
                    .foregroundStyle(TEPalette.lcd.opacity(0.8))
                    .lineLimit(1)
            } else {
                Text(model.googleCalendar.isConnected ? "CALENDAR READY / NO MEETING SHAKE QUEUED" : "LOCAL TIMER READY")
                    .font(TEFonts.label)
                    .foregroundStyle(TEPalette.lcd.opacity(0.65))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(TEPalette.display)
        )
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index == 0 && model.isAlarmActive ? TEPalette.red : TEPalette.lcd.opacity(0.18))
                        .frame(width: 18, height: 3)
                }
            }
            .padding(8)
        }
    }

    private var timerSection: some View {
        TEPanel(title: "TIMER") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PresetKey(title: "05", subtitle: "MIN") { model.startTimer(minutes: 5) }
                    PresetKey(title: "15", subtitle: "MIN") { model.startTimer(minutes: 15) }
                        .keyboardShortcut(.defaultAction)
                    PresetKey(title: "30", subtitle: "MIN") { model.startTimer(minutes: 30) }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("CUSTOM")
                            .font(TEFonts.micro)
                            .foregroundStyle(TEPalette.muted)
                        TextField("15", text: $customMinutes)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .frame(width: 58, height: 34)
                            .background(TEPalette.recess)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(TEPalette.ink.opacity(0.35), lineWidth: 1)
                            )
                    }

                    Button("START") {
                        model.startTimer(minutes: Double(customMinutes) ?? 15)
                    }
                    .buttonStyle(TEKeyButtonStyle(tone: .orange))
                }

                HStack(spacing: 8) {
                    Button(model.timerSnapshot.state == .paused ? "RESUME" : "PAUSE") {
                        model.pauseOrResumeTimer()
                    }
                    .buttonStyle(TEKeyButtonStyle(tone: .neutral))
                    .disabled(model.timerSnapshot.state != .running && model.timerSnapshot.state != .paused)

                    Button("CANCEL") {
                        model.cancelTimer()
                    }
                    .buttonStyle(TEKeyButtonStyle(tone: .neutral))
                    .disabled(model.timerSnapshot.state == .idle && !model.isAlarmActive)

                    if model.isAlarmActive {
                        Button("STOP") { model.stopAlarm() }
                            .buttonStyle(TEKeyButtonStyle(tone: .red))
                        Button("SNOOZE") { model.snoozeAlarm() }
                            .buttonStyle(TEKeyButtonStyle(tone: .blue))
                    }
                }
            }
        }
    }

    private var calendarSection: some View {
        TEPanel(title: "CALENDAR") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    StatusDot(active: model.googleCalendar.isConnected)
                    Text(model.googleCalendar.status.uppercased())
                        .font(TEFonts.label)
                        .foregroundStyle(TEPalette.ink)
                        .lineLimit(1)
                    Spacer()
                    if model.googleCalendar.isConnected {
                        Button("SYNC") { model.syncCalendarNow() }
                            .buttonStyle(TEKeyButtonStyle(tone: .neutral, compact: true))
                    } else {
                        Button("CONNECT") { model.connectGoogleCalendar() }
                            .buttonStyle(TEKeyButtonStyle(tone: .blue, compact: true))
                            .disabled(model.settings.googleClientID.isEmpty)
                    }
                }

                VStack(spacing: 4) {
                    if model.upcomingEvents.isEmpty {
                        EmptyEventRow(text: model.googleCalendar.isConnected ? "NO EVENTS IN QUEUE" : "ADD GOOGLE CLIENT ID IN SETTINGS")
                    } else {
                        ForEach(model.upcomingEvents.prefix(3)) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let lastError = model.lastError {
                Text(lastError)
                    .font(TEFonts.label)
                    .foregroundStyle(TEPalette.red)
                    .lineLimit(3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TEPalette.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(TEPalette.red.opacity(0.45), lineWidth: 1)
                    )
            }

            HStack {
                SettingsLink {
                    Text("SETTINGS")
                }
                .buttonStyle(TEKeyButtonStyle(tone: .neutral, compact: true))
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(TEKeyButtonStyle(tone: .neutral, compact: true))
            }
        }
    }
}

private enum TEPalette {
    static let shell = Color(red: 0.91, green: 0.89, blue: 0.82)
    static let panel = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let recess = Color(red: 0.83, green: 0.81, blue: 0.74)
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.06)
    static let muted = Color(red: 0.36, green: 0.35, blue: 0.30)
    static let display = Color(red: 0.035, green: 0.045, blue: 0.035)
    static let lcd = Color(red: 0.68, green: 0.93, blue: 0.53)
    static let orange = Color(red: 1.0, green: 0.47, blue: 0.14)
    static let red = Color(red: 0.96, green: 0.12, blue: 0.09)
    static let blue = Color(red: 0.12, green: 0.45, blue: 0.88)
    static let yellow = Color(red: 1.0, green: 0.82, blue: 0.18)
}

private enum TEFonts {
    static let label = Font.system(size: 10, weight: .bold, design: .monospaced)
    static let micro = Font.system(size: 8, weight: .bold, design: .monospaced)
}

private struct TEPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(TEFonts.label)
                    .tracking(1.2)
                Spacer()
                Rectangle()
                    .fill(TEPalette.ink.opacity(0.18))
                    .frame(height: 1)
            }
            content
        }
        .padding(12)
        .background(TEPalette.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(TEPalette.ink.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct PresetKey: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .monospacedDigit()
                Text(subtitle)
                    .font(TEFonts.micro)
            }
            .frame(width: 52, height: 42)
        }
        .buttonStyle(TEKeyButtonStyle(tone: .yellow))
    }
}

private struct StatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(TEFonts.label)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(TEPalette.panel)
        .overlay(
            Capsule()
                .stroke(TEPalette.ink.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct StatusDot: View {
    let active: Bool

    var body: some View {
        Circle()
            .fill(active ? TEPalette.lcd : TEPalette.muted.opacity(0.35))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(TEPalette.ink.opacity(0.7), lineWidth: 1))
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 8) {
            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                .font(TEFonts.label)
                .monospacedDigit()
                .frame(width: 58, alignment: .leading)
            Text(event.title.uppercased())
                .font(TEFonts.label)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(TEPalette.recess.opacity(0.65))
    }
}

private struct EmptyEventRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TEFonts.label)
            .foregroundStyle(TEPalette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(TEPalette.recess.opacity(0.45))
    }
}

private struct TEKeyButtonStyle: ButtonStyle {
    enum Tone {
        case neutral
        case orange
        case red
        case blue
        case yellow

        var fill: Color {
            switch self {
            case .neutral:
                TEPalette.recess
            case .orange:
                TEPalette.orange
            case .red:
                TEPalette.red
            case .blue:
                TEPalette.blue
            case .yellow:
                TEPalette.yellow
            }
        }

        var foreground: Color {
            switch self {
            case .red, .blue:
                .white
            case .neutral, .orange, .yellow:
                TEPalette.ink
            }
        }
    }

    let tone: Tone
    var compact = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TEFonts.label)
            .tracking(0.8)
            .foregroundStyle(isEnabled ? tone.foreground : TEPalette.ink.opacity(0.35))
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, compact ? 6 : 9)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isEnabled ? tone.fill : TEPalette.recess.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(TEPalette.ink.opacity(isEnabled ? 0.85 : 0.25), lineWidth: 1)
            )
            .shadow(
                color: TEPalette.ink.opacity(isEnabled && !configuration.isPressed ? 0.28 : 0),
                radius: 0,
                x: 0,
                y: isEnabled && !configuration.isPressed ? 2 : 0
            )
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
