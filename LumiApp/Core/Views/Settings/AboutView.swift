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
                // App icon and title
                headerSection

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

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: 20) {
            // App icon
            LogoView(variant: .about)
                .frame(width: 80, height: 80)
                .cornerRadius(18)
                .shadow(radius: 5)

            VStack(alignment: .leading, spacing: 8) {
                Text(appInfo.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Text(appInfo.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)

                if let version = appInfo.version {
                    HStack(spacing: 4) {
                        Image(systemName: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                        Text(version)
                            .font(.caption)
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }

    // MARK: - Info Cards

    private var appInfoCard: some View {
        InfoCard(title: "App Information", icon: "info.circle.fill") {
            AboutInfoRow(label: "App Name", value: appInfo.name)
            AboutInfoRow(label: "Bundle ID", value: appInfo.bundleIdentifier)
            if let description = appInfo.description {
                AboutInfoRow(label: "Description", value: description)
            }
        }
    }

    private var versionInfoCard: some View {
        InfoCard(title: "Version Information", icon: "number.circle.fill") {
            AboutInfoRow(label: "Version", value: appInfo.version ?? "Unknown")
            AboutInfoRow(label: "Build", value: appInfo.build ?? "Unknown")
            AboutInfoRow(label: "Build Configuration", value: versionInfo.buildConfiguration)
            AboutInfoRow(label: "Build Date", value: versionInfo.buildDate)
        }
    }

    private var buildHistoryCard: some View {
        InfoCard(title: "Build History", icon: "clock.arrow.circlepath") {
            AboutInfoRow(label: "Minimum Support", value: "macOS \(versionInfo.minimumOSVersion)")
            AboutInfoRow(label: "SDK Version", value: versionInfo.sdkVersion)
            AboutInfoRow(label: "Swift Version", value: versionInfo.swiftVersion)
            AboutInfoRow(label: "Xcode Version", value: versionInfo.xcodeVersion)
        }
    }

    private var systemInfoCard: some View {
        InfoCard(title: "System Information", icon: "desktopcomputer") {
            AboutInfoRow(label: "OS", value: versionInfo.systemVersion)
            AboutInfoRow(label: "Architecture", value: versionInfo.architecture)
            AboutInfoRow(label: "App Path", value: versionInfo.appPath)
        }
    }

    private var updateInfoCard: some View {
        InfoCard(title: "Update Information", icon: "arrow.down.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Current version is the latest stable version")
                    .font(.subheadline)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                GlassDivider()

                Text("Lumi uses the Sparkle framework for automatic updates. When a new version is available, the app will automatically prompt you to update.")
                    .font(.caption)
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

// MARK: - InfoCard Component

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        MystiqueGlassCard(cornerRadius: DesignTokens.Radius.md, padding: DesignTokens.Spacing.cardPadding) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: icon)
                        .foregroundColor(DesignTokens.Color.semantic.primary)
                    Text(title)
                        .font(DesignTokens.Typography.bodyEmphasized)
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    content
                }
            }
        }
    }
}

// MARK: - AboutInfoRow Component

struct AboutInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 100, alignment: .leading)

            Text(":")
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .textSelection(.enabled)

            Spacer()
        }
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
