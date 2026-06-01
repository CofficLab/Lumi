import SwiftUI
import LumiUI
import Darwin

struct LocalMachineInfoView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
        let nullTerminatorIndex = model.firstIndex(of: 0) ?? model.endIndex
        let bytes = model[..<nullTerminatorIndex].map { UInt8(bitPattern: $0) }
        let name = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
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
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Label(chip, systemImage: "cpu")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                Text("·").font(.appMicro).foregroundColor(theme.textSecondary)
                Label("内存 \(ramGB) GB", systemImage: "memorychip")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                Text("·").font(.appMicro).foregroundColor(theme.textSecondary)
                Label("磁盘 \(diskGB) GB", systemImage: "internaldrive")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
                Text("·").font(.appMicro).foregroundColor(theme.textSecondary)
                Label(osString, systemImage: "desktopcomputer")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }
            Text("请根据本机配置选择合适的模型进行下载和加载，以获得更稳定的体验。")
                .font(.appMicro)
                .foregroundColor(theme.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(
            style: .custom(theme.appStatusMutedFill),
            cornerRadius: 8
        )
    }
}
