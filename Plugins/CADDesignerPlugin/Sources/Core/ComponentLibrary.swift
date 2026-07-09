import Foundation

/// 组件目录：内置欧标 20/30/40 系列型材与连接件规格（等价 JSON 目录，代码内置便于无资源依赖）。
///
/// 规格参数参考文档第 4.3 节欧标型材规格体系。
public final class ComponentLibrary: @unchecked Sendable {
    public static let shared = ComponentLibrary()

    public let profiles: [ProfileSpec]
    public let connectors: [ConnectorSpec]

    private init() {
        // 欧标型材（文档第 4.3 节）：20/30/40 系列常用规格。
        // 米重为常见工程估算值（kg/m）。
        self.profiles = [
            // 20 系列（槽宽 6mm）：轻型框架、展示架
            ProfileSpec(id: "profile-20x20-eu", name: "20×20 欧标型材", series: .series20,
                        width: 20, height: 20, slotWidth: 6, slotDepth: 2, weightPerMeter: 0.52),
            ProfileSpec(id: "profile-20x40-eu", name: "20×40 欧标型材", series: .series20,
                        width: 20, height: 40, slotWidth: 6, slotDepth: 2, weightPerMeter: 0.98),
            ProfileSpec(id: "profile-20x60-eu", name: "20×60 欧标型材", series: .series20,
                        width: 20, height: 60, slotWidth: 6, slotDepth: 2, weightPerMeter: 1.42),
            ProfileSpec(id: "profile-20x80-eu", name: "20×80 欧标型材", series: .series20,
                        width: 20, height: 80, slotWidth: 6, slotDepth: 2, weightPerMeter: 1.88),
            // 30 系列（槽宽 8mm）：工作台、流水线
            ProfileSpec(id: "profile-30x30-eu", name: "30×30 欧标型材", series: .series30,
                        width: 30, height: 30, slotWidth: 8, slotDepth: 3, weightPerMeter: 0.92),
            ProfileSpec(id: "profile-30x60-eu", name: "30×60 欧标型材", series: .series30,
                        width: 30, height: 60, slotWidth: 8, slotDepth: 3, weightPerMeter: 1.74),
            ProfileSpec(id: "profile-30x90-eu", name: "30×90 欧标型材", series: .series30,
                        width: 30, height: 90, slotWidth: 8, slotDepth: 3, weightPerMeter: 2.62),
            // 40 系列（槽宽 8/10mm）：重型机架、设备框架
            ProfileSpec(id: "profile-40x40-eu", name: "40×40 欧标型材", series: .series40,
                        width: 40, height: 40, slotWidth: 8, slotDepth: 3, weightPerMeter: 1.45),
            ProfileSpec(id: "profile-40x80-eu", name: "40×80 欧标型材", series: .series40,
                        width: 40, height: 80, slotWidth: 8, slotDepth: 3, weightPerMeter: 2.86),
            ProfileSpec(id: "profile-40x120-eu", name: "40×120 欧标型材", series: .series40,
                        width: 40, height: 120, slotWidth: 8, slotDepth: 3, weightPerMeter: 4.28),
            ProfileSpec(id: "profile-40x160-eu", name: "40×160 欧标型材", series: .series40,
                        width: 40, height: 160, slotWidth: 8, slotDepth: 3, weightPerMeter: 5.72),
            ProfileSpec(id: "profile-80x80-eu", name: "80×80 欧标型材", series: .series40,
                        width: 80, height: 80, slotWidth: 10, slotDepth: 4, weightPerMeter: 5.32),
        ]

        // 连接件（文档第 4.4 节）
        self.connectors = [
            ConnectorSpec(id: "connector-corner-20", name: "20 系列角码", kind: .cornerBracket, series: .series20, unitWeight: 0.04),
            ConnectorSpec(id: "connector-corner-30", name: "30 系列角码", kind: .cornerBracket, series: .series30, unitWeight: 0.08),
            ConnectorSpec(id: "connector-corner-40", name: "40 系列角码", kind: .cornerBracket, series: .series40, unitWeight: 0.15),
            ConnectorSpec(id: "connector-bolt-20", name: "20 系列 T 型螺栓", kind: .bolt, series: .series20, unitWeight: 0.02),
            ConnectorSpec(id: "connector-bolt-30", name: "30 系列 T 型螺栓", kind: .bolt, series: .series30, unitWeight: 0.03),
            ConnectorSpec(id: "connector-bolt-40", name: "40 系列 T 型螺栓", kind: .bolt, series: .series40, unitWeight: 0.05),
            ConnectorSpec(id: "connector-nut-20", name: "20 系列滑块螺母", kind: .nut, series: .series20, unitWeight: 0.01),
            ConnectorSpec(id: "connector-nut-30", name: "30 系列滑块螺母", kind: .nut, series: .series30, unitWeight: 0.02),
            ConnectorSpec(id: "connector-nut-40", name: "40 系列滑块螺母", kind: .nut, series: .series40, unitWeight: 0.03),
            ConnectorSpec(id: "connector-endcap-20", name: "20 系列封端条", kind: .endCap, series: .series20, unitWeight: 0.005),
            ConnectorSpec(id: "connector-endcap-30", name: "30 系列封端条", kind: .endCap, series: .series30, unitWeight: 0.008),
            ConnectorSpec(id: "connector-endcap-40", name: "40 系列封端条", kind: .endCap, series: .series40, unitWeight: 0.012),
            ConnectorSpec(id: "connector-hinge-40", name: "40 系列合页", kind: .hinge, series: .series40, unitWeight: 0.22),
        ]
    }

    public func profileSpec(id: String) -> ProfileSpec? {
        profiles.first { $0.id == id }
    }

    public func connectorSpec(id: String) -> ConnectorSpec? {
        connectors.first { $0.id == id }
    }

    /// 按系列分组型材。
    public func profiles(groupedBy series: ProfileSeries) -> [ProfileSpec] {
        profiles.filter { $0.series == series }
    }

    /// 按系列分组连接件。
    public func connectors(groupedBy series: ProfileSeries) -> [ConnectorSpec] {
        connectors.filter { $0.series == series }
    }
}
