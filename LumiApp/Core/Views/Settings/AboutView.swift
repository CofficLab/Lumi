import SwiftUI

/// About view, displays app details
struct AboutView: View {
    /// App info
    private var appInfo: AppInfo {
        AppInfo()
    }

    /// Version info
    private var versionInfo: VersionInfo {
        VersionInfo()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // App info card
                appInfoCard

                // Version info card
                versionInfoCard

                // Build history card
                buildHistoryCard

                // System info card
                systemInfoCard

                // Update info card
                updateInfoCard

                Spacer()
            }
            .padding(32)
        }
        .navigationTitle("About")
    }

    // MARK: - Info Cards

    private var appInfoCard: some View {
        GlassInfoCard(title: "App Information", icon: "info.circle.fill") {
            GlassKeyValueRow(label: "App Name", value: appInfo.name)
            GlassKeyValueRow(label: "Bundle ID", value: appInfo.bundleIdentifier)
            if let description = appInfo.description {
                GlassKeyValueRow(label: "Description", value: description)
            }
        }
    }

    private var versionInfoCard: some View {
        GlassInfoCard(title: "Version Information", icon: "number.circle.fill") {
            GlassKeyValueRow(label: "Version", value: appInfo.version ?? "Unknown")
            GlassKeyValueRow(label: "Build", value: appInfo.build ?? "Unknown")
            GlassKeyValueRow(label: "Build Configuration", value: versionInfo.buildConfiguration)
            GlassKeyValueRow(label: "Build Date", value: versionInfo.buildDate)
        }
    }

    private var buildHistoryCard: some View {
        GlassInfoCard(title: "Build History", icon: "clock.arrow.circlepath") {
            GlassKeyValueRow(label: "Minimum Support", value: "macOS \(versionInfo.minimumOSVersion)")
            GlassKeyValueRow(label: "SDK Version", value: versionInfo.sdkVersion)
            GlassKeyValueRow(label: "Swift Version", value: versionInfo.swiftVersion)
            GlassKeyValueRow(label: "Xcode Version", value: versionInfo.xcodeVersion)
        }
    }

    private var systemInfoCard: some View {
        GlassInfoCard(title: "System Information", icon: "desktopcomputer") {
            GlassKeyValueRow(label: "OS", value: versionInfo.systemVersion)
            GlassKeyValueRow(label: "Architecture", value: versionInfo.architecture)
            GlassKeyValueRow(label: "App Path", value: versionInfo.appPath)
        }
    }

    private var updateInfoCard: some View {
        GlassInfoCard(title: "Update Information", icon: "arrow.down.circle.fill", subtitle: "Automatic updates") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current version is the latest stable version")
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                GlassDivider()

                Text("Lumi uses the Sparkle framework for automatic updates. When a new version is available, the app will automatically prompt you to update.")
                    .font(DesignTokens.Typography.caption1)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
            }
        }
    }
}

// MARK: - AppInfo Model

struct AppInfo {
    let name: String
    let version: String?
    let build: String?
    let bundleIdentifier: String
    let description: String?

    init() {
        let bundle = Bundle.main
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Lumi"
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        self.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        self.bundleIdentifier = bundle.bundleIdentifier ?? "com.lumi.app"
        self.description = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String
    }
}

// MARK: - VersionInfo Model

struct VersionInfo {
    let shortVersion: String
    let buildVersion: String
    let buildConfiguration: String
    let buildDate: String
    let minimumOSVersion: String
    let sdkVersion: String
    let swiftVersion: String
    let xcodeVersion: String
    let architecture: String
    let systemVersion: String
    let appPath: String

    init() {
        let bundle = Bundle.main

        // Basic info
        self.shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        self.buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        // Build configuration
        #if DEBUG
        self.buildConfiguration = "Debug"
        #else
        self.buildConfiguration = "Release"
        #endif

        // Build date
        if let buildDateString = bundle.object(forInfoDictionaryKey: "BuildDate") as? String {
            self.buildDate = buildDateString
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            self.buildDate = formatter.string(from: Date())
        }

        // System info
        self.minimumOSVersion = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String ?? "15.0"

        // SDK info
        self.sdkVersion = "macOS 26.2"

        // Swift version
        self.swiftVersion = "6.0"

        // Xcode version
        self.xcodeVersion = "17.2"

        // Architecture
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? "Unknown"
            }
        }
        self.architecture = machine

        // System version
        let processInfo = ProcessInfo.processInfo
        self.systemVersion = processInfo.operatingSystemVersionString

        // App path
        self.appPath = bundle.bundlePath
    }
}

// MARK: - Preview

#Preview {
    AboutView()
}

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
