import SwiftUI

enum Format {
    static func bytes(_ value: Double) -> String {
        Int64(value).formatted(.byteCount(style: .memory))
    }

    static func bytes(_ value: UInt64) -> String { bytes(Double(value)) }

    static func rate(_ value: Double) -> String {
        value < 1 ? "0 B/s" : "\(Int64(value).formatted(.byteCount(style: .file)))/s"
    }

    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0...1)))
    }

    /// CPU % of one core, Activity Monitor style ("12.3").
    static func cpu(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    static func watts(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(value < 10 ? 2 : 1)))) W"
    }

    static func celsius(_ value: Double?) -> String {
        guard let value else { return "—" }
        return Measurement(value: value, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600, m = Int(seconds) / 60 % 60
        let s = seconds.truncatingRemainder(dividingBy: 60)
        return h > 0
            ? String(format: "%d:%02d:%05.2f", h, m, s)
            : String(format: "%d:%05.2f", m, s)
    }

    static func uptime(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.days, .hours, .minutes], width: .narrow))
    }
}

enum ProcessIcon {
    @MainActor private static var cache: [String: NSImage] = [:]
    @MainActor private static let generic = NSWorkspace.shared.icon(for: .unixExecutable)

    /// App bundle icon for executables inside a `.app`, otherwise the generic executable icon.
    @MainActor static func image(for path: String?) -> NSImage {
        guard let path, let range = path.range(of: ".app/", options: .backwards) else { return generic }
        let bundle = String(path[..<range.lowerBound]) + ".app"
        if let icon = cache[bundle] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: bundle)
        cache[bundle] = icon
        return icon
    }
}
