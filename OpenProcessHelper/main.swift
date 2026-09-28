import Foundation

/// Privileged launch daemon: delivers signals, purges memory and reads stats of processes the app can't.
final class Helper: NSObject, OpenProcessHelperProtocol, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Only our own signed app may talk to us.
        connection.setCodeSigningRequirement(
            "anchor apple generic and identifier \"cl.franciscosolis.openprocess\" and certificate leaf[subject.OU] = \"\(teamID)\""
        )
        connection.exportedInterface = NSXPCInterface(with: OpenProcessHelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func version(reply: @escaping @Sendable (String) -> Void) { reply(helperVersion) }

    func sendSignal(_ signal: Int32, toPID pid: Int32, reply: @escaping @Sendable (Int32) -> Void) {
        guard pid > 1, allowedSignals.contains(signal) else { return reply(EINVAL) }
        reply(kill(pid, signal) == 0 ? 0 : errno)
    }

    func purgeMemory(reply: @escaping @Sendable (Int32) -> Void) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        do {
            try p.run()
            p.waitUntilExit()
            reply(p.terminationStatus)
        } catch {
            reply(ENOENT)
        }
    }

    func stats(forPIDs pids: [Int32], reply: @escaping @Sendable (Data) -> Void) {
        let stats = pids.prefix(8192).compactMap(RawProcStats.read(pid:))
        reply((try? JSONEncoder().encode(stats)) ?? Data())
    }
}

let helper = Helper()
let listener = NSXPCListener(machServiceName: helperMachServiceName)
listener.delegate = helper
listener.resume()
RunLoop.main.run()
