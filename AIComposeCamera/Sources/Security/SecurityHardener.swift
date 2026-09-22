import Foundation
import UIKit
import Darwin

/// Defensive security module providing anti-debugging, jailbreak detection,
/// and runtime integrity verification against reverse engineering and tampering.
public enum SecurityHardener {

    /// Apply all anti-reversing defenses on app launch.
    public static func applyProtections() {
        #if !DEBUG
        denyDebuggerAttachment()
        #endif
    }

    /// Check if a debugger is currently attached using sysctl (P_TRACED).
    public static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride

        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Prevents debuggers (LLDB, GDB, Frida, Cycript) from attaching to the process.
    /// Uses PT_DENY_ATTACH via dynamic symbol resolution to avoid static detection.
    private static func denyDebuggerAttachment() {
        typealias PtraceType = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt

        guard let handle = dlopen(nil, RTLD_GLOBAL | RTLD_NOW) else { return }
        defer { dlclose(handle) }

        if let ptraceSym = dlsym(handle, "ptrace") {
            let ptraceFunc = unsafeBitCast(ptraceSym, to: PtraceType.self)
            _ = ptraceFunc(31 /* PT_DENY_ATTACH */, 0, 0, 0)
        }
    }

    /// Checks if device environment has been compromised (jailbreak detection).
    public static var isDeviceCompromised: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // 1. Check known jailbreak files and paths
        let suspiciousPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/usr/bin/ssh",
            "/private/var/lib/apt",
            "/private/var/lib/cydia",
            "/private/var/stash"
        ]

        for path in suspiciousPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }

        // 2. Check ability to write outside sandbox
        let testPath = "/private/jb_test_\(UUID().uuidString).txt"
        do {
            try "jb_test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: testPath)
            return true // Sandbox violation succeeded -> Jailbroken
        } catch {
            // Expected for non-jailbroken devices
        }

        // 3. Check suspicious URL schemes
        if let cydiaURL = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(cydiaURL) {
            return true
        }

        return false
        #endif
    }
}
