import AppKit
import Foundation
import SwiftUI
import OSLog

struct SmartApp: Identifiable, Sendable, Equatable, Hashable {
    // MARK: - Properties
    
    static let emoji = "🐒"

    var id: String
    var name: String

    /// Is system app
    var isSystemApp: Bool = false

    /// Is hidden
    var hidden: Bool = false

    /// Is sample app
    var isSample: Bool = false

    /// Is proxy app
    var isProxy: Bool = false

    /// the URL to the application's bundle
    var bundleURL: URL?

    var isNotSample: Bool { !isSample }
    var hasId: Bool { !id.isEmpty }
    var hasNoId: Bool { id.isEmpty }
    
    // MARK: - Equatable
    
    static func == (lhs: SmartApp, rhs: SmartApp) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.isSystemApp == rhs.isSystemApp &&
               lhs.hidden == rhs.hidden &&
               lhs.isSample == rhs.isSample &&
               lhs.isProxy == rhs.isProxy &&
               lhs.bundleURL == rhs.bundleURL
    }
}

// MARK: - Instance Methods

extension SmartApp {
    /// Get App Icon
    func getIcon() -> some View {
        // Check running app first
        if let runningApp = Self.getApp(self.id), let icon = runningApp.icon {
            return AnyView(Image(nsImage: icon))
        }
        
        // Fallback to Workspace icon for bundle URL
        if let url = self.bundleURL {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            return AnyView(Image(nsImage: icon))
        }
        
        // Fallback generic
        return AnyView(Image(systemName: "app.dashed"))
    }
}

// MARK: - Factory Methods

extension SmartApp {
    /// Create SmartApp from ID
    static func fromId(_ id: String) -> Self {
        if let runningApp = getApp(id) {
            return SmartApp(
                id: id,
                name: runningApp.localizedName ?? "",
                isProxy: Self.isProxyApp(runningApp),
                bundleURL: runningApp.bundleURL
            )
        }

        // Handle unknown app
        return SmartApp(id: id, name: id, isSystemApp: false, hidden: false, isSample: false, isProxy: Self.isProxyApp(withId: id), bundleURL: nil)
    }

    /// Create SmartApp from NSRunningApplication
    static func fromRunningApp(_ app: NSRunningApplication) -> Self {
        return SmartApp(
            id: app.bundleIdentifier ?? "-",
            name: app.localizedName ?? "-",
            isProxy: Self.isProxyApp(app),
            bundleURL: app.bundleURL
        )
    }
}

// MARK: - Static Properties & Helper Logic

extension SmartApp {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.cofficlab.lumi", category: "SmartApp")

    /// Current running app list (deduplicated)
    static let appList: [SmartApp] = getRunningAppList().map {
        Self.fromRunningApp($0)
    }.reduce(into: []) { result, app in
        if !result.contains(where: { $0.id == app.id }) {
            result.append(app)
        }
    }
    
    /// Get all running applications
    static func getRunningAppList() -> [NSRunningApplication] {
        let workspace = NSWorkspace.shared
        return workspace.runningApplications
    }

    /// Find running app by ID
    static func getApp(_ id: String, verbose: Bool = false) -> NSRunningApplication? {
        let apps = getRunningAppList()

        for app in apps {
            guard let bundleIdentifier = app.bundleIdentifier else {
                continue
            }

            if bundleIdentifier == id {
                return app
            }
            
            // Loose match
            if id.contains(bundleIdentifier) {
                return app
            }
        }

        if verbose {
            logger.debug("⚠️ App not found: \(id)")
        }

        return nil
    }
    
    /// Check if app is proxy (NSRunningApplication)
    static func isProxyApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleId = app.bundleIdentifier else {
            return false
        }
        
        return isProxyApp(withId: bundleId, name: app.localizedName)
    }
    
    /// Check if app is proxy (ID)
    static func isProxyApp(withId appId: String, name: String? = nil) -> Bool {
        // Common Proxy Apps
        let proxyAppIdentifiers = [
            "com.expressvpn.ExpressVPN",
            "com.nordvpn.osx",
            "com.surfshark.vpnclient.macos",
            "com.cyberghostvpn.mac",
            "com.privateinternetaccess.vpn",
            "com.tunnelbear.mac.TunnelBear",
            "com.protonvpn.mac",
            "com.windscribe.desktop",
            "com.hotspotshield.vpn.mac",
            "com.qiuyuzhou.ShadowsocksX-NG",
            "com.shadowsocks.ShadowsocksX-NG",
            "clowwindy.ShadowsocksX",
            "com.github.shadowsocks.ShadowsocksX-NG",
            "com.v2ray.V2RayU",
            "com.yanue.V2rayU",
            "com.v2rayx.V2RayX",
            "net.qiuyuzhou.V2RayX",
            "com.west2online.ClashX",
            "com.dreamacro.clash.for.windows",
            "com.clash.for.windows",
            "com.github.yichengchen.clashX",
            "com.nssurge.surge-mac",
            "com.nssurge.surge.mac",
            "com.proxyman.NSProxy",
            "com.xk72.Charles",
            "org.wireshark.Wireshark",
            "com.proxifier.macos",
            "org.torproject.torbrowser",
            "org.getlantern.lantern",
            "ca.psiphon.Psiphon",
            "net.tunnelblick.tunnelblick",
            "net.openvpn.connect.app",
            "com.viscosityvpn.Viscosity"
        ]
        
        if proxyAppIdentifiers.contains(appId) {
            return true
        }
        
        let proxyKeywords = [
            "vpn", "proxy", "shadowsocks", "v2ray", "clash", 
            "surge", "trojan", "ssr", "vmess", "vless",
            "wireguard", "openvpn", "tunnel", "tor"
        ]
        
        let lowercaseBundleId = appId.lowercased()
        let lowercaseName = (name ?? "").lowercased()
        
        for keyword in proxyKeywords {
            if lowercaseBundleId.contains(keyword) || lowercaseName.contains(keyword) {
                return true
            }
        }
        
        return false
    }
}
