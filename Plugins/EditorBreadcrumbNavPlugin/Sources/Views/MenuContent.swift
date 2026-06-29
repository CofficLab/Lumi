import SwiftUI

// MARK: - Menu Content

/// 面包屑下拉菜单内容视图（显示同目录下的兄弟节点）
public struct MenuContent: View {
    public let siblings: [BreadcrumbSibling]
    public let currentURL: URL
    public let onSelectFile: (URL) -> Void

    public var body: some View {
        let directories = siblings.filter(\.isDirectory)
        let files = siblings.filter { !$0.isDirectory }

        if !directories.isEmpty {
            Section {
                ForEach(directories) { sibling in
                    MenuRow(
                        sibling: sibling,
                        isCurrent: sibling.url == currentURL,
                        onSelectFile: onSelectFile
                    )
                }
            }
        }

        if !files.isEmpty {
            if !directories.isEmpty {
                Divider()
            }
            Section {
                ForEach(files) { sibling in
                    MenuRow(
                        sibling: sibling,
                        isCurrent: sibling.url == currentURL,
                        onSelectFile: onSelectFile
                    )
                }
            }
        }
    }
}
