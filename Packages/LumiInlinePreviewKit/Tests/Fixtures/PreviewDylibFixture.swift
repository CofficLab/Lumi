// MARK: - PreviewDylibFixture
//
// 最小化的"用户预览 dylib"源文件，仅用于手动验证 `Load Dylib…` 路径。
// 编译方法（在仓库根目录执行）：
//
//     SDK=$(xcrun --show-sdk-path --sdk macosx)
//     swiftc \
//       -emit-library \
//       -O \
//       -module-name PreviewDylibFixture \
//       -sdk "$SDK" \
//       -target arm64-apple-macosx14.0 \
//       -o /tmp/PreviewDylibFixture.dylib \
//       Packages/LumiInlinePreviewKit/Tests/Fixtures/PreviewDylibFixture.swift
//
// 然后在 Lumi 中点 "Start Stream" → "Load Dylib…" 选择 `/tmp/PreviewDylibFixture.dylib`，
// 应当看到一个青色背景上跳动黄色圆点的视图。
//
// 符号约定：`@_cdecl("lumi_preview_make_nsview") () -> UnsafeMutableRawPointer?`
// 返回 `Unmanaged.passRetained(rootView).toOpaque()`，由子进程 `takeRetainedValue()` 接管所有权。

import AppKit
import SwiftUI

private struct FixtureRoot: View {
    var body: some View {
        TimelineView(.animation) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Color(nsColor: .systemTeal).opacity(0.6)

                Circle()
                    .fill(Color.yellow)
                    .frame(width: 60, height: 60)
                    .offset(
                        x: CGFloat(sin(phase * 1.6)) * 80,
                        y: CGFloat(cos(phase * 1.6)) * 60
                    )

                VStack(spacing: 6) {
                    Text("PreviewDylibFixture")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Loaded via dlopen at \(Int(phase) % 1000)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .monospacedDigit()
                }
                .padding(8)
                .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

@_cdecl("lumi_preview_make_nsview")
public func lumi_preview_make_nsview() -> UnsafeMutableRawPointer? {
    let view = NSHostingView(rootView: FixtureRoot())
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
    return Unmanaged.passRetained(view).toOpaque()
}
