import Cocoa
import FinderSync
import os
import SuperLogKit

extension FinderSync {
    
    // MARK: - Actions

    @IBAction func openInVSCode(_ sender: AnyObject?) {
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

    @IBAction func openInTerminal(_ sender: AnyObject?) {
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

    @IBAction func createNewFileFromTemplate(_ sender: AnyObject?) {
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
        createNewFile(extension: template.extensionName, content: template.content, namePrefix: template.name)
    }

    @IBAction func copyPath(_ sender: AnyObject?) {
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

    @IBAction func deleteFile(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                            FinderSync.logger.info("\(self.t)触发「删除文件」操作")
            }
        }
        guard let items = getSelectedURLs(), !items.isEmpty else {
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

    @IBAction func hideFile(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                            FinderSync.logger.info("\(self.t)触发「隐藏文件」操作")
            }
        }
        guard let items = getSelectedURLs(), !items.isEmpty else {
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
                if Self.verbose {
                    if FinderSync.verbose {
                                            FinderSync.logger.info("\(self.t)已隐藏: \(url.path)")
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

    @IBAction func showHiddenFiles(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                            FinderSync.logger.info("\(self.t)触发「显示隐藏文件」操作")
            }
        }
        guard let currentDir = getCurrentDirectoryURL() else {
            if Self.verbose {
                if FinderSync.verbose {
                                    FinderSync.logger.warning("\(self.t)未获取到当前目录")
                }
            }
            return
        }

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: [.isHiddenKey, .isDirectoryKey],
                options: [.skipsSubdirectoryDescendants]
            )

            var revealedCount = 0

            for url in urls where url.lastPathComponent.hasPrefix(".") {
                do {
                    var resourceValues = URLResourceValues()
                    resourceValues.isHidden = false
                    var mutableURL = url
                    try mutableURL.setResourceValues(resourceValues)
                    revealedCount += 1
                } catch {
                    if Self.verbose {
                        if FinderSync.verbose {
                                                    FinderSync.logger.error("\(self.t)取消隐藏失败: \(url.path)，错误: \(error.localizedDescription)")
                        }
                    }
                }
            }

            if Self.verbose {
                if FinderSync.verbose {
                                    FinderSync.logger.info("\(self.t)成功取消隐藏 \(revealedCount) 个以 . 开头的项目")
                }
            }
        } catch {
            if Self.verbose {
                if FinderSync.verbose {
                                    FinderSync.logger.error("\(self.t)读取目录失败: \(currentDir.path)，错误: \(error.localizedDescription)")
                }
            }
        }
    }

    @IBAction func listHiddenFiles(_ sender: AnyObject?) {
        if Self.verbose {
            if FinderSync.verbose {
                            FinderSync.logger.info("\(self.t)触发「列出隐藏文件」操作")
            }
        }
        guard let currentDir = getCurrentDirectoryURL() else {
            if Self.verbose {
                if FinderSync.verbose {
                                    FinderSync.logger.warning("\(self.t)未获取到当前目录")
                }
            }
            return
        }

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: [.isHiddenKey],
                options: [.skipsSubdirectoryDescendants]
            )

            let hiddenItems = urls.filter { url in
                (try? url.resourceValues(forKeys: [.isHiddenKey]))?.isHidden == true
            }

            if Self.verbose {
                if FinderSync.verbose {
                                    FinderSync.logger.info("\(self.t)在当前目录中找到 \(hiddenItems.count) 个隐藏文件")
                }
            }

            // 在主线程显示对话框
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = String(localized: "Hidden Files", table: "FinderSync")

                if hiddenItems.isEmpty {
                    alert.informativeText = String(format: String(localized: "No hidden files found in:\n%@", table: "FinderSync"), currentDir.path)
                    alert.addButton(withTitle: String(localized: "OK", table: "FinderSync"))
                } else {
                    let fileNames = hiddenItems.map { $0.lastPathComponent }.sorted()
                    let fileList = fileNames.joined(separator: "\n")

                    alert.informativeText = String(format: String(localized: "Found %d hidden file(s) in:\n%@\n\n%@", table: "FinderSync"), hiddenItems.count, currentDir.path, fileList)
                    alert.addButton(withTitle: String(localized: "OK", table: "FinderSync"))
                }

                alert.alertStyle = .informational
                alert.runModal()
            }
        } catch {
            if Self.verbose {
                if FinderSync.verbose {
                                    FinderSync.logger.error("\(self.t)读取目录失败: \(currentDir.path)，错误: \(error.localizedDescription)")
                }
            }

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = String(localized: "Error", table: "FinderSync")
                alert.informativeText = String(format: String(localized: "Failed to read directory:\n%@", table: "FinderSync"), currentDir.path)
                alert.alertStyle = .critical
                alert.addButton(withTitle: String(localized: "OK", table: "FinderSync"))
                alert.runModal()
            }
        }
    }
}
