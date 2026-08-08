import Cocoa
import FinderSync
import os
import SuperLogKit

extension FinderSync {
    // MARK: - Actions

    @IBAction nonisolated func openInVSCode(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performOpenInVSCode(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performOpenInVSCode(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「在 VS Code 中打开」操作")
            }
        }
        guard let items = getSelectedURLs() else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)未获取到选中项")
                }
            }
            return
        }
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)选中项数量: \(items.count)")
            }
        }

        let urlsToOpen = items.isEmpty ? [getCurrentDirectoryURL()].compactMap { $0 } : items

        guard !urlsToOpen.isEmpty else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)没有可打开的目标路径")
                }
            }
            return
        }

        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)待打开 URL 数量: \(urlsToOpen.count)")
            }
        }
        if Self.verbose, let first = urlsToOpen.first {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)首个 URL 路径: \(first.path)")
            }
        }

        openURLs(urlsToOpen, withAppBundleIdentifier: "com.microsoft.VSCode")
    }

    @IBAction nonisolated func openInTerminal(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performOpenInTerminal(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performOpenInTerminal(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「在终端中打开」操作")
            }
        }
        let items = getSelectedURLs() ?? []
        let folders = items.filter { isDirectory($0) }

        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)选中项: \(items.count)，文件夹: \(folders.count)")
            }
        }

        if !folders.isEmpty {
            openURLs(folders, withAppBundleIdentifier: "com.apple.Terminal")
        } else if let target = getCurrentDirectoryURL() {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.info("\(self.t)打开当前目录: \(target.path)")
                }
            }
            openURLs([target], withAppBundleIdentifier: "com.apple.Terminal")
        } else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)未找到目标目录")
                }
            }
        }
    }

    /// Finder invokes menu actions through an XPC callback queue, not necessarily
    /// the main actor. Keep the exported selector nonisolated and hop before
    /// touching AppKit or the FinderSync controller.
    @IBAction nonisolated func createNewFileFromTemplate(_ sender: AnyObject?) {
        performSelector(
            onMainThread: #selector(performCreateNewFileFromTemplate(_:)),
            with: sender,
            waitUntilDone: false
        )
    }

    @objc @MainActor
    private func performCreateNewFileFromTemplate(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「从模板新建文件」操作")
            }
        }
        guard let item = sender as? NSMenuItem else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)sender 不是 NSMenuItem 类型")
                }
            }
            return
        }

        let index = item.tag
        guard index >= 0, index < cachedTemplates.count else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)模板索引无效: \(index)，缓存数量: \(self.cachedTemplates.count)")
                }
            }
            return
        }

        let template = cachedTemplates[index]

        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)创建文件 - 名称: \(template.name), 扩展名: \(template.extensionName)")
            }
        }
        createNewFile(
            extension: template.extensionName,
            content: template.content,
            namePrefix: template.name,
            targetURL: cachedNewFileTargetURL
        )
    }

    @IBAction nonisolated func copyPath(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performCopyPath(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performCopyPath(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「复制路径」操作")
            }
        }
        let items = getSelectedURLs() ?? []
        let urlsToCopy = items.isEmpty ? [getCurrentDirectoryURL()].compactMap { $0 } : items

        guard !urlsToCopy.isEmpty else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)没有可复制的 URL")
                }
            }
            return
        }

        let paths = urlsToCopy.map { $0.path }
        let stringToCopy = paths.joined(separator: "\n")

        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)复制到剪贴板: \(stringToCopy)")
            }
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(stringToCopy, forType: .string)
    }

    @IBAction nonisolated func deleteFile(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performDeleteFile(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performDeleteFile(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「删除文件」操作")
            }
        }
        let items = cachedSelectedURLs.isEmpty ? (getSelectedURLs() ?? []) : cachedSelectedURLs
        guard !items.isEmpty else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)没有选中要删除的项")
                }
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = String(localized: "Confirm Move to Trash", table: "FinderSync")
        alert.informativeText = items.count == 1
            ? String(format: String(localized: "Move \"%@\" to Trash?", table: "FinderSync"), items[0].lastPathComponent)
            : String(format: String(localized: "Move %d items to Trash?", table: "FinderSync"), items.count)
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Move to Trash", table: "FinderSync"))
        alert.addButton(withTitle: String(localized: "Cancel", table: "FinderSync"))

        guard alert.runModal() == .alertFirstButtonReturn else {
            if Self.verbose { FinderSync.logger.info("\(self.t)用户取消删除") }
            return
        }

        for url in items {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                if Self.verbose {
                    if FinderSync.verbose {
                        FinderSync.logger.info("\(self.t)已移至废纸篓: \(url.path)")
                    }
                }
            } catch {
                if Self.verbose {
                    if FinderSync.verbose {
                        FinderSync.logger.error("\(self.t)移至废纸篓失败: \(url.path)，错误: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    @IBAction nonisolated func hideFile(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performHideFile(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performHideFile(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「隐藏文件」操作")
            }
        }
        let items = cachedSelectedURLs.isEmpty ? (getSelectedURLs() ?? []) : cachedSelectedURLs
        guard !items.isEmpty else {
            if Self.verbose {
                if FinderSync.verbose {
                    FinderSync.logger.warning("\(self.t)没有选中要隐藏的项")
                }
            }
            return
        }

        for url in items {
            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = true
                var mutableURL = url
                try mutableURL.setResourceValues(resourceValues)
                let isHidden = try mutableURL.resourceValues(forKeys: [.isHiddenKey]).isHidden == true
                if Self.verbose {
                    if FinderSync.verbose {
                        FinderSync.logger.info("\(self.t)已隐藏: \(url.path)，属性确认: \(isHidden)")
                    }
                }
            } catch {
                if Self.verbose {
                    if FinderSync.verbose {
                        FinderSync.logger.error("\(self.t)隐藏失败: \(url.path)，错误: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    @IBAction nonisolated func unhideFile(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performUnhideFile(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performUnhideFile(_ sender: AnyObject?) {
        if Self.verbose {
            FinderSync.logger.info("\(self.t)触发「取消隐藏文件」操作")
        }

        let items = cachedSelectedURLs.isEmpty ? (getSelectedURLs() ?? []) : cachedSelectedURLs
        guard !items.isEmpty else {
            if Self.verbose {
                FinderSync.logger.warning("\(self.t)没有选中要取消隐藏的项")
            }
            return
        }

        for url in items {
            do {
                var resourceValues = URLResourceValues()
                resourceValues.isHidden = false
                var mutableURL = url
                try mutableURL.setResourceValues(resourceValues)
                if Self.verbose {
                    FinderSync.logger.info("\(self.t)已取消隐藏: \(url.path)")
                }
            } catch {
                if Self.verbose {
                    FinderSync.logger.error("\(self.t)取消隐藏失败: \(url.path)，错误: \(error.localizedDescription)")
                }
            }
        }
    }

    @IBAction nonisolated func showHiddenFiles(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performShowHiddenFiles(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performShowHiddenFiles(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「显示隐藏文件」操作")
            }
        }
        setFinderShowsHiddenFiles(true)
    }

    @IBAction nonisolated func hideHiddenFiles(_ sender: AnyObject?) {
        performSelector(onMainThread: #selector(performHideHiddenFiles(_:)), with: sender, waitUntilDone: false)
    }

    @objc @MainActor
    private func performHideHiddenFiles(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                FinderSync.logger.info("\(self.t)触发「不显示隐藏文件」操作")
            }
        }
        setFinderShowsHiddenFiles(false)
    }

    @MainActor
    private func setFinderShowsHiddenFiles(_ showHiddenFiles: Bool) {
        guard let url = URL(string: "lumi://finder/show-hidden?value=\(showHiddenFiles ? "true" : "false")") else {
            FinderSync.logger.error("\(self.t)无法生成 Finder 隐藏文件显示请求")
            return
        }

        guard NSWorkspace.shared.open(url) else {
            FinderSync.logger.error("\(self.t)无法请求 Lumi 主应用更新 Finder 隐藏文件显示设置")
            return
        }
        if Self.verbose {
            FinderSync.logger.info("\(self.t)已请求 Lumi 主应用更新 Finder 隐藏文件显示设置: \(showHiddenFiles)")
        }
    }
}
