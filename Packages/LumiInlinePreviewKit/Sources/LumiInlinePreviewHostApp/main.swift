import AppKit
import Foundation

// Phase 2 子进程入口。
//
// 启动步骤：
// 1. 创建 NSApplication（accessory 策略：不显示在 dock）。
// 2. 安装 stdio 主控，监听 stdin 行协议、按需启动渲染循环。
// 3. 进入主 run loop，持续渲染并通过 stdout 推送帧事件。
// 4. stdin EOF → 主控触发 `NSApplication.terminate(nil)`。

NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.finishLaunching()

let host = HotStdioPreviewHost()
host.start()

NSApplication.shared.run()
