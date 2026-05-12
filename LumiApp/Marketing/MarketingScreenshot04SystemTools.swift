import SwiftUI

struct MarketingScreenshot04SystemTools: View {
    var body: some View {
        MarketingScreenshotStage(
            eyebrow: "Built-In Tools",
            title: "Monitor your Mac and clean project clutter",
            subtitle: "Static dashboards mirror Lumi's device and disk utility plugins for everyday developer maintenance."
        ) {
            MarketingMacWindow {
                MarketingToolPageShell(selectedIcon: "macbook.and.iphone") {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            MarketingSystemToolDashboard()
                        }
                        MarketingStatusBar()
                    }
                }
            }
        }
    }
}

private struct MarketingSystemToolDashboard: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Device Info", systemImage: "macbook.and.iphone")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("Live sample")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Color.white.opacity(0.035))

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 18) {
                    MarketingSystemMetricCard(title: "CPU", value: "38%", icon: "cpu", tint: Color(red: 0.19, green: 0.82, blue: 0.35), values: [22, 34, 28, 44, 39, 51, 37, 42, 38])
                    MarketingSystemMetricCard(title: "Memory", value: "12.4 GB", icon: "memorychip", tint: Color(red: 0.49, green: 0.44, blue: 1.00), values: [40, 45, 47, 49, 52, 50, 54, 56, 58])
                }

                VStack(spacing: 18) {
                    MarketingSystemMetricCard(title: "Network", value: "42 MB/s", icon: "network", tint: Color(red: 0.04, green: 0.52, blue: 1.00), values: [12, 18, 28, 22, 40, 33, 48, 39, 46])
                    MarketingSystemMetricCard(title: "Disk I/O", value: "128 MB/s", icon: "internaldrive", tint: Color(red: 1.00, green: 0.62, blue: 0.04), values: [8, 12, 17, 32, 21, 36, 29, 44, 31])
                }

                MarketingDiskUtilityPreview()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.092, green: 0.098, blue: 0.116))
        }
    }
}

private struct MarketingSystemMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color
    let values: [CGFloat]

    var body: some View {
        MarketingCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(value)
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundStyle(tint)
                }
                .foregroundStyle(.white)

                GeometryReader { proxy in
                    Path { path in
                        let step = proxy.size.width / CGFloat(max(values.count - 1, 1))
                        for index in values.indices {
                            let x = CGFloat(index) * step
                            let y = proxy.size.height - (values[index] / 60.0 * proxy.size.height)
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 112)
                .background(Color.black.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(width: 330, height: 196)
    }
}

private struct MarketingDiskUtilityPreview: View {
    var body: some View {
        MarketingCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Disk Manager", systemImage: "internaldrive")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text("312 GB free")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                }
                .foregroundStyle(.white)

                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: 0.68)
                            .stroke(Color(red: 0.49, green: 0.44, blue: 1.00), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text("68%")
                                .font(.system(size: 28, weight: .bold))
                            Text("used")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)

                    VStack(spacing: 10) {
                        MarketingUtilityModeRow(title: "Large Files", icon: "doc.text", value: "24 items", selected: true)
                        MarketingUtilityModeRow(title: "Directory Analysis", icon: "folder", value: "Scanning")
                        MarketingUtilityModeRow(title: "System Cleanup", icon: "gear", value: "8.6 GB")
                        MarketingUtilityModeRow(title: "Xcode Cleanup", icon: "hammer", value: "14.2 GB")
                    }
                }

                VStack(spacing: 8) {
                    MarketingLargeFilePreviewRow(name: "DerivedData", size: "8.4 GB")
                    MarketingLargeFilePreviewRow(name: "Simulator Caches", size: "5.1 GB")
                    MarketingLargeFilePreviewRow(name: "Build Archives", size: "3.7 GB")
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 410)
    }
}

private struct MarketingUtilityModeRow: View {
    let title: String
    let icon: String
    let value: String
    var selected = false

    var body: some View {
        HStack {
            Image(systemName: icon).frame(width: 20)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(selected ? .white : .white.opacity(0.72))
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(selected ? Color(red: 0.49, green: 0.44, blue: 1.00).opacity(0.26) : Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct MarketingLargeFilePreviewRow: View {
    let name: String
    let size: String

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
            Text(name)
            Spacer()
            Text(size).foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.86))
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color.black.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

#Preview("04 System Tools") {
    MarketingScreenshot04SystemTools()
}
