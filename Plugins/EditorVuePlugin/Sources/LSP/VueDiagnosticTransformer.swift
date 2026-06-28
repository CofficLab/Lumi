import Foundation
import LanguageServerProtocol
import os
import SuperLogKit

/// Vue 诊断坐标转换器
///
/// Volar 在混合模式下的诊断坐标通常已经对应到真实 .vue 文件，
/// 但在某些边界情况下（如虚拟文件内部错误）需要将坐标映射回来。
///
/// 本模块提供：
/// 1. 诊断位置校正（虚拟行 → 真实行）
/// 2. 诊断范围裁剪（超出区块范围的诊断过滤）
/// 3. 诊断消息增强（添加 Vue 上下文信息）
struct VueDiagnosticTransformer: Sendable, SuperLog {
    nonisolated static let emoji = "🔧"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.diagnostic-transformer"
    )

    // MARK: - 变换结果

    /// 变换后的诊断结果
    struct TransformedDiagnostic: Sendable {
        /// 原始诊断
        let original: Diagnostic

        /// 变换后的范围（如果发生了坐标调整）
        let adjustedRange: LSPRange?

        /// 所在区块类型
        let blockType: SFCBlockType?

        /// 是否需要显示（某些虚拟文件诊断应被过滤）
        let shouldDisplay: Bool

        /// 增强的消息前缀
        let contextPrefix: String?
    }

    // MARK: - 公开方法

    /// 变换 Volar 返回的诊断结果
    ///
    /// - Parameters:
    ///   - diagnostics: Volar 返回的原始诊断列表
    ///   - fileMapping: 当前 .vue 文件的虚拟映射
    /// - Returns: 变换后的诊断列表
    static func transform(
        diagnostics: [Diagnostic],
        fileMapping: VueVirtualFileMapper.FileMapping?
    ) -> [TransformedDiagnostic] {
        guard let fileMapping else {
            // 无映射信息时，直接透传所有诊断
            return diagnostics.map { original in
                TransformedDiagnostic(
                    original: original,
                    adjustedRange: nil,
                    blockType: nil,
                    shouldDisplay: true,
                    contextPrefix: nil
                )
            }
        }

        return diagnostics.compactMap { diagnostic in
            transformSingle(diagnostic, fileMapping: fileMapping)
        }
    }

    /// 判断诊断是否来自 Volar 虚拟文件而非真实文件
    ///
    /// Volar 在混合模式下通常直接报告真实文件坐标，
    /// 但如果诊断来源是虚拟文件（如 .vue.ts），需要映射回来。
    ///
    /// - Parameter uri: 诊断的 URI
    /// - Returns: 是否为虚拟文件诊断
    static func isVirtualFileDiagnostic(uri: String) -> Bool {
        // 虚拟文件模式: file:///path/to/Component.vue.ts
        // 或 file:///path/to/Component.vue.html
        // 或 file:///path/to/Component.vue.css
        return uri.hasSuffix(".vue.ts")
            || uri.hasSuffix(".vue.js")
            || uri.hasSuffix(".vue.html")
            || uri.hasSuffix(".vue.css")
            || uri.hasSuffix(".vue.scss")
            || uri.hasSuffix(".vue.less")
    }

    /// 从虚拟文件 URI 提取真实 .vue 文件 URI
    ///
    /// - Parameter virtualURI: 虚拟文件 URI
    /// - Returns: 真实 .vue 文件 URI
    static func realFileURI(from virtualURI: String) -> String {
        // file:///path/to/Component.vue.ts → file:///path/to/Component.vue
        let patterns = [".vue.ts", ".vue.js", ".vue.html", ".vue.css", ".vue.scss", ".vue.less"]
        for pattern in patterns {
            if virtualURI.hasSuffix(pattern) {
                return String(virtualURI.dropLast(pattern.count - 4)) // 保留 .vue
            }
        }
        return virtualURI
    }

    // MARK: - 私有方法

    /// 变换单条诊断
    private static func transformSingle(
        _ diagnostic: Diagnostic,
        fileMapping: VueVirtualFileMapper.FileMapping
    ) -> TransformedDiagnostic? {
        let range = diagnostic.range
        let startLine = range.start.line
        let endLine = range.end.line

        // 判断诊断所在的区块
        let blockMapping = fileMapping.blockAt(realLine: startLine)

        // 检查诊断范围是否在文件的有效区域内
        guard startLine >= 0, endLine >= startLine else {
            if EditorVuePlugin.verbose {
                logger.debug("\(Self.t)\(emoji) 诊断范围无效，过滤: start=\(startLine), end=\(endLine)")
            }
            return nil
        }

        // 确定区块上下文
        let blockType = blockMapping?.blockType

        // 检查是否需要过滤虚拟文件的冗余诊断
        let shouldDisplay = shouldDisplayDiagnostic(
            diagnostic,
            blockType: blockType,
            fileMapping: fileMapping
        )

        // 生成上下文前缀
        let contextPrefix = generateContextPrefix(
            diagnostic: diagnostic,
            blockType: blockType
        )

        // 检查是否需要调整范围
        var adjustedRange: LSPRange? = nil
        if let mapping = blockMapping {
            // 确保诊断范围不超出区块边界
            let clampedStartLine = max(startLine, mapping.realStartLine + 1)
            let clampedEndLine = min(endLine, mapping.realEndLine)

            if clampedStartLine != startLine || clampedEndLine != endLine {
                adjustedRange = LSPRange(
                    start: Position(line: clampedStartLine, character: range.start.character),
                    end: Position(line: clampedEndLine, character: range.end.character)
                )
            }
        }

        return TransformedDiagnostic(
            original: diagnostic,
            adjustedRange: adjustedRange,
            blockType: blockType,
            shouldDisplay: shouldDisplay,
            contextPrefix: contextPrefix
        )
    }

    /// 判断诊断是否应该显示
    private static func shouldDisplayDiagnostic(
        _ diagnostic: Diagnostic,
        blockType: SFCBlockType?,
        fileMapping: VueVirtualFileMapper.FileMapping
    ) -> Bool {
        // 始终显示错误和警告
        switch diagnostic.severity {
        case .error, .warning:
            return true
        case .information, .hint, nil:
            break
        }

        // 过滤一些已知的虚拟文件噪声
        let message = diagnostic.message.lowercased()

        // Volar 有时会报告虚拟注入代码的错误，这些不应显示给用户
        let virtualNoisePatterns = [
            "cannot find name '__VLS_",           // Volar 内部变量
            "property '__VLS_",                   // Volar 内部属性
            "type '__VLS_",                       // Volar 内部类型
            "is not assignable to type '__VLS_",  // Volar 类型断言
        ]

        for pattern in virtualNoisePatterns {
            if message.contains(pattern.lowercased()) {
                return false
            }
        }

        return true
    }

    /// 生成诊断的上下文前缀
    private static func generateContextPrefix(
        diagnostic: Diagnostic,
        blockType: SFCBlockType?
    ) -> String? {
        guard let blockType else { return nil }

        let blockName: String
        switch blockType {
        case .template: blockName = "template"
        case .script: blockName = "script"
        case .style: blockName = "style"
        }

        // 仅对某些特定类型的诊断添加上下文
        let message = diagnostic.message.lowercased()

        // 如果诊断消息本身已经包含区块信息，不再重复
        if message.contains("template") || message.contains("script") || message.contains("style") {
            return nil
        }

        return "[\(blockName)]"
    }
}
