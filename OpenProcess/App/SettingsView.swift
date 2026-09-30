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
                Picker("Frecuencia de actualización", selection: $monitor.interval) {
                    Text("Muy frecuente (1 s)").tag(1.0)
                    Text("Frecuente (2 s)").tag(2.0)
                    Text("Normal (5 s)").tag(5.0)
                }
                .help("Cada cuánto se vuelven a leer los procesos y las métricas. Más frecuente usa más CPU")
                Toggle("Mostrar en la barra de menús", isOn: $showMenuBarExtra)
                    .help("Mostrar el uso de CPU y un resumen del sistema en la barra de menús")
                Toggle("Seguir solo en la barra de menús al cerrar la ventana", isOn: $menuBarOnly)
                    .disabled(!showMenuBarExtra)
                    .help("Al cerrar la ventana, OpenProcess desaparece del Dock y sigue midiendo desde la barra de menús")
            } header: {
                Text("General")
            } footer: {
                Text("Con la ventana cerrada, vuelve a abrirla desde el ícono de la barra de menús ▸ Abrir OpenProcess.")
                    .foregroundStyle(.secondary)
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
                            .help("Quitar el asistente privilegiado; se pierden las métricas de otros usuarios y la purga de memoria")
                    case .requiresApproval:
                        Button("Abrir Ítems de inicio…") { SMAppService.openSystemSettingsLoginItems() }
                            .help("Abrir Ajustes del Sistema para aprobar el asistente")
                        Button("Comprobar de nuevo") { monitor.helper.refresh() }
                            .help("Volver a comprobar si el asistente ya fue aprobado")
                    default:
                        Button("Instalar asistente…") { monitor.helper.install() }
                            .help("Registrar el asistente privilegiado; macOS pedirá que lo apruebes")
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