import SwiftUI

/// First-run welcome sheet. One skippable screen; reopen it from Ayuda ▸ Bienvenida a OpenProcess.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("menuBarOnly") private var menuBarOnly = false

    private let features: [(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)] = [
        ("list.bullet.rectangle", "Todos los procesos",
         "Ordena, busca y filtra por nombre, PID, usuario o ruta. Míralos en lista o como árbol y elige las columnas."),
        ("xmark.octagon", "Control de procesos",
         "Sal de un proceso, fuerza su salida o envíale cualquier señal. Siempre se pide confirmación antes."),
        ("info.circle", "Información y muestreo",
         "Inspecciona un proceso, sus archivos y puertos abiertos, o toma una muestra de 3 segundos para ver en qué está ocupado."),
        ("chart.xyaxis.line", "Métricas del sistema",
         "CPU por núcleo, GPU, memoria y presión, energía y temperatura, disco y red, con historial en vivo."),
        ("menubar.rectangle", "En la barra de menús",
         "Un resumen siempre a la vista. Puedes cerrar la ventana y dejar OpenProcess solo en la barra de menús."),
        ("lock.shield", "Asistente privilegiado (opcional)",
         "Instálalo en Ajustes para ver y terminar procesos del sistema y de otros usuarios, y para purgar la memoria."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                Text("Te damos la bienvenida a OpenProcess")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Un monitor de actividad nativo para tu Mac.")
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

            Toggle("Seguir solo en la barra de menús al cerrar la ventana", isOn: $menuBarOnly)
                .help("Al cerrar la ventana, OpenProcess desaparece del Dock y sigue midiendo desde la barra de menús")

            Button("Continuar") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .help("Cerrar la bienvenida y empezar a usar OpenProcess")
        }
        .padding(32)
        .frame(width: 520)
    }
}
