# Issue #2: FinderSync 删除操作无确认机制

**严重程度**: 🔴 Critical  
**状态**: Open  
**文件**: `LumiFinder/FinderSync+Actions.swift`

---

## 问题描述

`deleteFile` 方法直接将文件移至废纸篓，没有任何用户确认步骤，可能导致用户误操作删除重要文件。

## 当前代码

```swift
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
            // 错误处理...
        }
    }
}
```

## 问题分析

1. **无确认对话框**: 用户点击菜单项后直接执行删除
2. **无撤销机制**: 虽然移至废纸篓，但用户可能未注意到删除操作
3. **批量删除风险**: 选中多个文件时会一并删除，无二次确认

## 建议修复

1. 添加 NSAlert 确认对话框，显示即将删除的文件列表
2. 考虑添加"移到废纸篓"的二次确认
3. 对于批量操作，显示文件数量并要求确认

## 示例修复代码

```swift
@IBAction func deleteFile(_ sender: AnyObject?) {
    guard let items = getSelectedURLs(), !items.isEmpty else { return }
    
    let alert = NSAlert()
    alert.messageText = "确认删除"
    alert.informativeText = "确定要将 \(items.count) 个项目移到废纸篓吗？"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "移到废纸篓")
    alert.addButton(withTitle: "取消")
    
    if alert.runModal() == .alertFirstButtonReturn {
        for url in items {
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
}
```

## 修复优先级

高 - 用户误操作可能导致数据丢失