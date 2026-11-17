import AppKit
import Combine
import Foundation

/// V2 application delegate for Launch Services, Finder, and Dock open events.
/// It deliberately contains no legacy KernelLumi/FactoryCore dependency: the
/// path is handed to `KernelFactory` after the shared V2 kernel is ready.
@MainActor
final class LumiAppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    /// 待打开的外部路径队列。冷启动时 Launch Services 可能一次送来多个
    /// 文件，且事件可能先于主窗口的订阅到达；单值会被同批次后续项覆盖，
    /// 必须排队逐个消费（#441）。
    @Published var pendingOpenPaths: [String] = []
    /// 是否已有消费循环在跑：防止多个批次触发并发 drain 重复处理。
    private var isDrainingPendingOpenPaths = false

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if handleFinderCommand(url) { continue }
            if url.isFileURL {
                pendingOpenPaths.append(url.standardizedFileURL.path)
            }
        }
        activateMainWindow()
    }

    func application(_ application: NSApplication, openFile filename: String) -> Bool {
        pendingOpenPaths.append((filename as NSString).standardizingPath)
        activateMainWindow()
        return true
    }

    private func handleFinderCommand(_ url: URL) -> Bool {
        guard url.scheme == Self.urlScheme, url.host == "finder" else {
            return false
        }

        switch url.path {
        case "/show-hidden":
            return handleShowHiddenCommand(url)
        case "/open-project":
            return handleOpenProjectCommand(url)
        default:
            return false
        }
    }

    /// 处理 `lumi://finder/show-hidden?value=true|false`。
    private func handleShowHiddenCommand(_ url: URL) -> Bool {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "value" })?.value,
              let showHiddenFiles = Bool(value) else {
            return false
        }

        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = [
            "write", "com.apple.finder", "AppleShowAllFiles", "-bool",
            showHiddenFiles ? "true" : "false"
        ]
        try? defaults.run()
        defaults.waitUntilExit()
        guard defaults.terminationStatus == 0 else { return true }

        let restart = Process()
        restart.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        restart.arguments = ["Finder"]
        try? restart.run()
        return true
    }

    /// 处理 `lumi://finder/open-project?path=<文件夹绝对路径>`。
    ///
    /// 该命令由 Finder 右键扩展的「在 Lumi 中打开」发出。这里只把路径
    /// 交给 `pendingOpenPaths`，由主视图按既有的外部路径流程切换当前项目，
    /// 避免在 App Delegate 里直接依赖内核。
    private func handleOpenProjectCommand(_ url: URL) -> Bool {
        guard let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "path" })?.value,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        pendingOpenPaths.append((path as NSString).standardizingPath)
        return true
    }

    /// 逐个消费排队的打开请求。
    ///
    /// 同一时刻只允许一个消费循环：drain 进行中新到达的批次交给当前循环
    /// 的下一轮迭代，而不是再起一个并发循环。循环内先弹出队首再处理，
    /// 处理期间新入队的项不会丢（#441）。
    func drainPendingOpenPaths(_ open: (String) async -> Void) async {
        guard !isDrainingPendingOpenPaths else { return }
        isDrainingPendingOpenPaths = true
        defer { isDrainingPendingOpenPaths = false }
        while let path = pendingOpenPaths.first {
            pendingOpenPaths.removeFirst()
            await open(path)
        }
    }

    private func activateMainWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.identifier == LumiWindowIdentity.main })?
                .makeKeyAndOrderFront(nil)
        }
    }

    private static var urlScheme: String {
        (Bundle.main.object(forInfoDictionaryKey: "LumiURLScheme") as? String)
            ?? "lumi"
    }
}
