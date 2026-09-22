import CoreGraphics
import Foundation

// MARK: - 设备

/// 原型画板使用的设备类型。
///
/// 尺寸以**逻辑点（CSS px）**为单位：与 HTML/CSS 的视口一致，
/// 导出像素 = 逻辑尺寸 × `scale`。这与 `KitAppStorePromo` 的
/// 「固定 App Store 枚举尺寸」不同——原型要支持任意设备。
public enum PrototypeDeviceKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case iPhone15Pro
    case iPhone15ProMax
    case iPhoneSE
    case iPadPro11
    case iPadPro129
    case desktop
    case custom

    public var id: String { rawValue }

    /// 设备族展示名（如 "iPhone 15 Pro"）。
    public var displayName: String {
        switch self {
        case .iPhone15Pro: "iPhone 15 Pro"
        case .iPhone15ProMax: "iPhone 15 Pro Max"
        case .iPhoneSE: "iPhone SE"
        case .iPadPro11: "iPad Pro 11\""
        case .iPadPro129: "iPad Pro 12.9\""
        case .desktop: "Desktop"
        case .custom: "Custom"
        }
    }

    /// 预置设备的默认配置；`.custom` 无默认值。
    public var preset: PrototypeDevice? {
        switch self {
        case .iPhone15Pro: PrototypeDevice(kind: .iPhone15Pro, width: 393, height: 852, scale: 3)
        case .iPhone15ProMax: PrototypeDevice(kind: .iPhone15ProMax, width: 430, height: 932, scale: 3)
        case .iPhoneSE: PrototypeDevice(kind: .iPhoneSE, width: 375, height: 667, scale: 2)
        case .iPadPro11: PrototypeDevice(kind: .iPadPro11, width: 834, height: 1194, scale: 2)
        case .iPadPro129: PrototypeDevice(kind: .iPadPro129, width: 1024, height: 1366, scale: 2)
        case .desktop: PrototypeDevice(kind: .desktop, width: 1440, height: 900, scale: 2)
        case .custom: nil
        }
    }
}

/// 画板设备：逻辑尺寸 + 导出倍率 + 画板圆角。
public struct PrototypeDevice: Codable, Equatable, Sendable {
    public var kind: PrototypeDeviceKind
    /// 逻辑宽度（CSS px）。
    public var width: Double
    /// 逻辑高度（CSS px）。
    public var height: Double
    /// 导出倍率：输出像素 = 逻辑尺寸 × scale。
    public var scale: Double

    public var logicalSize: CGSize { CGSize(width: width, height: height) }

    /// 导出后的像素尺寸。
    public var pixelWidth: Int { Int((width * scale).rounded()) }
    public var pixelHeight: Int { Int((height * scale).rounded()) }

    public var isPortrait: Bool { height >= width }

    public init(kind: PrototypeDeviceKind, width: Double, height: Double, scale: Double) {
        self.kind = kind
        self.width = width
        self.height = height
        self.scale = scale
    }

    enum CodingKeys: String, CodingKey {
        case kind, width, height, scale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(PrototypeDeviceKind.self, forKey: .kind) ?? .custom
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 393
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? 852
        scale = try c.decodeIfPresent(Double.self, forKey: .scale) ?? 2
    }
}

// MARK: - 视觉风格

/// 原型视觉风格：决定新屏幕使用的起始模板。
public enum PrototypeStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// 低保真线框图：灰阶、占位块、强调结构而非视觉。
    case wireframe
    /// 高保真：带品牌色、圆角与真实排版。
    case hiFi

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wireframe: "Wireframe"
        case .hiFi: "Hi-Fi"
        }
    }
}

// MARK: - 屏幕

/// 一屏原型：一个独立的完整 HTML 文档。
public struct PrototypeScreen: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var order: Int
    public var htmlFileName: String
    /// 从 HTML 中的 `data-prototype-link` 反向解析出的跳转关系（索引缓存）。
    public var hotspots: [PrototypeHotspot]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        title: String,
        order: Int,
        htmlFileName: String = "index.html",
        hotspots: [PrototypeHotspot] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.order = order
        self.htmlFileName = htmlFileName
        self.hotspots = hotspots
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, title, order, htmlFileName, hotspots, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 0
        htmlFileName = try c.decodeIfPresent(String.self, forKey: .htmlFileName) ?? "index.html"
        hotspots = try c.decodeIfPresent([PrototypeHotspot].self, forKey: .hotspots) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

// MARK: - 跳转

/// 一屏上的一个跳转热点：点击后进入 `targetScreenID`。
public struct PrototypeHotspot: Codable, Equatable, Sendable {
    /// 目标屏幕 slug。
    public var targetScreenID: String
    /// 可选的展示标签（来自 `data-prototype-label`）。
    public var label: String?

    public init(targetScreenID: String, label: String? = nil) {
        self.targetScreenID = targetScreenID
        self.label = label
    }
}

/// HTML 中承载原型语义的属性名与保留标识。
///
/// 跳转只由 LLM 在 HTML 里**声明**（写 data 属性），执行由宿主预览时
/// 注入的 JS 完成——与 `KitHTMLPreview` 现有 `data-block` 右键选区同一套路。
public enum PrototypeHTMLAttributes {
    /// 跳转目标屏幕：`data-prototype-link="screen-02-detail"`。
    public static let link = "data-prototype-link"
    /// 跳转控件展示标签：`data-prototype-label="进入详情"`。
    public static let label = "data-prototype-label"
    /// 区块标识（供右键选区定位）：`data-block="headline"`。
    public static let block = "data-block"
    /// 区块人类可读标签：`data-block-label="标题"`。
    public static let blockLabel = "data-block-label"

    /// 保留 slug：屏幕不能占用该名字（与项目级 `assets/` 目录冲突）。
    public static let reservedSlug = "assets"
}

// MARK: - 项目

/// 一个原型项目：一组按顺序排列的屏幕 + 画板设备 + 起始屏。
///
/// 存储布局（`.lumi/prototype/tasks/<id>/`）：
/// ```
/// manifest.json          ← 本结构
/// assets/                ← 项目级共享素材
/// <screen-slug>/index.html  ← 每屏一个完整 HTML 文档（引用 ../assets/...）
/// ```
public struct PrototypeProject: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var id: String
    public var title: String
    public var style: PrototypeStyle
    public var device: PrototypeDevice
    public var screens: [PrototypeScreen]
    /// 起始屏 slug；为空时取顺序第一屏。
    public var startScreenID: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        schemaVersion: Int = PrototypeProject.currentSchemaVersion,
        id: String,
        title: String,
        style: PrototypeStyle = .wireframe,
        device: PrototypeDevice,
        screens: [PrototypeScreen] = [],
        startScreenID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.style = style
        self.device = device
        self.screens = screens
        self.startScreenID = startScreenID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, title, style, device, screens, startScreenID, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? id
        style = try c.decodeIfPresent(PrototypeStyle.self, forKey: .style) ?? .wireframe
        device = try c.decodeIfPresent(PrototypeDevice.self, forKey: .device)
            ?? PrototypeDeviceKind.iPhone15Pro.preset!
        screens = try c.decodeIfPresent([PrototypeScreen].self, forKey: .screens) ?? []
        startScreenID = try c.decodeIfPresent(String.self, forKey: .startScreenID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    /// 按顺序排列的屏幕。
    public var sortedScreens: [PrototypeScreen] {
        screens.sorted { $0.order < $1.order }
    }

    public func screen(id: String) -> PrototypeScreen? {
        screens.first { $0.id == id }
    }

    /// 起始屏：显式指定优先，否则取顺序第一屏。
    public var resolvedStartScreen: PrototypeScreen? {
        if let startScreenID, let screen = screen(id: startScreenID) { return screen }
        return sortedScreens.first
    }
}

// MARK: - 已解析的屏幕

/// 从磁盘读出的屏幕：元数据 + HTML 正文 + 解析后的路径。
public struct PrototypeResolvedScreen: Equatable, Sendable {
    public let project: PrototypeProject
    public let screen: PrototypeScreen
    /// 屏幕目录（`<project>/<screen-slug>`）。
    public let directoryURL: URL
    public let html: String

    public var htmlURL: URL { directoryURL.appendingPathComponent(screen.htmlFileName) }

    public init(
        project: PrototypeProject,
        screen: PrototypeScreen,
        directoryURL: URL,
        html: String
    ) {
        self.project = project
        self.screen = screen
        self.directoryURL = directoryURL
        self.html = html
    }
}

// MARK: - 跳转解析

extension PrototypeHotspot {
    /// 从 HTML 中解析全部 `data-prototype-link` 声明。
    ///
    /// 结果按出现顺序去重（同一目标屏在多个控件上出现时只记一次）。
    /// `label` 取该控件上的 `data-prototype-label`（可为空）。
    public static func parse(fromHTML html: String) -> [PrototypeHotspot] {
        // 逐个抓取标签，再从标签里取属性，避免跨标签误配。
        let tagPattern = #"<[a-zA-Z][^>]*"# + PrototypeHTMLAttributes.link + #"\s*=\s*["']([^"']+)["'][^>]*>"#
        guard let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: [.caseInsensitive]) else {
            return []
        }
        let labelPattern = PrototypeHTMLAttributes.label + #"\s*=\s*["']([^"']*)["']"#
        let labelRegex = try? NSRegularExpression(pattern: labelPattern, options: [.caseInsensitive])

        var seen = Set<String>()
        var hotspots: [PrototypeHotspot] = []
        let range = NSRange(html.startIndex..., in: html)

        for match in tagRegex.matches(in: html, range: range) {
            guard match.numberOfRanges > 1,
                  let targetRange = Range(match.range(at: 1), in: html) else { continue }
            let target = String(html[targetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty, seen.insert(target).inserted else { continue }

            var label: String?
            if let labelRegex, let tagRange = Range(match.range(at: 0), in: html) {
                let tag = String(html[tagRange])
                let tagNSRange = NSRange(tag.startIndex..., in: tag)
                if let labelMatch = labelRegex.firstMatch(in: tag, range: tagNSRange),
                   labelMatch.numberOfRanges > 1,
                   let valueRange = Range(labelMatch.range(at: 1), in: tag) {
                    let value = String(tag[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty { label = value }
                }
            }
            hotspots.append(PrototypeHotspot(targetScreenID: target, label: label))
        }
        return hotspots
    }

    /// 从 HTML 中提取所有被声明的跳转目标（性能更好，仅需集合时用）。
    public static func declaredTargets(inHTML html: String) -> Set<String> {
        Set(parse(fromHTML: html).map(\.targetScreenID))
    }
}
