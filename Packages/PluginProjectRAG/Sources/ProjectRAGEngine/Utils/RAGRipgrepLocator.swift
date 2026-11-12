import Foundation

/// 定位 ripgrep 可执行文件：优先随应用打包的副本，系统安装作为兜底。
enum RAGRipgrepLocator {
    static func executable() -> URL? {
        candidates().first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    static func candidates() -> [URL] {
        var urls: [URL] = []
        // 构建脚本把签名后的 rg 拷到主可执行文件同目录（Contents/MacOS）；
        // 资源 bundle 内的副本未签名，Hardened Runtime 下不能优先使用。
        if let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent() {
            urls.append(executableDirectory.appendingPathComponent("rg"))
        }
        #if SWIFT_PACKAGE
        if let packageResource = Bundle.module.url(forResource: "rg", withExtension: nil) {
            urls.append(packageResource)
        }
        #endif
        let pathEntries = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        urls.append(contentsOf: pathEntries.map { URL(fileURLWithPath: "\($0)/rg") })
        urls.append(contentsOf: [
            URL(fileURLWithPath: "/opt/homebrew/bin/rg"),
            URL(fileURLWithPath: "/usr/local/bin/rg"),
            URL(fileURLWithPath: "/usr/bin/rg"),
        ])
        return urls
    }
}