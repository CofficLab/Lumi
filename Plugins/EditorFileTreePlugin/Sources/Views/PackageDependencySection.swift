import AppKit
import LumiCoreKit
import LumiUI
import SwiftUI

public struct PackageDependencySection: View {
    @LumiTheme private var uiTheme

    public let projectRootPath: String
    public let dependencies: [PackageDependency]
    public let isLoading: Bool
    public let diagnostic: String?
    public let onRetry: () -> Void

    @State private var isExpanded: Bool = true

    public var body: some View {
        // 直接返回 VStack，避免 AnyView 擦除类型、阻断 SwiftUI 静态 diff（递归树中成本放大）。
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
                FileTreeSettings.shared.setPackageDependencySectionExpanded(isExpanded, for: projectRootPath)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(uiTheme.textTertiary)
                        .frame(width: 12)

                    Image(systemName: "shippingbox")
                        .font(.system(size: 12))
                        .foregroundColor(uiTheme.primary)
                        .frame(width: 16)

                    Text(LumiPluginLocalization.string("Package Dependencies", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(uiTheme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if isLoading {
                        ProgressView()
                            .controlSize(.mini)
                            .scaleEffect(0.55)
                            .frame(width: 14, height: 14)
                    } else if !dependencies.isEmpty {
                        Text("\(dependencies.count)")
                            .font(.appMicro)
                            .foregroundColor(uiTheme.textSecondary)
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
                        .font(.appMicro)
                        .foregroundColor(uiTheme.textSecondary)
                        .lineLimit(2)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 6)
                        .padding(.leading, 28)
                } else {
                    VStack(spacing: 1) {
                        ForEach(dependencies) { dependency in
                            PackageDependencyRow(dependency: dependency, depth: 1)
                        }
                    }
                }
            }
        }
        .onAppear {
            isExpanded = FileTreeSettings.shared.isPackageDependencySectionExpanded(for: projectRootPath)
        }
        .onChange(of: projectRootPath) { _, newPath in
            isExpanded = FileTreeSettings.shared.isPackageDependencySectionExpanded(for: newPath)
        }
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
