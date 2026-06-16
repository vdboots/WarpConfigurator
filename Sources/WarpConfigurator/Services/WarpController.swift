import Foundation
import AppKit

enum WarpControllerError: LocalizedError {
    case adminFailed(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .adminFailed(let code, let msg):
            return String(localized: "WARP restart failed (\(Int(code))): \(msg)", bundle: .module)
        }
    }
}

enum WarpController {
    /// Killt frontend + daemon (sudo), opent daarna de WARP app opnieuw.
    static func restartAndLaunch() throws {
        let script = """
        do shell script "/usr/bin/killall 'Cloudflare WARP' 2>/dev/null; /usr/bin/killall warp-svc 2>/dev/null; exit 0" with administrator privileges with prompt "Cloudflare WARP herstarten"
        """
        try runOsascript(script)
        Thread.sleep(forTimeInterval: 1.2)
        launchWarpApp()
    }

    static func launchWarpApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Cloudflare WARP"]
        try? task.run()
    }

    private static func runOsascript(_ script: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let err = Pipe()
        task.standardError = err
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw WarpControllerError.adminFailed(code: task.terminationStatus, message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
