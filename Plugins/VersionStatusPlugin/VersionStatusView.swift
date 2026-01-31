import SwiftUI

/// 版本状态视图：在状态栏显示应用版本号
struct VersionStatusView: View {
    /// 应用版本号
    private let appVersion: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }()

    /// 构建号
    private let buildNumber: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }()

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "number")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("v\(appVersion)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)

            Text("(\(buildNumber))")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
}

// MARK: - Preview

#Preview("Version Status View") {
    HStack {
        Spacer()
        VersionStatusView()
            .padding()
        Spacer()
    }
    .frame(width: 150, height: 40)
    .background(Color(.controlBackgroundColor))
}
