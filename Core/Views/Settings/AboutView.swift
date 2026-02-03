import SwiftUI

/// 关于页面视图，显示应用详细信息
struct AboutView: View {
    /// 应用信息
    private var appInfo: AppInfo {
        AppInfo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 32) {
                Spacer().frame(height: 40)

                // App 图标和名称
                VStack(spacing: 16) {
                    // App 图标
                    LogoView(variant: .about, design: .smartLight)
                        .frame(width: 128, height: 128)

                    // App 名称
                    Text(appInfo.name)
                        .font(.title)
                        .fontWeight(.bold)

                    // App 版本
                    VStack(spacing: 4) {
                        Text("版本 \(appInfo.version)")
                            .font(.body)
                            .foregroundColor(.secondary)

                        Text("Build \(appInfo.build)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 信息区域
                VStack(spacing: 24) {
                    // 描述
                    VStack(alignment: .leading, spacing: 8) {
                        Text("关于")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(appInfo.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // 基本信息
                    VStack(alignment: .leading, spacing: 12) {
                        Text("应用信息")
                            .font(.headline)

                        VStack(spacing: 8) {
                            infoRow(title: "应用名称", value: appInfo.name)
                            infoRow(title: "版本", value: appInfo.version)
                            infoRow(title: "Build", value: appInfo.build)
                            infoRow(title: "Bundle ID", value: appInfo.bundleIdentifier)
                        }
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
            }
        }
        .navigationTitle("关于")
    }

    /// 信息行组件
    /// - Parameters:
    ///   - title: 标题
    ///   - value: 值
    /// - Returns: 信息行视图
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

/// 应用信息模型
struct AppInfo {
    let name: String
    let version: String
    let build: String
    let bundleIdentifier: String
    let description: String

    init() {
        let bundle = Bundle.main
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "SwiftUI Template"
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        self.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.yourcompany.SwiftUI-Template"
        self.description = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as?
            String ?? "一个现代化的macOS应用，让您的体验更加简单高效。"
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
