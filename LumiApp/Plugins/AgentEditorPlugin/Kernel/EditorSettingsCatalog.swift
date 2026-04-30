import SwiftUI

@MainActor
struct EditorSettingsCatalogSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let entries: [EditorSettingsCatalogEntry]
}

@MainActor
struct EditorSettingsCatalogEntry: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let keywords: [String]
    let content: (EditorSettingsState) -> AnyView
}

@MainActor
enum EditorSettingsCatalog {
    static func builtInSections() -> [EditorSettingsCatalogSection] {
        [
            EditorSettingsCatalogSection(
                id: "editor.typography",
                title: "字体与缩进",
                subtitle: "控制编辑器的基本排版、缩进宽度和制表符策略。",
                entries: [
                    .init(
                        id: "editor.font-size",
                        title: "字体大小",
                        subtitle: "调整 source editor 的默认字号。",
                        keywords: ["font", "font size", "字号", "字体"],
                        content: { state in
                            AnyView(
                                EditorStepperSettingRow(
                                    title: "字体大小",
                                    subtitle: "当前 \(Int(state.fontSize)) pt",
                                    value: Binding(
                                        get: { Int(state.fontSize) },
                                        set: { state.fontSize = Double($0) }
                                    ),
                                    range: 10...28
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.tab-width",
                        title: "Tab Size",
                        subtitle: "控制缩进宽度和软制表符长度。",
                        keywords: ["tab", "tab size", "indent", "缩进"],
                        content: { state in
                            AnyView(
                                EditorSegmentedSettingRow(
                                    title: "Tab Size",
                                    subtitle: "代码缩进默认宽度",
                                    selection: Binding(
                                        get: { state.tabWidth },
                                        set: { state.tabWidth = $0 }
                                    ),
                                    options: [2, 4, 8]
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.use-spaces",
                        title: "Insert Spaces",
                        subtitle: "使用空格替代真实 Tab 字符。",
                        keywords: ["spaces", "tabs", "indent", "空格", "tab"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Insert Spaces",
                                    subtitle: "输入缩进时优先插入空格",
                                    isOn: Binding(
                                        get: { state.useSpaces },
                                        set: { state.useSpaces = $0 }
                                    )
                                )
                            )
                        }
                    )
                ]
            ),
            EditorSettingsCatalogSection(
                id: "editor.display",
                title: "显示选项",
                subtitle: "控制行号、换行、折叠和 minimap 等可视表面。",
                entries: [
                    .init(
                        id: "editor.wrap-lines",
                        title: "Word Wrap",
                        subtitle: "长行在视口宽度内自动折返。",
                        keywords: ["wrap", "word wrap", "自动换行"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Word Wrap",
                                    subtitle: "超长文本在当前视口内换行显示",
                                    isOn: Binding(
                                        get: { state.wrapLines },
                                        set: { state.wrapLines = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.minimap",
                        title: "Minimap",
                        subtitle: "在右侧显示文档概览；大文件模式下可能被强制关闭。",
                        keywords: ["minimap", "overview", "概览"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Minimap",
                                    subtitle: "显示右侧文档概览",
                                    isOn: Binding(
                                        get: { state.showMinimap },
                                        set: { state.showMinimap = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.line-numbers",
                        title: "Line Numbers",
                        subtitle: "显示左侧 gutter 与行号。",
                        keywords: ["line numbers", "gutter", "行号"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Line Numbers",
                                    subtitle: "显示 gutter、行号与左侧 marker",
                                    isOn: Binding(
                                        get: { state.showGutter },
                                        set: { state.showGutter = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.folding",
                        title: "Code Folding",
                        subtitle: "显示折叠 ribbon 与折叠摘要。",
                        keywords: ["folding", "fold", "折叠"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Code Folding",
                                    subtitle: "显示折叠控制与折叠摘要",
                                    isOn: Binding(
                                        get: { state.showFoldingRibbon },
                                        set: { state.showFoldingRibbon = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.render-whitespace",
                        title: "Render Whitespace",
                        subtitle: "当前底层 editor engine 尚未开放独立 whitespace 渲染开关。",
                        keywords: ["render whitespace", "whitespace", "空白字符"],
                        content: { state in
                            AnyView(
                                EditorReadOnlySettingRow(
                                    title: "Render Whitespace",
                                    subtitle: state.supportsRenderWhitespace
                                        ? "Whitespace rendering is available."
                                        : "Unavailable in the current source editor backend.",
                                    badge: state.supportsRenderWhitespace ? "Available" : "Unavailable"
                                )
                            )
                        }
                    )
                ]
            ),
            EditorSettingsCatalogSection(
                id: "editor.save-pipeline",
                title: "保存行为",
                subtitle: "控制保存时的格式化、imports 和清理策略。",
                entries: [
                    .init(
                        id: "editor.format-on-save",
                        title: "Format On Save",
                        subtitle: "保存时尝试运行格式化。",
                        keywords: ["format on save", "save", "格式化"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Format On Save",
                                    subtitle: "保存文件时自动触发格式化",
                                    isOn: Binding(
                                        get: { state.formatOnSave },
                                        set: { state.formatOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.organize-imports-on-save",
                        title: "Organize Imports On Save",
                        subtitle: "保存时请求 LSP 整理 imports。",
                        keywords: ["organize imports", "imports", "save"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Organize Imports On Save",
                                    subtitle: "保存时整理 imports",
                                    isOn: Binding(
                                        get: { state.organizeImportsOnSave },
                                        set: { state.organizeImportsOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.fix-all-on-save",
                        title: "Fix All On Save",
                        subtitle: "保存时请求 LSP 执行 source.fixAll。",
                        keywords: ["fix all", "save", "code actions"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Fix All On Save",
                                    subtitle: "保存时运行 source.fixAll",
                                    isOn: Binding(
                                        get: { state.fixAllOnSave },
                                        set: { state.fixAllOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.trim-trailing-whitespace",
                        title: "Trim Trailing Whitespace",
                        subtitle: "保存时移除每行末尾多余空格。",
                        keywords: ["trim trailing whitespace", "whitespace", "save"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Trim Trailing Whitespace",
                                    subtitle: "保存时清理行尾空白",
                                    isOn: Binding(
                                        get: { state.trimTrailingWhitespaceOnSave },
                                        set: { state.trimTrailingWhitespaceOnSave = $0 }
                                    )
                                )
                            )
                        }
                    ),
                    .init(
                        id: "editor.insert-final-newline",
                        title: "Insert Final Newline",
                        subtitle: "保存时确保文件结尾带换行。",
                        keywords: ["final newline", "newline", "save"],
                        content: { state in
                            AnyView(
                                EditorToggleSettingRow(
                                    title: "Insert Final Newline",
                                    subtitle: "保存时补齐文件末尾换行",
                                    isOn: Binding(
                                        get: { state.insertFinalNewlineOnSave },
                                        set: { state.insertFinalNewlineOnSave = $0 }
                                    )
                                )
                            )
                        }
                    )
                ]
            )
        ]
    }
}
