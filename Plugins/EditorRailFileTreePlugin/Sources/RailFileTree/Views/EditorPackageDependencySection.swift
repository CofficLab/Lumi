import AppKit
import EditorService
import LumiCoreKit
import SwiftUI

public struct EditorPackageDependencySection: View {
    @EnvironmentObject private var editorContext: EditorContext

    public let projectRootPath: String
    public let dependencies: [EditorPackageDependency]
    public let isLoading: Bool
    public let diagnostic: String?
    public let onRetry: () -> Void

    @State private var isExpanded: Bool = true

    public var body: some View {
        guard let theme = editorContext.activeChromeTheme else {
            return AnyView(Color.clear)
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    isExpanded.toggle()
                    EditorFileTreeStore.shared.setPackageDependencySectionExpanded(isExpanded, for: projectRootPath)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(theme.workspaceSecondaryTextColor())
                            .frame(width: 12)

                        Image(systemName: "shippingbox")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accentColors().primary)
                            .frame(width: 16)

                        Text(LumiPluginLocalization.string("Package Dependencies", bundle: .module))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.workspaceTextColor())
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if isLoading {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.55)
                                .frame(width: 14, height: 14)
                        } else if !dependencies.isEmpty {
                            Text("\(dependencies.count)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(theme.workspaceSecondaryTextColor())
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu { contextMenuContent }

                if isExpanded {
                    if dependencies.isEmpty {
                        Text(diagnostic ?? LumiPluginLocalization.string("No package dependencies", bundle: .module))
                            .font(.system(size: 10))
                            .foregroundColor(theme.workspaceSecondaryTextColor())
                            .lineLimit(2)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 6)
                            .padding(.leading, 28)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(dependencies) { dependency in
                                EditorPackageDependencyRow(dependency: dependency, depth: 1)
                            }
                        }
                    }
                }
            }
            .onAppear {
                isExpanded = EditorFileTreeStore.shared.isPackageDependencySectionExpanded(for: projectRootPath)
            }
            .onChange(of: projectRootPath) { _, newPath in
                isExpanded = EditorFileTreeStore.shared.isPackageDependencySectionExpanded(for: newPath)
            }
        )
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button { onRetry() } label: {
            Label(LumiPluginLocalization.string("Retry refresh", bundle: .module), systemImage: "arrow.clockwise")
        }
        if let diagnostic {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(diagnostic, forType: .string)
            } label: {
                Label(LumiPluginLocalization.string("Copy diagnostic text", bundle: .module), systemImage: "doc.on.doc")
            }
        }
    }
}
