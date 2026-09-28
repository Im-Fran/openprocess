import Foundation
import ServiceManagement

/// Registers and talks to the privileged launch daemon.
@MainActor @Observable
final class HelperClient {
    enum State: Equatable { case notInstalled, requiresApproval, enabled, unavailable(String) }

    private(set) var state: State = .notInstalled
    private let service = SMAppService.daemon(plistName: helperPlistName)
    @ObservationIgnored private var connection: NSXPCConnection?

    init() { refresh() }

    var isEnabled: Bool { state == .enabled }

    func refresh() {
        state = switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .notInstalled
        @unknown default: .notInstalled
        }
    }

    func install() {
        do {
            try service.register()
        } catch {
            state = .unavailable(error.localizedDescription)
            if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            return
        }
        refresh()
        if state == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    func uninstall() {
        connection?.invalidate()
        connection = nil
        try? service.unregister()
        refresh()
    }

    private func proxy(_ onError: @escaping @Sendable (Error) -> Void) -> OpenProcessHelperProtocol? {
        if connection == nil {
            let c = NSXPCConnection(machServiceName: helperMachServiceName, options: .privileged)
            c.remoteObjectInterface = NSXPCInterface(with: OpenProcessHelperProtocol.self)
            // Make sure we only talk to our own helper.
            c.setCodeSigningRequirement(
                "anchor apple generic and identifier \"cl.franciscosolis.openprocess.helper\" and certificate leaf[subject.OU] = \"\(teamID)\""
            )
            c.invalidationHandler = { [weak self] in Task { @MainActor in self?.connection = nil } }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler(onError) as? OpenProcessHelperProtocol
    }

    /// Calls the helper; returns nil if it isn't enabled or the call failed.
    private func call<T: Sendable>(_ body: (OpenProcessHelperProtocol, @escaping @Sendable (T) -> Void) -> Void) async -> T? {
        guard isEnabled else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<T?, Never>) in
            let once = ResumeOnce(cont)
            guard let proxy = proxy({ _ in once.resume(nil) }) else { return once.resume(nil) }
            body(proxy) { once.resume($0) }
        }
    }

    func sendSignal(_ signal: Int32, to pid: Int32) async -> Int32? {
        await call { $0.sendSignal(signal, toPID: pid, reply: $1) }
    }

    func purgeMemory() async -> Int32? {
        await call { $0.purgeMemory(reply: $1) }
    }

    func stats(for pids: [Int32]) async -> [RawProcStats] {
        guard !pids.isEmpty, let data: Data = await call({ $0.stats(forPIDs: pids, reply: $1) }) else { return [] }
        return (try? JSONDecoder().decode([RawProcStats].self, from: data)) ?? []
    }
}

/// XPC may call both the error handler and the reply; resume exactly once.
private final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?
    init(_ c: CheckedContinuation<T?, Never>) { continuation = c }
    func resume(_ value: T?) {
        lock.withLock { continuation?.resume(returning: value); continuation = nil }
    }
}
