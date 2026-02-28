import Cocoa
import FinderSync
import OSLog

class FinderSync: FIFinderSync, SuperLog {
    static let emoji = "🧩"
    static let verbose = true

    let myFolderURL = URL(fileURLWithPath: "/Users")
    let appGroupId = "group.com.coffic.lumi"
    let configKey = "RClickConfig"

    /// 缓存模板列表，用于通过 tag 索引（representedObject 在 Extension 中不可靠）
    var cachedTemplates: [NewFileTemplate] = []

    override init() {
        super.init()

        if Self.verbose {
            os_log("\(Self.t)从路径启动: \(Bundle.main.bundlePath)")
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
            os_log("\(Self.t)菜单调用，类型: \(menuKind.rawValue)")
        }

        // Produce a menu for the extension.
        let menu = NSMenu(title: "Lumi")
        let config = loadConfig()

        if let config = config {
            if Self.verbose {
                os_log("\(Self.t)配置已加载，包含 \(config.items.count) 个菜单项")
            }
        } else {
            if Self.verbose {
                os_log("\(Self.t)配置加载失败或为空，使用默认配置")
            }
        }

        // Default items if config is missing or load failed
        let items = config?.items.filter { $0.isEnabled } ?? [
            RClickMenuItem(id: "1", type: .openInVSCode, isEnabled: true),
            RClickMenuItem(id: "2", type: .openInTerminal, isEnabled: true),
            RClickMenuItem(id: "3", type: .copyPath, isEnabled: true),
            RClickMenuItem(id: "4", type: .newFile, isEnabled: true),
        ]

        if Self.verbose {
            os_log("\(Self.t)生成菜单，共 \(items.count) 个启用的菜单项")
        }

        // Only show separator if we have items
        if !items.isEmpty {
            // menu.addItem(NSMenuItem.separator()) // Finder usually adds separator for us
        }

        // Check macOS version for icon support
        let showIcons = SystemUtil.isMacOSVersion(atLeast: 11)

        if Self.verbose {
            os_log("\(Self.t)图标显示: \(showIcons) (要求 macOS 11.0+，当前: \(SystemUtil.macOSVersionString()))")
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

                let templates = config?.fileTemplates?.filter { $0.isEnabled } ?? [
                    NewFileTemplate(id: "t1", name: "文本文档", extensionName: "txt", content: "", isEnabled: true),
                    NewFileTemplate(id: "t2", name: "Markdown", extensionName: "md", content: "", isEnabled: true),
                ]

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

    private func loadConfig() -> RClickConfig? {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            if Self.verbose {
                os_log("\(Self.t)无法访问 UserDefaults，suite: \(self.appGroupId)")
            }
            return nil
        }

        guard let data = defaults.data(forKey: configKey) else {
            if Self.verbose {
                os_log("\(Self.t)未找到配置数据，key: \(self.configKey)")
            }
            return nil
        }

        do {
            return try JSONDecoder().decode(RClickConfig.self, from: data)
        } catch {
            if Self.verbose {
                os_log("\(Self.t)配置解析失败: \(error.localizedDescription)")
            }
            return nil
        }
    }

    func getSelectedURLs() -> [URL]? {
        let items = FIFinderSyncController.default().selectedItemURLs()
        if Self.verbose {
            os_log("\(Self.t)获取选中 URL: 找到 \(items?.count ?? 0) 项")
        }
        return items
    }

    func getCurrentDirectoryURL() -> URL? {
        let url = FIFinderSyncController.default().targetedURL()
        if Self.verbose {
            os_log("\(Self.t)获取当前目录 URL: \(url?.path ?? "nil")")
        }
        return url
    }

    func isDirectory(_ url: URL) -> Bool {
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    func openURLs(_ urls: [URL], withAppBundleIdentifier bundleId: String) {
        if Self.verbose {
            os_log("\(Self.t)打开 URL，数量: \(urls.count)，bundle: \(bundleId)")
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            if Self.verbose {
                os_log("\(Self.t)未找到 bundle ID 对应的应用: \(bundleId)")
            }
            return
        }

        if Self.verbose {
            os_log("\(Self.t)找到应用 URL: \(appURL.path)")
        }

        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                if Self.verbose {
                    os_log("\(Self.t)打开 URL 失败: \(error.localizedDescription)")
                }
            } else {
                if Self.verbose {
                    os_log("\(Self.t)成功请求打开")
                }
            }
        }
    }

    func createNewFile(extension ext: String, content: String, namePrefix: String) {
        guard let target = getCurrentDirectoryURL() else {
            if Self.verbose {
                os_log("\(Self.t)创建文件失败 - 没有目标目录")
            }
            return
        }

        var filename = "\(namePrefix).\(ext)"
        var fileURL = target.appendingPathComponent(filename)
        var counter = 1

        while FileManager.default.fileExists(atPath: fileURL.path) {
            filename = "\(namePrefix) \(counter).\(ext)"
            fileURL = target.appendingPathComponent(filename)
            counter += 1
        }

        if Self.verbose {
            os_log("\(Self.t)尝试写入文件: \(fileURL.path)")
        }

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            if Self.verbose {
                os_log("\(Self.t)文件创建成功")
            }
        } catch {
            if Self.verbose {
                os_log("\(Self.t)文件创建失败: \(error.localizedDescription)")
            }
        }
    }
}
