import Foundation

enum ProfileRevokerError: LocalizedError {
    case failed(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .failed(let code, let msg):
            return String(localized: "profiles remove failed (\(Int(code))): \(msg)", bundle: .module)
        }
    }
}

enum ProfileRevoker {
    static func revoke(identifier: String = "cloudflare_warp") throws {
        let escaped = identifier.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"/usr/bin/profiles remove -identifier \(escaped)\" with administrator privileges with prompt \"Cloudflare WARP profiel verwijderen\""
        try runOsascript(script)
    }

    static func isInstalled(identifier: String = "cloudflare_warp") -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        task.arguments = ["list", "-type", "configuration"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch { return false }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return out.contains(identifier)
    }

    private static func runOsascript(_ script: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let errPipe = Pipe()
        task.standardError = errPipe
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus != 0 {
            let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ProfileRevokerError.failed(code: task.terminationStatus, message: msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
