import Foundation
import os
import SuperLogKit

/// 组件重命名联动工具
///
/// 当用户重命名 `.vue` 文件时，同步更新项目中所有引用：
/// - Template 中的组件标签 `<OldName />` → `<NewName />`
/// - Script 中的 import 语句
/// - Router 配置中的引用
/// - 其他组件中的引用
///
/// 使用方式：调用 `ComponentRenamer.rename()` 执行完整的重命名流程。
struct ComponentRenamer: Sendable, SuperLog {
    nonisolated static let emoji = "✏️"
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.vue-editor.renamer"
    )

    // MARK: - 重命名计划

    /// 重命名计划
    struct RenamePlan: Sendable {
        /// 原文件路径
        let oldPath: String

        /// 新文件路径
        let newPath: String

        /// 旧组件名（PascalCase）
        let oldName: String

        /// 新组件名（PascalCase）
        let newName: String

        /// 旧 kebab-case 名
        let oldKebabName: String

        /// 新 kebab-case 名
        let newKebabName: String

        /// 需要修改的文件列表
        let affectedFiles: [AffectedFile]
    }

    /// 受影响的文件
    struct AffectedFile: Sendable {
        /// 文件路径
        let path: String

        /// 替换操作列表
        let replacements: [TextReplacement]

        /// 文件类型
        let fileType: FileType

        enum FileType: String, Sendable {
            case vue
            case typescript
            case javascript
            case router
            case other
        }
    }

    /// 文本替换操作
    struct TextReplacement: Sendable {
        /// 旧文本
        let oldText: String

        /// 新文本
        let newText: String

        /// 替换类型
        let kind: ReplacementKind

        enum ReplacementKind: String, Sendable {
            case importStatement   // import OldName from './...'
            case templateTag       // <OldName /> or <old-name />
            case componentOption   // components: { OldName }
            case routerReference   // routes: [{ component: ... }]
        }
    }

    // MARK: - 重命名结果

    /// 重命名结果
    struct RenameResult: Sendable {
        /// 是否成功
        let success: Bool

        /// 重命名的文件数（不含被重命名的组件本身）
        let filesModified: Int

        /// 总替换次数
        let totalReplacements: Int

        /// 失败的文件
        let failures: [(path: String, error: String)]
    }

    // MARK: - 计划生成

    /// 生成重命名计划（不执行实际修改）
    ///
    /// - Parameters:
    ///   - oldPath: 原组件文件路径
    ///   - newName: 新组件名（不含扩展名，如 "NewButton"）
    ///   - projectPath: 项目根目录
    /// - Returns: 重命名计划
    static func plan(
        oldPath: String,
        newName: String,
        projectPath: String
    ) -> RenamePlan {
        let oldName = URL(fileURLWithPath: oldPath)
            .deletingPathExtension()
            .lastPathComponent

        let oldDir = (oldPath as NSString).deletingLastPathComponent
        let newPath = (oldDir as NSString).appendingPathComponent(newName + ".vue")

        let oldPascal = VueProjectScanner.fileNameToComponentName(oldName)
        let newPascal = VueProjectScanner.fileNameToComponentName(newName)
        let oldKebab = VueProjectScanner.pascalToKebab(oldPascal)
        let newKebab = VueProjectScanner.pascalToKebab(newPascal)

        // 扫描项目中所有受影响的文件
        let affectedFiles = scanAffectedFiles(
            projectPath: projectPath,
            oldPascal: oldPascal,
            newPascal: newPascal,
            oldKebab: oldKebab,
            newKebab: newKebab,
            oldPath: oldPath
        )

        return RenamePlan(
            oldPath: oldPath,
            newPath: newPath,
            oldName: oldPascal,
            newName: newPascal,
            oldKebabName: oldKebab,
            newKebabName: newKebab,
            affectedFiles: affectedFiles
        )
    }

    // MARK: - 执行重命名

    /// 执行重命名计划
    ///
    /// - Parameter plan: 重命名计划
    /// - Returns: 执行结果
    static func rename(plan: RenamePlan) -> RenameResult {
        var filesModified = 0
        var totalReplacements = 0
        var failures: [(path: String, error: String)] = []

        let fm = FileManager.default

        // 1. 重命名组件文件本身
        do {
            try fm.moveItem(atPath: plan.oldPath, toPath: plan.newPath)
            if EditorVuePlugin.verbose {
                logger.info("\(Self.t)\(emoji) 重命名文件: \(plan.oldPath) → \(plan.newPath)")
            }
        } catch {
            failures.append((plan.oldPath, error.localizedDescription))
            return RenameResult(success: false, filesModified: 0, totalReplacements: 0, failures: failures)
        }

        // 2. 更新所有引用文件
        for affected in plan.affectedFiles {
            guard let fileText = try? VueTextFileIO.read(path: affected.path) else {
                failures.append((affected.path, "Cannot read file"))
                continue
            }

            let content = fileText.content
            var updated = content
            for replacement in affected.replacements {
                updated = updated.replacingOccurrences(of: replacement.oldText, with: replacement.newText)
                totalReplacements += 1
            }

            if updated != content {
                do {
                    try VueTextFileIO.write(updated, to: affected.path, encoding: fileText.encoding)
                    filesModified += 1
                    if EditorVuePlugin.verbose {
                        logger.info("\(Self.t)\(emoji) 更新引用: \(affected.path) (\(affected.replacements.count) 处)")
                    }
                } catch {
                    failures.append((affected.path, error.localizedDescription))
                }
            }
        }

        return RenameResult(
            success: failures.isEmpty,
            filesModified: filesModified,
            totalReplacements: totalReplacements,
            failures: failures
        )
    }

    // MARK: - 扫描受影响文件

    private static func scanAffectedFiles(
        projectPath: String,
        oldPascal: String,
        newPascal: String,
        oldKebab: String,
        newKebab: String,
        oldPath: String
    ) -> [AffectedFile] {
        var files: [AffectedFile] = []

        let fm = FileManager.default
        let skipDirs: Set<String> = [
            "node_modules", ".git", "dist", "build", ".nuxt",
            ".next", ".cache", "coverage", ".output",
        ]

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: projectPath),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let fileURL as URL in enumerator {
            // 跳过目录
            if skipDirs.contains(fileURL.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }

            let ext = fileURL.pathExtension.lowercased()
            let isTarget = ext == "vue" || ext == "ts" || ext == "tsx" || ext == "js" || ext == "jsx"
            guard isTarget else { continue }

            let filePath = fileURL.path

            // 跳过正在重命名的文件本身
            if filePath == oldPath { continue }

            // 读取文件并查找引用
            guard let content = try? VueTextFileIO.readContent(path: filePath) else { continue }

            var replacements: [TextReplacement] = []

            // 检测各种引用模式
            addImportReplacements(
                content: content,
                oldPascal: oldPascal,
                newPascal: newPascal,
                oldPath: oldPath,
                replacements: &replacements
            )

            addTemplateReplacements(
                content: content,
                oldPascal: oldPascal,
                newPascal: newPascal,
                oldKebab: oldKebab,
                newKebab: newKebab,
                replacements: &replacements
            )

            if !replacements.isEmpty {
                let fileType: AffectedFile.FileType
                switch ext {
                case "vue": fileType = .vue
                case "ts", "tsx": fileType = .typescript
                case "js", "jsx": fileType = .javascript
                default: fileType = .other
                }

                // 检测是否为 router 文件
                let fileName = fileURL.lastPathComponent.lowercased()
                let isRouter = fileName.contains("router") || fileName.contains("routes")
                let finalType = isRouter ? AffectedFile.FileType.router : fileType

                files.append(AffectedFile(
                    path: filePath,
                    replacements: replacements,
                    fileType: finalType
                ))
            }
        }

        return files
    }

    // MARK: - 引用检测

    /// 检测并添加 import 语句的替换
    private static func addImportReplacements(
        content: String,
        oldPascal: String,
        newPascal: String,
        oldPath: String,
        replacements: inout [TextReplacement]
    ) {
        // import OldName from '...'
        let importPattern = "import \(oldPascal) "
        if content.contains(importPattern) {
            replacements.append(TextReplacement(
                oldText: importPattern,
                newText: "import \(newPascal) ",
                kind: .importStatement
            ))
        }

        // import { OldName } from '...'
        let destructurePattern = "import { \(oldPascal) }"
        if content.contains(destructurePattern) {
            replacements.append(TextReplacement(
                oldText: destructurePattern,
                newText: "import { \(newPascal) }",
                kind: .importStatement
            ))
        }

        // import OldName from './relative/path/OldName.vue'
        let oldFileName = URL(fileURLWithPath: oldPath)
            .deletingPathExtension()
            .lastPathComponent
        if content.contains("/\(oldFileName).vue") || content.contains("/\(oldFileName)'") {
            replacements.append(TextReplacement(
                oldText: "/\(oldFileName).vue",
                newText: "/\(newPascal).vue",
                kind: .importStatement
            ))
            // 不带扩展名
            replacements.append(TextReplacement(
                oldText: "/\(oldFileName)'",
                newText: "/\(newPascal)'",
                kind: .importStatement
            ))
        }
    }

    /// 检测并添加 Template 标签的替换
    private static func addTemplateReplacements(
        content: String,
        oldPascal: String,
        newPascal: String,
        oldKebab: String,
        newKebab: String,
        replacements: inout [TextReplacement]
    ) {
        // <OldName .../> or <OldName> (PascalCase)
        let pascalOpen = "<\(oldPascal)"
        if content.contains(pascalOpen) {
            replacements.append(TextReplacement(
                oldText: pascalOpen,
                newText: "<\(newPascal)",
                kind: .templateTag
            ))
        }

        // </OldName> (closing tag)
        let pascalClose = "</\(oldPascal)"
        if content.contains(pascalClose) {
            replacements.append(TextReplacement(
                oldText: pascalClose,
                newText: "</\(newPascal)",
                kind: .templateTag
            ))
        }

        // <old-name .../> (kebab-case)
        if oldKebab != oldPascal {
            let kebabOpen = "<\(oldKebab)"
            if content.contains(kebabOpen) {
                replacements.append(TextReplacement(
                    oldText: kebabOpen,
                    newText: "<\(newKebab)",
                    kind: .templateTag
                ))
            }

            let kebabClose = "</\(oldKebab)"
            if content.contains(kebabClose) {
                replacements.append(TextReplacement(
                    oldText: kebabClose,
                    newText: "</\(newKebab)",
                    kind: .templateTag
                ))
            }
        }

        // components: { OldName }
        let componentsOption = "components: { \(oldPascal)"
        if content.contains(componentsOption) {
            replacements.append(TextReplacement(
                oldText: componentsOption,
                newText: "components: { \(newPascal)",
                kind: .componentOption
            ))
        }
    }
}
