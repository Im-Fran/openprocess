import Foundation
import IOKit
import IOKit.ps

// ponytail: IOReport, IOHIDEventSystemClient and SMC keys are private/undocumented and may change
// between macOS releases or chips; every source degrades to nil and the UI shows it as unavailable.

/// Reads float keys from the System Management Controller.
final class SMC {
    private struct KeyInfo { var dataSize: UInt32 = 0; var dataType: UInt32 = 0; var attributes: UInt8 = 0; var pad: (UInt8, UInt8, UInt8) = (0, 0, 0) }
    private struct Param {
        var key: UInt32 = 0
        var vers: (UInt8, UInt8, UInt8, UInt8, UInt16) = (0, 0, 0, 0, 0)
        var pLimit: (UInt16, UInt16, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0)
        var keyInfo = KeyInfo()
        var result: UInt8 = 0, status: UInt8 = 0, command: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
    }

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: KeyInfo] = [:]

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        defer { IOObjectRelease(service) }
        guard service != 0, IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
    }

    deinit { IOServiceClose(connection) }

    private func call(_ input: Param) -> Param? {
        var input = input, output = Param()
        var size = MemoryLayout<Param>.stride
        guard IOConnectCallStructMethod(connection, 2, &input, MemoryLayout<Param>.stride, &output, &size) == KERN_SUCCESS,
              output.result == 0 else { return nil }
        return output
    }

    func float(_ key: String) -> Double? {
        let code = key.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        if infoCache[code] == nil {
            guard let info = call(Param(key: code, command: 9)) else { return nil }
            infoCache[code] = info.keyInfo
        }
        guard let info = infoCache[code], info.dataType == 0x666C_7420 /* "flt " */, info.dataSize == 4,
              let out = call(Param(key: code, keyInfo: info, command: 5)) else { return nil }
        let value = withUnsafeBytes(of: out.bytes) { $0.load(as: Float.self) }
        return value.isFinite ? Double(value) : nil
    }
}

/// GPU energy from the private IOReport "Energy Model" group.
final class IOReportEnergy {
    private typealias CopyChannels = @convention(c) (CFString?, CFString?, UInt64, UInt64, UInt64) -> Unmanaged<CFDictionary>?
    private typealias CreateSubscription = @convention(c) (UnsafeMutableRawPointer?, CFMutableDictionary, UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, UInt64, CFTypeRef?) -> OpaquePointer?
    private typealias CreateSamples = @convention(c) (OpaquePointer, CFMutableDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias CreateDelta = @convention(c) (CFDictionary, CFDictionary, CFTypeRef?) -> Unmanaged<CFDictionary>?
    private typealias GetString = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias GetInteger = @convention(c) (CFDictionary, Int32) -> Int64

    private let createSamples: CreateSamples, createDelta: CreateDelta
    private let channelName: GetString, unitLabel: GetString, integerValue: GetInteger
    private let subscription: OpaquePointer
    private let channels: CFMutableDictionary
    private var previous: CFDictionary?

    init?() {
        guard let lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_NOW) else { return nil }
        func sym<T>(_ name: String, _: T.Type) -> T? { dlsym(lib, name).map { unsafeBitCast($0, to: T.self) } }
        guard let copy = sym("IOReportCopyChannelsInGroup", CopyChannels.self),
              let subscribe = sym("IOReportCreateSubscription", CreateSubscription.self),
              let samples = sym("IOReportCreateSamples", CreateSamples.self),
              let delta = sym("IOReportCreateSamplesDelta", CreateDelta.self),
              let name = sym("IOReportChannelGetChannelName", GetString.self),
              let unit = sym("IOReportChannelGetUnitLabel", GetString.self),
              let value = sym("IOReportSimpleGetIntegerValue", GetInteger.self),
              let group = copy("Energy Model" as CFString, nil, 0, 0, 0)?.takeRetainedValue(),
              let desired = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, group) else { return nil }
        var subbed: Unmanaged<CFMutableDictionary>?
        guard let sub = subscribe(nil, desired, &subbed, 0, nil), let subbed else { return nil }
        subscription = sub
        channels = subbed.takeRetainedValue()
        createSamples = samples; createDelta = delta
        channelName = name; unitLabel = unit; integerValue = value
    }

    /// Joules per channel name since the previous call.
    func sample() -> [String: Double] {
        guard let current = createSamples(subscription, channels, nil)?.takeRetainedValue() else { return [:] }
        defer { previous = current }
        guard let previous, let delta = createDelta(previous, current, nil)?.takeRetainedValue(),
              let list = (delta as NSDictionary)["IOReportChannels"] as? [CFDictionary] else { return [:] }
        var result: [String: Double] = [:]
        for channel in list {
            guard let name = channelName(channel)?.takeUnretainedValue() as String? else { continue }
            let scale: Double = switch unitLabel(channel)?.takeUnretainedValue() as String? {
            case "mJ": 1e-3
            case "uJ": 1e-6
            case "nJ": 1e-9
            default: 0
            }
            let value = Double(integerValue(channel, 0)) * scale
            if value > 0 { result[name, default: 0] += value }
        }
        return result
    }
}

/// Temperature sensors via the private IOHIDEventSystemClient API.
final class HIDTemperatures {
    private typealias ClientCreate = @convention(c) (CFAllocator?) -> Unmanaged<CFTypeRef>?
    private typealias SetMatching = @convention(c) (CFTypeRef, CFDictionary) -> Int32
    private typealias CopyServices = @convention(c) (CFTypeRef) -> Unmanaged<CFArray>?
    private typealias CopyProperty = @convention(c) (CFTypeRef, CFString) -> Unmanaged<CFTypeRef>?
    private typealias CopyEvent = @convention(c) (CFTypeRef, Int64, Int32, Int64) -> Unmanaged<CFTypeRef>?
    private typealias GetFloat = @convention(c) (CFTypeRef, Int32) -> Double

    private let client: CFTypeRef
    private let copyServices: CopyServices, copyProperty: CopyProperty, copyEvent: CopyEvent, getFloat: GetFloat
    private static let temperatureEvent: Int64 = 15

    init?() {
        guard let lib = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else { return nil }
        func sym<T>(_ name: String, _: T.Type) -> T? { dlsym(lib, name).map { unsafeBitCast($0, to: T.self) } }
        guard let create = sym("IOHIDEventSystemClientCreate", ClientCreate.self),
              let match = sym("IOHIDEventSystemClientSetMatching", SetMatching.self),
              let services = sym("IOHIDEventSystemClientCopyServices", CopyServices.self),
              let property = sym("IOHIDServiceClientCopyProperty", CopyProperty.self),
              let event = sym("IOHIDServiceClientCopyEvent", CopyEvent.self),
              let float = sym("IOHIDEventGetFloatValue", GetFloat.self),
              let client = create(kCFAllocatorDefault)?.takeRetainedValue() else { return nil }
        _ = match(client, ["PrimaryUsagePage": 0xFF00, "PrimaryUsage": 5] as CFDictionary)
        self.client = client
        copyServices = services; copyProperty = property; copyEvent = event; getFloat = float
    }

    func sample() -> [TemperatureSensor] {
        guard let services = copyServices(client)?.takeRetainedValue() as? [CFTypeRef] else { return [] }
        var byName: [String: Double] = [:]
        for service in services {
            guard let name = copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String,
                  let event = copyEvent(service, Self.temperatureEvent, 0, 0)?.takeRetainedValue() else { continue }
            let celsius = getFloat(event, Int32(Self.temperatureEvent << 16))
            // Discard uncalibrated/placeholder readings.
            guard celsius > 0, celsius < 150 else { continue }
            byName[name] = max(byName[name] ?? 0, celsius)
        }
        return byName.map { TemperatureSensor(name: $0.key, celsius: $0.value) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

final class PowerSampler {
    private let smc = SMC()
    private let ioreport = IOReportEnergy()
    private let hid = HIDTemperatures()

    func sample(seconds: Double) -> PowerSnapshot {
        var snap = PowerSnapshot()
        snap.system = smc?.float("PSTR")
        if let joules = ioreport?.sample()["GPU Energy"], seconds > 0 { snap.gpu = joules / seconds }
        snap.sensors = hid?.sample() ?? []
        snap.battery = Self.battery()
        return snap
    }

    static func battery() -> BatteryInfo? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in list {
            guard let d = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            let remaining = (d[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
            var info = BatteryInfo(
                percent: max > 0 ? current * 100 / max : current,
                isCharging: d[kIOPSIsChargingKey] as? Bool ?? false,
                onAC: d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                minutesRemaining: remaining
            )
            let smart = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
            if smart != 0 {
                let props = IOKitRegistry.properties(smart)
                // Newer Macs only publish capacities inside "BatteryData".
                let data = props["BatteryData"] as? [String: Any] ?? [:]
                func value(_ key: String) -> Int? { props[key] as? Int ?? data[key] as? Int }
                info.cycleCount = value("CycleCount")
                if let design = value("DesignCapacity"), let raw = value("AppleRawMaxCapacity"), design > 0 {
                    info.health = min(100, raw * 100 / design)
                }
                IOObjectRelease(smart)
            }
            return info
        }
        return nil
    }
}
