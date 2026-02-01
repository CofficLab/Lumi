import Foundation

enum BrewError: Error {
    case notInstalled
    case commandFailed(String)
    case parsingError(Error)
    case notFound
}

actor BrewService {
    static let shared = BrewService()
    
    private var brewPath: String?
    
    init() {
        self.brewPath = findBrewPath()
    }
    
    private func findBrewPath() -> String? {
        let possiblePaths = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    func checkInstalled() -> Bool {
        return brewPath != nil
    }
    
    func getVersion() async throws -> String {
        return try await execute(["--version"])
    }
    
    // MARK: - Core Operations
    
    func listInstalled() async throws -> [BrewPackage] {
        // 获取所有已安装的 Casks 和 Formulae
        // brew info --json=v2 --installed
        let jsonString = try await execute(["info", "--json=v2", "--installed"])
        guard let data = jsonString.data(using: .utf8) else {
            throw BrewError.parsingError(NSError(domain: "BrewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data"]))
        }
        
        let info = try JSONDecoder().decode(BrewInfo.self, from: data)
        var packages: [BrewPackage] = []
        
        // 处理 Formulae
        for f in info.formulae {
            let version = f.versions?.stable ?? "unknown"
            let installedVer = f.installed?.first?.version
            packages.append(BrewPackage(
                name: f.name,
                desc: f.desc,
                homepage: f.homepage,
                version: version,
                installedVersion: installedVer,
                outdated: f.outdated ?? false,
                isCask: false
            ))
        }
        
        // 处理 Casks
        for c in info.casks {
            let version = c.version ?? "unknown"
            // Cask 只要出现在 installed 列表里就是已安装，通常没有详细的 installed 结构
            // 对于 Cask, version 字段就是当前最新版本，通常认为已安装的就是这个版本，或者需要检查 outdated
            packages.append(BrewPackage(
                name: c.token ?? c.name, // Cask 使用 token 作为标识符
                desc: c.desc,
                homepage: c.homepage,
                version: version,
                installedVersion: version, // 简化处理
                outdated: false, // 暂无法直接从 info 获取 cask outdated 状态，需配合 outdated 命令
                isCask: true
            ))
        }
        
        return packages
    }
    
    func getOutdated() async throws -> [BrewPackage] {
        // brew outdated --json=v2
        let jsonString = try await execute(["outdated", "--json=v2"])
        guard let data = jsonString.data(using: .utf8) else {
            throw BrewError.parsingError(NSError(domain: "BrewService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid data"]))
        }
        
        let info = try JSONDecoder().decode(BrewInfo.self, from: data)
        var packages: [BrewPackage] = []
        
        for f in info.formulae {
            packages.append(BrewPackage(
                name: f.name,
                desc: f.desc,
                homepage: f.homepage,
                version: f.versions?.stable ?? "unknown",
                installedVersion: f.installed?.first?.version,
                outdated: true,
                isCask: false
            ))
        }
        
        for c in info.casks {
             packages.append(BrewPackage(
                name: c.token ?? c.name,
                desc: c.desc,
                homepage: c.homepage,
                version: c.version ?? "unknown",
                installedVersion: nil, // Outdated info might not have installed version easily
                outdated: true,
                isCask: true
            ))
        }
        
        return packages
    }
    
    func search(query: String) async throws -> [BrewPackage] {
        // brew search --json query (注意：brew search 不支持 json 输出，或者支持有限)
        // 通常做法：brew search query 获取名称列表，然后 brew info --json=v2 names...
        
        // 简化实现：先只支持 Cask 的搜索
        // brew search --cask query
        let output = try await execute(["search", "--cask", query])
        let names = output.split(separator: "\n").map { String($0) }
        
        if names.isEmpty { return [] }
        
        // 获取详细信息
        // 限制数量，防止请求过多
        let limitNames = Array(names.prefix(10))
        return try await getInfo(names: limitNames, isCask: true)
    }
    
    func getInfo(names: [String], isCask: Bool) async throws -> [BrewPackage] {
        if names.isEmpty { return [] }
        
        var args = ["info", "--json=v2"]
        if isCask {
            args.append("--cask")
        }
        args.append(contentsOf: names)
        
        let jsonString = try await execute(args)
        guard let data = jsonString.data(using: .utf8) else { return [] }
        
        let info = try JSONDecoder().decode(BrewInfo.self, from: data)
        var packages: [BrewPackage] = []
        
        if isCask {
            for c in info.casks {
                packages.append(BrewPackage(
                    name: c.token ?? c.name,
                    desc: c.desc,
                    homepage: c.homepage,
                    version: c.version ?? "unknown",
                    installedVersion: nil, // Info 不包含安装状态，除非 installed
                    outdated: false,
                    isCask: true
                ))
            }
        } else {
            for f in info.formulae {
                packages.append(BrewPackage(
                    name: f.name,
                    desc: f.desc,
                    homepage: f.homepage,
                    version: f.versions?.stable ?? "unknown",
                    installedVersion: f.installed?.first?.version,
                    outdated: false,
                    isCask: false
                ))
            }
        }
        
        return packages
    }
    
    // MARK: - Actions
    
    func install(name: String, isCask: Bool) async throws {
        var args = ["install"]
        if isCask {
            args.append("--cask")
        }
        args.append(name)
        _ = try await execute(args)
    }
    
    func uninstall(name: String, isCask: Bool) async throws {
        var args = ["uninstall"]
        if isCask {
            args.append("--cask")
        }
        args.append(name)
        _ = try await execute(args)
    }
    
    func upgrade(name: String, isCask: Bool) async throws {
        var args = ["upgrade"]
        if isCask {
            args.append("--cask")
        }
        args.append(name)
        _ = try await execute(args)
    }
    
    // MARK: - Private Execution
    
    private func execute(_ args: [String]) async throws -> String {
        guard let brewPath = brewPath else {
            throw BrewError.notInstalled
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewPath)
        task.arguments = args
        
        // 设置环境变量，防止 brew 报错
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        // 尝试修复路径问题
        if let path = env["PATH"] {
             env["PATH"] = path + ":/opt/homebrew/bin:/usr/local/bin"
        } else {
             env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        }
        task.environment = env
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe // 合并 stderr，以便捕获错误信息
        
        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: BrewError.commandFailed(output))
                }
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
