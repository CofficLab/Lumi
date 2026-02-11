import Cocoa
import FinderSync
import OSLog

extension FinderSync {
    
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

        let index = item.tag
        guard index >= 0, index < cachedTemplates.count else {
            if Self.verbose {
                os_log("\(Self.t)模板索引无效: \(index)，缓存数量: \(self.cachedTemplates.count)")
            }
            return
        }

        let template = cachedTemplates[index]

        if Self.verbose {
            os_log("\(Self.t)创建文件 - 名称: \(template.name), 扩展名: \(template.extensionName)")
        }
        createNewFile(extension: template.extensionName, content: template.content, namePrefix: template.name)
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

    @IBAction func showHiddenFiles(_ sender: AnyObject?) {
        if Self.verbose {
            os_log("\(Self.t)触发「显示隐藏文件」操作")
        }
        guard let currentDir = getCurrentDirectoryURL() else {
            if Self.verbose {
                os_log("\(Self.t)未获取到当前目录")
            }
            return
        }

        // 使用 AppleScript 来显示隐藏文件
        let script = """
        tell application "Finder"
            if (count of windows) > 0 then
                set folderPath to "\(currentDir.path)" as alias
                set every file of folderPath whose name starts with "." to visible
            end if
        end tell
        """

        if Self.verbose {
            os_log("\(Self.t)执行 AppleScript 显示隐藏文件")
        }

        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)

        if let error = error {
            if Self.verbose {
                os_log("\(Self.t)执行 AppleScript 失败: \(error)")
            }
        } else {
            if Self.verbose {
                os_log("\(Self.t)成功显示隐藏文件")
            }
        }
    }
}
