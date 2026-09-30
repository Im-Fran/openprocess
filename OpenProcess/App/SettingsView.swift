import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("menuBarOnly") private var menuBarOnly = false

    var body: some View {
        @Bindable var monitor = monitor
        Form {
            Section {
                Picker("Update Frequency", selection: $monitor.interval) {
                    Text("Very Often (1 s)").tag(1.0)
                    Text("Often (2 s)").tag(2.0)
                    Text("Normally (5 s)").tag(5.0)
                }
                .help("How often processes and metrics are read again. More often uses more CPU")
                Toggle("Show in Menu Bar", isOn: $showMenuBarExtra)
                    .help("Show CPU usage and a system summary in the menu bar")
                Toggle("Keep running in the menu bar when the window closes", isOn: $menuBarOnly)
                    .disabled(!showMenuBarExtra)
                    .help("When the window closes, OpenProcess leaves the Dock and keeps measuring from the menu bar")
            } header: {
                Text("General")
            } footer: {
                Text("With the window closed, reopen it from the menu bar icon ▸ Open OpenProcess.")
                    .foregroundStyle(.secondary)
            }
            Section {
                LabeledContent("Status") {
                    switch monitor.helper.state {
                    case .enabled: StatusLabel("Active", symbol: "checkmark.circle.fill", color: .green)
                    case .requiresApproval: StatusLabel("Requires Approval", symbol: "exclamationmark.triangle.fill", color: .yellow)
                    case .notInstalled: StatusLabel("Not Installed", symbol: "circle", color: .secondary)
                    case .unavailable(let error): StatusLabel(LocalizedStringKey(error), symbol: "xmark.octagon.fill", color: .red)
                    }
                }
                HStack {
                    switch monitor.helper.state {
                    case .enabled:
                        Button("Uninstall Helper") { monitor.helper.uninstall() }
                            .help("Remove the privileged helper; metrics for other users and memory purging stop working")
                    case .requiresApproval:
                        Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                            .help("Open System Settings to approve the helper")
                        Button("Check Again") { monitor.helper.refresh() }
                            .help("Check again whether the helper has been approved")
                    default:
                        Button("Install Helper…") { monitor.helper.install() }
                            .help("Register the privileged helper; macOS will ask you to approve it")
                    }
                }
            } header: {
                Text("Privileged Helper")
            } footer: {
                Text("Lets you see metrics for system processes and other users’ processes, quit them, and purge memory. After installing it, approve it in System Settings ▸ General ▸ Login Items.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { monitor.helper.refresh() }
    }
}