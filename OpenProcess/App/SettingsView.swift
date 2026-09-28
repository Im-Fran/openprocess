import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

    var body: some View {
        @Bindable var monitor = monitor
        Form {
            Section("General") {
                Picker("Frecuencia de actualización", selection: $monitor.interval) {
                    Text("Muy frecuente (1 s)").tag(1.0)
                    Text("Frecuente (2 s)").tag(2.0)
                    Text("Normal (5 s)").tag(5.0)
                }
                Toggle("Mostrar en la barra de menús", isOn: $showMenuBarExtra)
            }
            Section {
                LabeledContent("Estado") {
                    switch monitor.helper.state {
                    case .enabled: StatusLabel("Activo", symbol: "checkmark.circle.fill", color: .green)
                    case .requiresApproval: StatusLabel("Requiere aprobación", symbol: "exclamationmark.triangle.fill", color: .yellow)
                    case .notInstalled: StatusLabel("No instalado", symbol: "circle", color: .secondary)
                    case .unavailable(let error): StatusLabel(LocalizedStringKey(error), symbol: "xmark.octagon.fill", color: .red)
                    }
                }
                HStack {
                    switch monitor.helper.state {
                    case .enabled:
                        Button("Desinstalar asistente") { monitor.helper.uninstall() }
                    case .requiresApproval:
                        Button("Abrir Ítems de inicio…") { SMAppService.openSystemSettingsLoginItems() }
                        Button("Comprobar de nuevo") { monitor.helper.refresh() }
                    default:
                        Button("Instalar asistente…") { monitor.helper.install() }
                    }
                }
            } header: {
                Text("Asistente privilegiado")
            } footer: {
                Text("Permite ver métricas de procesos del sistema y de otros usuarios, terminarlos y purgar la memoria. Tras instalarlo, apruébalo en Ajustes del Sistema ▸ General ▸ Ítems de inicio.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { monitor.helper.refresh() }
    }
}