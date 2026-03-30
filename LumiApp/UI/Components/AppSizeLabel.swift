import SwiftUI

// MARK: - AppSizeLabel

/// 文件/内存大小格式化标签
///
/// 自动使用 ByteCountFormatter 格式化字节数，支持不同的显示风格。
/// 用于替代分散在 6+ 处的 `ByteCountFormatter.string(fromByteCount:...)` 重复调用。
///
/// ## 使用示例
/// ```swift
/// AppSizeLabel(bytes: 1024)
/// // 输出: "1 KB"
///
/// AppSizeLabel(bytes: 1536000, style: .memory)
/// // 输出: "1.5 MB"
///
/// AppSizeLabel(bytes: file.size, style: .file)
/// // 输出: "1.54 MB"
/// ```
struct AppSizeLabel: View {
    let bytes: Int64
    let style: ByteCountFormatter.CountStyle

    /// 默认初始化
    init(bytes: Int64, style: ByteCountFormatter.CountStyle = .file) {
        self.bytes = bytes
        self.style = style
    }

    var body: some View {
        Text(formattedSize)
            .font(AppUI.Typography.caption1)
            .foregroundColor(AppUI.Color.semantic.textSecondary)
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: style)
    }
}

// MARK: - ByteCountFormatter Extension

public extension ByteCountFormatter {
    /// 格式化字节数
    static func format(_ bytes: Int64, style: CountStyle = .file) -> String {
        string(fromByteCount: bytes, countStyle: style)
    }
}

// MARK: - Preview

#Preview("AppSizeLabel") {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("小文件:")
            AppSizeLabel(bytes: 1024)
        }
        
        HStack {
            Text("中等文件:")
            AppSizeLabel(bytes: 15 * 1024 * 1024)
        }
        
        HStack {
            Text("大文件:")
            AppSizeLabel(bytes: 2 * 1024 * 1024 * 1024)
        }
        
        HStack {
            Text("内存:")
            AppSizeLabel(bytes: 8 * 1024 * 1024 * 1024, style: .memory)
        }
    }
    .padding()
    .frame(width: 300)
    .background(AppUI.Color.basePalette.deepBackground)
}