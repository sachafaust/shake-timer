import SwiftUI

@main
struct ShakeTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
                .frame(width: 430)
        } label: {
            Label(model.statusTitle, systemImage: model.isAlarmActive ? "alarm.waves.left.and.right.fill" : "timer")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(width: 440)
                .padding()
        }
    }
}
