import Foundation

public struct IconPreset: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let symbolName: String
    public let makeDocument: @Sendable (_ title: String?) -> IconDocument

    public init(
        id: String,
        title: String,
        subtitle: String,
        symbolName: String,
        makeDocument: @escaping @Sendable (_ title: String?) -> IconDocument
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.makeDocument = makeDocument
    }

    public static func == (lhs: IconPreset, rhs: IconPreset) -> Bool {
        lhs.id == rhs.id
    }
}

public enum IconPresetLibrary {
    public static let all: [IconPreset] = [
        gradientSymbol,
        glassTile,
        neonRing,
        developerTool,
        minimalMono,
    ]

    public static func preset(id: String) -> IconPreset? {
        all.first { $0.id == id }
    }

    public static let gradientSymbol = IconPreset(
        id: "gradient-symbol",
        title: "Gradient Symbol",
        subtitle: "Centered SF Symbol over a vivid gradient.",
        symbolName: "sparkles"
    ) { title in
        IconDocument(
            title: title?.isEmpty == false ? title! : "Gradient Symbol",
            background: .linearGradient(
                colors: ["#111827", "#2563eb", "#38bdf8"],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            layers: [
                IconLayer(
                    name: "Glow",
                    shape: .circle(cx: 512, cy: 512, radius: 330),
                    fill: .radialGradient(colors: ["#ffffff55", "#ffffff00"], center: .center, startRadius: 0, endRadius: 330),
                    opacity: 0.72,
                    blurRadius: 8
                ),
                IconLayer(
                    name: "Symbol",
                    shape: .symbol(name: "sparkles", x: 512, y: 512, size: 420, weight: "semibold"),
                    fill: .color("#ffffff"),
                    shadow: IconShadow(color: "#00000055", radius: 32, x: 0, y: 20)
                ),
            ]
        )
    }

    public static let glassTile = IconPreset(
        id: "glass-tile",
        title: "Glass Tile",
        subtitle: "Layered translucent tile for utilities.",
        symbolName: "square.3.layers.3d"
    ) { title in
        IconDocument(
            title: title?.isEmpty == false ? title! : "Glass Tile",
            background: .linearGradient(
                colors: ["#0f172a", "#0d9488", "#99f6e4"],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            layers: [
                IconLayer(
                    name: "Back Plate",
                    shape: .rectangle(x: 212, y: 244, width: 600, height: 560, cornerRadius: 160),
                    fill: .color("#ffffff22"),
                    stroke: IconStroke(color: "#ffffff66", width: 8),
                    transform: IconTransform(rotationDegrees: -8),
                    shadow: IconShadow(color: "#00000044", radius: 36, x: 0, y: 24)
                ),
                IconLayer(
                    name: "Front Plate",
                    shape: .rectangle(x: 252, y: 220, width: 520, height: 584, cornerRadius: 152),
                    fill: .color("#ffffff33"),
                    stroke: IconStroke(color: "#ffffff88", width: 8),
                    shadow: IconShadow(color: "#00000033", radius: 24, x: 0, y: 14)
                ),
                IconLayer(
                    name: "Symbol",
                    shape: .symbol(name: "wand.and.stars", x: 512, y: 512, size: 350, weight: "semibold"),
                    fill: .color("#ffffff"),
                    shadow: IconShadow(color: "#00000055", radius: 22, x: 0, y: 14)
                ),
            ]
        )
    }

    public static let neonRing = IconPreset(
        id: "neon-ring",
        title: "Neon Ring",
        subtitle: "High contrast ring and luminous glyph.",
        symbolName: "bolt.fill"
    ) { title in
        IconDocument(
            title: title?.isEmpty == false ? title! : "Neon Ring",
            background: .linearGradient(colors: ["#020617", "#111827"], startPoint: .top, endPoint: .bottom),
            layers: [
                IconLayer(
                    name: "Outer Ring",
                    shape: .circle(cx: 512, cy: 512, radius: 330),
                    fill: .color("#00000000"),
                    stroke: IconStroke(color: "#22d3ee", width: 52),
                    shadow: IconShadow(color: "#22d3ee88", radius: 42, x: 0, y: 0)
                ),
                IconLayer(
                    name: "Inner Fill",
                    shape: .circle(cx: 512, cy: 512, radius: 250),
                    fill: .radialGradient(colors: ["#0ea5e955", "#02061700"], center: .center, startRadius: 0, endRadius: 260)
                ),
                IconLayer(
                    name: "Bolt",
                    shape: .symbol(name: "bolt.fill", x: 512, y: 512, size: 360, weight: "bold"),
                    fill: .color("#f8fafc"),
                    shadow: IconShadow(color: "#67e8f988", radius: 30, x: 0, y: 0)
                ),
            ]
        )
    }

    public static let developerTool = IconPreset(
        id: "developer-tool",
        title: "Developer Tool",
        subtitle: "Bracket motif for coding and system tools.",
        symbolName: "chevron.left.forwardslash.chevron.right"
    ) { title in
        IconDocument(
            title: title?.isEmpty == false ? title! : "Developer Tool",
            background: .linearGradient(colors: ["#18181b", "#3f3f46", "#0f766e"], startPoint: .topLeading, endPoint: .bottomTrailing),
            layers: [
                IconLayer(
                    name: "Base Capsule",
                    shape: .capsule(x: 174, y: 320, width: 676, height: 384),
                    fill: .color("#ffffff18"),
                    stroke: IconStroke(color: "#ffffff55", width: 8),
                    shadow: IconShadow(color: "#00000066", radius: 34, x: 0, y: 20)
                ),
                IconLayer(
                    name: "Code",
                    shape: .symbol(name: "chevron.left.forwardslash.chevron.right", x: 512, y: 512, size: 430, weight: "bold"),
                    fill: .color("#ecfeff"),
                    shadow: IconShadow(color: "#00000066", radius: 20, x: 0, y: 12)
                ),
            ]
        )
    }

    public static let minimalMono = IconPreset(
        id: "minimal-mono",
        title: "Minimal Mono",
        subtitle: "Quiet monochrome mark for pro apps.",
        symbolName: "circle.hexagongrid.fill"
    ) { title in
        IconDocument(
            title: title?.isEmpty == false ? title! : "Minimal Mono",
            background: .color("#f8fafc"),
            layers: [
                IconLayer(
                    name: "Glyph Backdrop",
                    shape: .circle(cx: 512, cy: 512, radius: 320),
                    fill: .color("#0f172a"),
                    shadow: IconShadow(color: "#00000030", radius: 26, x: 0, y: 18)
                ),
                IconLayer(
                    name: "Glyph",
                    shape: .symbol(name: "circle.hexagongrid.fill", x: 512, y: 512, size: 360, weight: "regular"),
                    fill: .color("#f8fafc")
                ),
            ]
        )
    }
}
