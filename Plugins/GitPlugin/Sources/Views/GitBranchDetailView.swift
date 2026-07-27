import SwiftUI
import LumiKernel

/// Git 分支详情视图（在 popover 中显示）
public struct GitBranchDetailView: View {
    public let branchName: String?
    public let isDirty: Bool?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "7C6FFF"))

                Text(LumiPluginLocalization.string("Git Information", bundle: .module))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                Spacer()
            }

            Divider()

            if let branch = branchName {
                GitInfoRow(label: LumiPluginLocalization.string("Current Branch", bundle: .module), value: branch)

                if let dirty = isDirty {
                    HStack(spacing: 8) {
                        Text(LumiPluginLocalization.string("Status", bundle: .module))
                            .font(.system(size: 12))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            .frame(width: 70, alignment: .leading)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(dirty ? Color(hex: "FF9F0A") : Color(hex: "30D158"))
                                .frame(width: 6, height: 6)

                            Text(dirty
                                ? LumiPluginLocalization.string("Uncommitted Changes", bundle: .module)
                                : LumiPluginLocalization.string("Clean Working Tree", bundle: .module))
                                .font(.system(size: 12))
                                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        }

                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "FF9F0A"))

                    Text(LumiPluginLocalization.string("Unable to Get Git Information", bundle: .module))
                        .font(.system(size: 13))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
}

/// Git 信息行
public struct GitInfoRow: View {
    public let label: String
    public let value: String

    public var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                .lineLimit(2)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - 预览

#Preview("Detail View") {
    GitBranchDetailView(branchName: "main", isDirty: true)
        .frame(width: 300)
}
