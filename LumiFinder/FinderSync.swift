import Cocoa
import FinderSync
import OSLog

class FinderSync: FIFinderSync, SuperLog {
    static let emoji = "🧩"
    static let verbose = true

    let myFolderURL = URL(fileURLWithPath: "/Users")
    let appGroupId = "group.com.coffic.lumi"
    let configKey = "RClickConfig"

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
        let showIcons = SystemUtil.isMacOSVersion(atLeast: 26)

        if Self.verbose {
            os_log("\(Self.t)图标显示: \(showIcons) (要求 macOS 26.0+，当前: \(SystemUtil.macOSVersionString()))")
        }

        for item in items {
            switch item.type {
            case .openInVSCode:
                let vscodeItem = menu.addItem(withTitle: item.customTitle ?? "在 VS Code 中打开", action: #selector(openInVSCode(_:)), keyEquivalent: "")
                if showIcons {
                    vscodeItem.image = NSImage(systemSymbolName: "chevron.left.forwardslash.chevron.right", accessibilityDescription: "Code")
                }

            case .openInTerminal:
                let termItem = menu.addItem(withTitle: item.customTitle ?? "在终端中打开", action: #selector(openInTerminal(_:)), keyEquivalent: "")
                if showIcons {
                    termItem.image = NSImage(systemSymbolName: "apple.terminal", accessibilityDescription: "Terminal")
                }

            case .copyPath:
                let copyPathItem = menu.addItem(withTitle: item.customTitle ?? "复制路径", action: #selector(copyPath(_:)), keyEquivalent: "")
                if showIcons {
                    copyPathItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
                }

            case .newFile:
                let newFileItem = menu.addItem(withTitle: item.customTitle ?? "新建文件", action: nil, keyEquivalent: "")
                if showIcons {
                    newFileItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "New File")
                }

                let newFileMenu = NSMenu(title: "New File")
                newFileItem.submenu = newFileMenu

                let templates = config?.fileTemplates?.filter { $0.isEnabled } ?? [
                    NewFileTemplate(id: "t1", name: "文本文档", extensionName: "txt", content: "", isEnabled: true),
                    NewFileTemplate(id: "t2", name: "Markdown", extensionName: "md", content: "", isEnabled: true),
                ]

                for template in templates {
                    let tItem = newFileMenu.addItem(withTitle: "\(template.name) (.\(template.extensionName))", action: #selector(createNewFileFromTemplate(_:)), keyEquivalent: "")
                    tItem.representedObject = ["name": template.name, "ext": template.extensionName, "content": template.content]
                    if showIcons {
                        tItem.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "File")
                    }
                }

            case .deleteFile:
                let deleteItem = menu.addItem(withTitle: item.customTitle ?? "删除文件", action: #selector(deleteFile(_:)), keyEquivalent: "")
                if showIcons {
                    deleteItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Delete")
                }

            case .hideFile:
                let hideItem = menu.addItem(withTitle: item.customTitle ?? "隐藏文件", action: #selector(hideFile(_:)), keyEquivalent: "")
                if showIcons {
                    hideItem.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Hide")
                }
            }
        }

        return menu
    }

    // MARK: - Actions

    @IBAction func openInVSCode(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「在 VS Code 中打开」操作")
        }
        guard let items = getSelectedURLs() else {
            if Self.verbose {
                os_log("\(Self.t)未获取到选中项")
            }
            return
        }
        if Self.verbose {
            os_log("\(Self.t)选中项数量: \(items.count)")
        }

        let urlsToOpen = items.isEmpty ? [getCurrentDirectoryURL()].compactMap { $0 } : items

        if Self.verbose {
            os_log("\(Self.t)待打开 URL 数量: \(urlsToOpen.count)")
        }
        if Self.verbose, let first = urlsToOpen.first {
            os_log("\(Self.t)首个 URL 路径: \(first.path)")
        }

        openURLs(urlsToOpen, withAppBundleIdentifier: "com.microsoft.VSCode")
    }

    @IBAction func openInTerminal(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「在终端中打开」操作")
        }
        let items = getSelectedURLs() ?? []
        let folders = items.filter { isDirectory($0) }

        if Self.verbose {
            os_log("\(Self.t)选中项: \(items.count)，文件夹: \(folders.count)")
        }

        if !folders.isEmpty {
            openURLs(folders, withAppBundleIdentifier: "com.apple.Terminal")
        } else if let target = getCurrentDirectoryURL() {
            if Self.verbose {
                os_log("\(Self.t)打开当前目录: \(target.path)")
            }
            openURLs([target], withAppBundleIdentifier: "com.apple.Terminal")
        } else {
            if Self.verbose {
                os_log("\(Self.t)未找到目标目录")
            }
        }
    }

    @IBAction func createNewFileFromTemplate(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「从模板新建文件」操作")
        }
        guard let item = sender as? NSMenuItem else {
            if Self.verbose {
                os_log("\(Self.t)sender 不是 NSMenuItem 类型")
            }
            return
        }

        guard let data = item.representedObject as? [String: String] else {
            if Self.verbose {
                os_log("\(Self.t)representedObject 无效或为空")
            }
            return
        }

        guard let name = data["name"],
              let ext = data["ext"],
              let content = data["content"] else {
            if Self.verbose {
                os_log("\(Self.t)representedObject 缺少数据")
            }
            return
        }

        if Self.verbose {
            os_log("\(Self.t)创建文件 - 名称: \(name), 扩展名: \(ext)")
        }
        createNewFile(extension: ext, content: content, namePrefix: name)
    }

    @IBAction func copyPath(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「复制路径」操作")
        }
        let items = getSelectedURLs() ?? []
        let urlsToCopy = items.isEmpty ? [getCurrentDirectoryURL()].compactMap { $0 } : items

        guard !urlsToCopy.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)没有可复制的 URL")
            }
            return
        }

        let paths = urlsToCopy.map { $0.path }
        let stringToCopy = paths.joined(separator: "\n")

        if Self.verbose {
            os_log("\(Self.t)复制到剪贴板: \(stringToCopy)")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(stringToCopy, forType: .string)
    }

    @IBAction func deleteFile(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「删除文件」操作")
        }
        guard let items = getSelectedURLs(), !items.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)没有选中要删除的项")
            }
            return
        }

        for url in items {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                if Self.verbose {
                    os_log("\(Self.t)已移至废纸篓: \(url.path)")
                }
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)移至废纸篓失败: \(url.path)，错误: \(error.localizedDescription)")
                }
            }
        }
    }

    @IBAction func hideFile(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「隐藏文件」操作")
        }
        guard let items = getSelectedURLs(), !items.isEmpty else {
            if Self.verbose {
                os_log("\(Self.t)没有选中要隐藏的项")
            }
            return
        }

        for url in items {
            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = true
                var mutableURL = url
                try mutableURL.setResourceValues(resourceValues)
                if Self.verbose {
                    os_log("\(Self.t)已隐藏: \(url.path)")
                }
            } catch {
                if Self.verbose {
                    os_log("\(Self.t)隐藏失败: \(url.path)，错误: \(error.localizedDescription)")
                }
            }
        }
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

    private func getSelectedURLs() -> [URL]? {
        let items = FIFinderSyncController.default().selectedItemURLs()
        if Self.verbose {
            os_log("\(Self.t)获取选中 URL: 找到 \(items?.count ?? 0) 项")
        }
        return items
    }

    private func getCurrentDirectoryURL() -> URL? {
        let url = FIFinderSyncController.default().targetedURL()
        if Self.verbose {
            os_log("\(Self.t)获取当前目录 URL: \(url?.path ?? "nil")")
        }
        return url
    }

    private func isDirectory(_ url: URL) -> Bool {
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private func openURLs(_ urls: [URL], withAppBundleIdentifier bundleId: String) {
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

    private func createNewFile(extension ext: String, content: String, namePrefix: String) {
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
