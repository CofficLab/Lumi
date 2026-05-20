import AppKit
import SwiftUI

struct EditorPackageDependencySection: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let projectRootPath: String
    let dependencies: [EditorPackageDependency]
    let isLoading: Bool
    let diagnostic: String?
    let onRetry: () -> Void

    @State private var isExpanded: Bool = true

    var body: some View {
        let theme = themeVM.activeAppTheme

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

                    Text(String(localized: "Package Dependencies", table: "EditorRailFileTree"))
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
                    Text(diagnostic ?? String(localized: "No package dependencies", table: "EditorRailFileTree"))
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
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button { onRetry() } label: {
            Label(String(localized: "Retry refresh", table: "EditorRailFileTree"), systemImage: "arrow.clockwise")
        }
        if let diagnostic {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(diagnostic, forType: .string)
            } label: {
                Label(String(localized: "Copy diagnostic text", table: "EditorRailFileTree"), systemImage: "doc.on.doc")
            }
        }
    }
}
