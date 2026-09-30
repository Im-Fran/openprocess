import SwiftUI

/// First-run welcome sheet. One skippable screen; reopen it from Help ▸ Welcome to OpenProcess.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("menuBarOnly") private var menuBarOnly = false

    private let features: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("list.bullet.rectangle", "All processes",
         "Sort, search, and filter by name, PID, user, or path. View them as a list or a tree and choose the columns."),
        ("xmark.octagon", "Process control",
         "Quit a process, force it to quit, or send it any signal. You’re always asked to confirm first."),
        ("info.circle", "Info and sampling",
         "Inspect a process and its open files and ports, or take a 3‑second sample to see what it’s busy with."),
        ("chart.xyaxis.line", "System metrics",
         "Per-core CPU, GPU, memory and pressure, energy and temperature, disk and network, with live history."),
        ("menubar.rectangle", "In the menu bar",
         "A summary always in view. You can close the window and keep OpenProcess in the menu bar only."),
        ("lock.shield", "Privileged helper (optional)",
         "Install it in Settings to see and quit system processes and other users’ processes, and to purge memory."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("Welcome to OpenProcess")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A native activity monitor for your Mac.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(features, id: \.symbol) { feature in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: feature.symbol)
                            .font(.title)
                            .foregroundStyle(.tint)
                            .frame(width: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title).font(.headline)
                            Text(feature.detail)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Toggle("Keep running in the menu bar when the window closes", isOn: $menuBarOnly)
                .help("When the window closes, OpenProcess leaves the Dock and keeps measuring from the menu bar")

            Button("Continue") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Close the welcome screen and start using OpenProcess")
        }
        .padding(32)
        .frame(width: 520)
    }
}
