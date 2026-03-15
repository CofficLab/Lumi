import SwiftUI
import Darwin

struct LocalMachineInfoView: View {
    private static func localChipName() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else {
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &model, &size, nil, 0) == 0 else {
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        let name = String(cString: model).trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "Apple processor" {
            #if arch(arm64)
            return "Apple Silicon"
            #else
            return "Intel"
            #endif
        }
        return name
    }

    private static func localDiskTotalGB() -> Int {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64 else { return 0 }
        return Int(total / 1_000_000_000)
    }

    var body: some View {
        let chip = Self.localChipName()
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        let diskGB = Self.localDiskTotalGB()
        let osVer = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "macOS \(osVer.majorVersion).\(osVer.minorVersion).\(osVer.patchVersion)"
        let style = DesignTokens.Typography.caption2
        let color = DesignTokens.Color.semantic.textSecondary
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(chip, systemImage: "cpu")
                    .font(style)
                    .foregroundColor(color)
                Text("·").font(style).foregroundColor(color)
                Label("内存 \(ramGB) GB", systemImage: "memorychip")
                    .font(style)
                    .foregroundColor(color)
                Text("·").font(style).foregroundColor(color)
                Label("磁盘 \(diskGB) GB", systemImage: "internaldrive")
                    .font(style)
                    .foregroundColor(color)
                Text("·").font(style).foregroundColor(color)
                Label(osString, systemImage: "desktopcomputer")
                    .font(style)
                    .foregroundColor(color)
            }
            Text("请根据本机配置选择合适的模型进行下载和加载，以获得更稳定的体验。")
                .font(DesignTokens.Typography.caption2)
                .foregroundColor(DesignTokens.Color.semantic.textTertiary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
        )
    }
}

