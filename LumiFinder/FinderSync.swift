import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync, SuperLog {
    static let emoji = "🧩"
    static let verbose = true

    static let logger = Logger(subsystem: "com.coffic.lumi", category: "finder")

    let myFolderURL = URL(fileURLWithPath: "/Users")
    let appGroupId = "group.com.coffic.lumi"
    let configKey = "RClickConfig"

    /// 缓存模板列表，用于通过 tag 索引（representedObject 在 Extension 中不可靠）
    var cachedTemplates: [NewFileTemplate] = []

    private enum ConfigLoadReason: String {
        case appGroupMissing = "app_group_missing"
        case configNotFound = "config_not_found"
        case decodeFailed = "decode_failed"
        case invalidConfig = "invalid_config"
        case loaded = "loaded"
    }

    override init() {
        super.init()

        if Self.verbose {
            FinderSync.logger.info("\(self.t)从路径启动: \(Bundle.main.bundlePath)")
        }

        // Set up the directory we are syncing.
        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]

        // Set up images for our badge identifiers. For demonstration purposes, this is just one image.
        /*
         if let ep = Bundle(for: type(of: self)).path(forResource: "badge", ofType: "png") {
             let image = NSImage(contentsOfFile: ep)
             FIFinderSyncController.default().setBadgeImage(image!, label: "Status One", forBadgeIdentifier: "One")
         }
         */
    }

    // MARK: - Menu and Toolbar Item Support

    override var toolbarItemName: String {
        return "LumiFinder"
    }

    override var toolbarItemToolTip: String {
        return "Lumi Finder Extension: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil)!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        if Self.verbose {
            FinderSync.logger.info("\(self.t)菜单调用，类型: \(menuKind.rawValue)")
        }

        // Produce a menu for the extension.
        let menu = NSMenu(title: "Lumi")
        let loadResult = loadConfig()
        let config = loadResult.config

        if Self.verbose {
            FinderSync.logger.info("\(self.t)配置加载结果: \(loadResult.reason.rawValue)，菜单项: \(config.items.count)")
        }

        let items = config.items.filter { $0.isEnabled }

        if Self.verbose {
            FinderSync.logger.info("\(self.t)生成菜单，共 \(items.count) 个启用的菜单项")
        }

        // Only show separator if we have items
        if !items.isEmpty {
            // menu.addItem(NSMenuItem.separator()) // Finder usually adds separator for us
        }

        // Check macOS version for icon support
        let showIcons = SystemUtil.isMacOSVersion(atLeast: 11)

        if Self.verbose {
            FinderSync.logger.info("\(self.t)图标显示: \(showIcons) (要求 macOS 11.0+，当前: \(SystemUtil.macOSVersionString()))")
        }

        func menuIcon(_ name: String) -> NSImage? {
            let appearanceMatch = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            let currentMatch = NSAppearance.current.bestMatch(from: [.darkAqua, .aqua])
            let isDark = appearanceMatch == .darkAqua || currentMatch == .darkAqua || (UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String == "Dark")
            let color = isDark ? NSColor.white : NSColor.black
            guard let symbolImage = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
                return nil
            }
            let config = NSImage.SymbolConfiguration(paletteColors: [color])
            let colored = symbolImage.withSymbolConfiguration(config) ?? symbolImage
            colored.isTemplate = false
            return colored
        }

        for item in items {
            switch item.type {
            case .openInVSCode:
                let vscodeItem = menu.addItem(withTitle: item.customTitle ?? "在 VS Code 中打开", action: #selector(openInVSCode(_:)), keyEquivalent: "")
                if showIcons {
                    vscodeItem.image = menuIcon("chevron.left.forwardslash.chevron.right")
                }

            case .openInTerminal:
                let termItem = menu.addItem(withTitle: item.customTitle ?? "在终端中打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
                if showIcons {
                    termItem.image = menuIcon("apple.terminal")
                }

            case .copyPath:
                let copyPathItem = menu.addItem(withTitle: item.customTitle ?? "复制路径", action: #selector(copyPath(_:)), keyEquivalent: "")
                if showIcons {
                    copyPathItem.image = menuIcon("doc.on.doc")
                }

            case .newFile:
                let newFileItem = menu.addItem(withTitle: item.customTitle ?? "新建文件", action: nil, keyEquivalent: "")
                if showIcons {
                    newFileItem.image = menuIcon("doc.badge.plus")
                }

                let newFileMenu = NSMenu(title: "New File")
                newFileItem.submenu = newFileMenu

                let templates = (config.fileTemplates ?? defaultTemplates()).filter { $0.isEnabled }

                // 缓存模板，通过 tag 索引
                self.cachedTemplates = templates

                for (index, template) in templates.enumerated() {
                    let tItem = newFileMenu.addItem(withTitle: "\(template.name) (.\(template.extensionName))", action: #selector(createNewFileFromTemplate(_:)), keyEquivalent: "")
                    tItem.tag = index
                    if showIcons {
                        tItem.image = menuIcon("doc.text")
                    }
                }

            case .deleteFile:
                let deleteItem = menu.addItem(withTitle: item.customTitle ?? "删除文件", action: #selector(deleteFile(_:)), keyEquivalent: "")
                if showIcons {
                    deleteItem.image = menuIcon("trash")
                }

            case .hideFile:
                let hideItem = menu.addItem(withTitle: item.customTitle ?? "隐藏文件", action: #selector(hideFile(_:)), keyEquivalent: "")
                if showIcons {
                    hideItem.image = menuIcon("eye.slash")
                }

            case .showHiddenFiles:
                let showHiddenFilesItem = menu.addItem(withTitle: item.customTitle ?? "显示隐藏文件", action: #selector(showHiddenFiles(_:)), keyEquivalent: "")
                if showIcons {
                    showHiddenFilesItem.image = menuIcon("eye")
                }
            }
        }

        return menu
    }

    // MARK: - Helpers

    private func loadConfig() -> (config: RClickConfig, reason: ConfigLoadReason) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            if Self.verbose {
                FinderSync.logger.warning("\(self.t)无法访问 UserDefaults，suite: \(self.appGroupId)")
            }
            return (defaultConfig(), .appGroupMissing)
        }

        guard let data = defaults.data(forKey: configKey) else {
            if Self.verbose {
                FinderSync.logger.warning("\(self.t)未找到配置数据，key: \(self.configKey)")
            }
            return (defaultConfig(), .configNotFound)
        }

        do {
            let decoded = try JSONDecoder().decode(RClickConfig.self, from: data)
            let sanitized = sanitize(config: decoded)
            let reason: ConfigLoadReason = sanitized.items.isEmpty ? .invalidConfig : .loaded
            return (sanitized.items.isEmpty ? defaultConfig() : sanitized, reason)
        } catch {
            if Self.verbose {
                FinderSync.logger.error("\(self.t)配置解析失败: \(error.localizedDescription)")
            }
            return (defaultConfig(), .decodeFailed)
        }
    }

    func getSelectedURLs() -> [URL]? {
        let items = FIFinderSyncController.default().selectedItemURLs()
        if Self.verbose {
            FinderSync.logger.info("\(self.t)获取选中 URL: 找到 \(items?.count ?? 0) 项")
        }
        return items
    }

    func getCurrentDirectoryURL() -> URL? {
        let url = FIFinderSyncController.default().targetedURL()
        if Self.verbose {
            FinderSync.logger.info("\(self.t)获取当前目录 URL: \(url?.path ?? "nil")")
        }
        return url
    }

    func isDirectory(_ url: URL) -> Bool {
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    func openURLs(_ urls: [URL], withAppBundleIdentifier bundleId: String) {
        if Self.verbose {
            FinderSync.logger.info("\(self.t)打开 URL，数量: \(urls.count)，bundle: \(bundleId)")
        }

        guard !urls.isEmpty else {
            if Self.verbose {
                FinderSync.logger.warning("\(self.t)openURLs 收到空 URL 列表，已跳过")
            }
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            if Self.verbose {
                FinderSync.logger.warning("\(self.t)未找到 bundle ID 对应的应用: \(bundleId)")
            }
            return
        }

        if Self.verbose {
            FinderSync.logger.info("\(self.t)找到应用 URL: \(appURL.path)")
        }

        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                if Self.verbose {
                    FinderSync.logger.error("\(self.t)打开 URL 失败: \(error.localizedDescription)")
                }
            } else {
                if Self.verbose {
                    FinderSync.logger.info("\(self.t)成功请求打开")
                }
            }
        }
    }

    func createNewFile(extension ext: String, content: String, namePrefix: String) {
        guard let target = getCurrentDirectoryURL() else {
            if Self.verbose {
                FinderSync.logger.warning("\(self.t)创建文件失败 - 没有目标目录")
            }
            return
        }

        let safePrefix = sanitizeFileName(namePrefix)
        let safeExt = sanitizeExtension(ext)
        var filename = "\(safePrefix).\(safeExt)"
        var fileURL = target.appendingPathComponent(filename)
        var counter = 1

        while FileManager.default.fileExists(atPath: fileURL.path) {
            filename = "\(safePrefix) \(counter).\(safeExt)"
            fileURL = target.appendingPathComponent(filename)
            counter += 1
        }

        if Self.verbose {
            FinderSync.logger.info("\(self.t)尝试写入文件: \(fileURL.path)")
        }

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            if Self.verbose {
                FinderSync.logger.info("\(self.t)文件创建成功")
            }
        } catch {
            if Self.verbose {
                FinderSync.logger.error("\(self.t)文件创建失败: \(error.localizedDescription)")
            }
        }
    }

    private func sanitize(config: RClickConfig) -> RClickConfig {
        let items = config.items.enumerated().map { index, item in
            var normalized = item
            if normalized.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                normalized.id = "menu-\(index)"
            }
            return normalized
        }

        let templates: [NewFileTemplate]? = config.fileTemplates?.compactMap { template in
            guard template.isEnabled else { return template }

            let ext = sanitizeExtension(template.extensionName)
            let name = sanitizeFileName(template.name)
            guard !name.isEmpty, !ext.isEmpty else { return nil }

            var normalized = template
            normalized.name = name
            normalized.extensionName = ext
            return normalized
        }

        return RClickConfig(items: items, fileTemplates: templates)
    }

    private func defaultTemplates() -> [NewFileTemplate] {
        [
            NewFileTemplate(id: "t1", name: "文本文档", extensionName: "txt", content: "", isEnabled: true),
            NewFileTemplate(id: "t2", name: "Markdown", extensionName: "md", content: "", isEnabled: true)
        ]
    }

    private func defaultConfig() -> RClickConfig {
        RClickConfig(
            items: [
                RClickMenuItem(id: "1", type: .openInVSCode, isEnabled: true),
                RClickMenuItem(id: "2", type: .openInTerminal, isEnabled: true),
                RClickMenuItem(id: "3", type: .copyPath, isEnabled: true),
                RClickMenuItem(id: "4", type: .newFile, isEnabled: true)
            ],
            fileTemplates: defaultTemplates()
        )
    }

    private func sanitizeExtension(_ ext: String) -> String {
        let stripped = ext
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
        let allowed = stripped.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
        let value = String(String.UnicodeScalarView(allowed))
        return value.isEmpty ? "txt" : value
    }

    private func sanitizeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cleaned.isEmpty ? "新建文件" : cleaned
    }
}
