import ShakeTimerCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Alarm") {
                Stepper(
                    "Default snooze: \(Int(model.settings.defaultSnoozeSeconds / 60)) min",
                    value: secondsBinding(\.defaultSnoozeSeconds, minutes: true),
                    in: 1...60,
                    step: 1
                )
                Stepper(
                    "Max cue duration: \(Int(model.settings.maxAlarmSeconds)) sec",
                    value: secondsBinding(\.maxAlarmSeconds),
                    in: 5...120,
                    step: 5
                )
                Picker("Visual cue", selection: visualCueBinding()) {
                    ForEach(VisualCueKind.allCases, id: \.self) { cue in
                        Text(cue.title).tag(cue)
                    }
                }
                Slider(value: doubleBinding(\.visualIntensity), in: 0.1...1) {
                    Text("Visual intensity")
                } minimumValueLabel: {
                    Text("Low")
                } maximumValueLabel: {
                    Text("High")
                }
                Text(model.settings.visualCueKind.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Preview Visual Cue") {
                    model.previewVisualCue()
                }
                Toggle("Respect Reduce Motion", isOn: boolBinding(\.respectReduceMotion))
            }

            Section("Meetings") {
                Stepper(
                    "Cue before meetings: \(Int(model.settings.meetingLeadSeconds / 60)) min",
                    value: secondsBinding(\.meetingLeadSeconds, minutes: true),
                    in: 0...30,
                    step: 1
                )
                Stepper(
                    "Calendar poll: \(Int(model.settings.calendarPollSeconds)) sec",
                    value: secondsBinding(\.calendarPollSeconds, onSet: model.rescheduleCalendarPolling),
                    in: 15...900,
                    step: 15
                )
                TextField("Calendar ID", text: stringBinding(\.selectedCalendarID))
                    .textFieldStyle(.roundedBorder)
            }

            Section("Google OAuth") {
                TextField("Client ID", text: stringBinding(\.googleClientID))
                    .textFieldStyle(.roundedBorder)
                SecureField("Client secret (optional)", text: $model.googleClientSecret)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(model.googleCalendar.isConnected ? "Reconnect Google Calendar" : "Connect Google Calendar") {
                        model.connectGoogleCalendar()
                    }
                    .disabled(model.settings.googleClientID.isEmpty)
                    Button("Disconnect") {
                        model.disconnectGoogleCalendar()
                    }
                    .disabled(!model.googleCalendar.isConnected)
                }
            }
        }
    }

    private func doubleBinding(_ keyPath: WritableKeyPath<AppSettings, Double>) -> Binding<Double> {
        Binding {
            model.settings[keyPath: keyPath]
        } set: { newValue in
            model.settings[keyPath: keyPath] = newValue
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<AppSettings, Bool>) -> Binding<Bool> {
        Binding {
            model.settings[keyPath: keyPath]
        } set: { newValue in
            model.settings[keyPath: keyPath] = newValue
        }
    }

    private func stringBinding(_ keyPath: WritableKeyPath<AppSettings, String>) -> Binding<String> {
        Binding {
            model.settings[keyPath: keyPath]
        } set: { newValue in
            model.settings[keyPath: keyPath] = newValue
        }
    }

    private func visualCueBinding() -> Binding<VisualCueKind> {
        Binding {
            model.settings.visualCueKind
        } set: { newValue in
            model.settings.visualCueKind = newValue
        }
    }

    private func secondsBinding(
        _ keyPath: WritableKeyPath<AppSettings, TimeInterval>,
        minutes: Bool = false,
        onSet: (() -> Void)? = nil
    ) -> Binding<Double> {
        Binding {
            minutes ? model.settings[keyPath: keyPath] / 60 : model.settings[keyPath: keyPath]
        } set: { newValue in
            model.settings[keyPath: keyPath] = minutes ? newValue * 60 : newValue
            onSet?()
        }
    }
}
