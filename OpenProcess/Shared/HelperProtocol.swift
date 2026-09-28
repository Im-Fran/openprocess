import Foundation

let helperMachServiceName = "cl.franciscosolis.openprocess.helper"
let helperPlistName = "cl.franciscosolis.openprocess.helper.plist"
let helperVersion = "1"
let teamID = "PX7HA29NR3"

/// XPC interface of the privileged helper. Replies return `errno` (0 = success).
@objc protocol OpenProcessHelperProtocol {
    func version(reply: @escaping @Sendable (String) -> Void)
    func sendSignal(_ signal: Int32, toPID pid: Int32, reply: @escaping @Sendable (Int32) -> Void)
    func purgeMemory(reply: @escaping @Sendable (Int32) -> Void)
    /// JSON-encoded `[RawProcStats]` for the pids the helper could read.
    func stats(forPIDs pids: [Int32], reply: @escaping @Sendable (Data) -> Void)
}

/// Signals the helper is allowed to deliver.
let allowedSignals: Set<Int32> = [SIGTERM, SIGKILL, SIGINT, SIGHUP, SIGSTOP, SIGCONT, SIGQUIT, SIGUSR1, SIGUSR2]
