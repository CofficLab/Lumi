import Foundation

/// Inherited by shell children, including interpreters and compiled helpers.
/// This confines direct desktop access, not arbitrary code, files or networking.
enum ShellDesktopSandbox {
    static let executable = "/usr/bin/sandbox-exec"
    static let profile = """
    (version 1)
    (allow default)
    (deny appleevent-send)
    (deny mach-lookup
        (global-name "com.apple.windowserver.active")
        (global-name "com.apple.windowserver")
        (global-name "com.apple.coreservices.appleevents")
        (global-name "com.apple.coreservices.launchservicesd")
        (global-name "com.apple.axserver")
        (local-name "com.apple.axserver")
        (global-name-regex #"^com\\.apple\\.accessibility\\.")
        (local-name-regex #"^com\\.apple\\.axserver"))
    """

    static func arguments(command: String) throws -> [String] {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw NSError(domain: "ShellDesktopSandbox", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Desktop-isolated shell execution is unavailable. Use accessibility_observe/accessibility_act or managed computer_act for UI tasks."])
        }
        return ["-p", profile, "/bin/zsh", "-lc", command]
    }
}
