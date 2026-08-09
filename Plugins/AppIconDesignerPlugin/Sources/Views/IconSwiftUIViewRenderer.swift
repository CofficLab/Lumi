import SwiftUI

public struct IconSwiftUIViewRenderer {
    public init() {}

    @MainActor
    public func view(document: IconDocument) -> some View {
        IconRenderedDocumentView(document: document)
    }
}

struct IconRenderedDocumentView: View {
    let document: IconDocument

    var body: some View {
        GeometryReader { proxy in
            let document = IconDocumentSanitizer.sanitized(document)
            let scale = min(proxy.size.width / document.width, proxy.size.height / document.height)
            let xOffset = (proxy.size.width - document.width * scale) / 2
            let yOffset = (proxy.size.height - document.height * scale) / 2

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(paint(document.background))
                    .frame(width: document.width * scale, height: document.height * scale)
                    .position(x: xOffset + document.width * scale / 2, y: yOffset + document.height * scale / 2)

                ForEach(document.layers) { layer in
                    IconRenderedLayerView(layer: layer, scale: scale)
                        .opacity(layer.opacity)
                        .shadow(
                            color: Color(iconHex: layer.shadow?.color ?? "#00000000"),
                            radius: (layer.shadow?.radius ?? 0) * scale,
                            x: (layer.shadow?.x ?? 0) * scale,
                            y: (layer.shadow?.y ?? 0) * scale
                        )
                        .blur(radius: max(0, layer.blurRadius) * scale)
                        .scaleEffect(layer.transform.scale)
                        .rotationEffect(.degrees(layer.transform.rotationDegrees))
                        .offset(
                            x: xOffset + layer.transform.translateX * scale,
                            y: yOffset + layer.transform.translateY * scale
                        )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func paint(_ paint: IconPaint) -> AnyShapeStyle {
        switch paint {
        case .color(let value):
            return AnyShapeStyle(Color(iconHex: value))
        case .linearGradient(let colors, let startPoint, let endPoint):
            return AnyShapeStyle(
                LinearGradient(
                    colors: colors.map(Color.init(iconHex:)),
                    startPoint: UnitPoint(iconPoint: startPoint),
                    endPoint: UnitPoint(iconPoint: endPoint)
                )
            )
        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            return AnyShapeStyle(
                RadialGradient(
                    colors: colors.map(Color.init(iconHex:)),
                    center: UnitPoint(iconPoint: center),
                    startRadius: startRadius,
                    endRadius: endRadius
                )
            )
        }
    }
}

private struct IconRenderedLayerView: View {
    let layer: IconLayer
    let scale: Double

    var body: some View {
        switch layer.shape {
        case .rectangle(let x, let y, let width, let height, let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius * scale, style: .continuous)
                .fill(paint(layer.fill))
                .overlay(strokeOverlay(width: width, height: height, shape: .rounded(cornerRadius * scale)))
                .frame(width: width * scale, height: height * scale)
                .position(x: (x + width / 2) * scale, y: (y + height / 2) * scale)
        case .circle(let cx, let cy, let radius):
            Circle()
                .fill(paint(layer.fill))
                .overlay(strokeOverlay(width: radius * 2, height: radius * 2, shape: .circle))
                .frame(width: radius * 2 * scale, height: radius * 2 * scale)
                .position(x: cx * scale, y: cy * scale)
        case .capsule(let x, let y, let width, let height):
            Capsule(style: .continuous)
                .fill(paint(layer.fill))
                .overlay(strokeOverlay(width: width, height: height, shape: .capsule))
                .frame(width: width * scale, height: height * scale)
                .position(x: (x + width / 2) * scale, y: (y + height / 2) * scale)
        case .triangle(let x, let y, let width, let height):
            TriangleShape()
                .fill(paint(layer.fill))
                .overlay(strokeOverlay(width: width, height: height, shape: .triangle))
                .frame(width: width * scale, height: height * scale)
                .position(x: (x + width / 2) * scale, y: (y + height / 2) * scale)
        case .line(let x1, let y1, let x2, let y2):
            Path { path in
                path.move(to: CGPoint(x: x1 * scale, y: y1 * scale))
                path.addLine(to: CGPoint(x: x2 * scale, y: y2 * scale))
            }
            .stroke(
                Color(iconHex: layer.stroke?.color ?? layer.fill.hexValue),
                style: StrokeStyle(lineWidth: max(1, (layer.stroke?.width ?? 8) * scale), lineCap: .round)
            )
        case .symbol(let name, let x, let y, let size, let weight):
            Image(systemName: name)
                .resizable()
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size * scale, weight: iconFontWeight(weight)))
                .foregroundStyle(paint(layer.fill))
                .scaledToFit()
                .frame(width: size * scale, height: size * scale)
                .position(x: x * scale, y: y * scale)
        case .text(let value, let x, let y, let size, let weight):
            Text(value)
                .font(.system(size: size * scale, weight: iconFontWeight(weight), design: .rounded))
                .foregroundStyle(paint(layer.fill))
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .position(x: x * scale, y: y * scale)
        }
    }

    private enum StrokeShape {
        case rounded(Double)
        case circle
        case capsule
        case triangle
    }

    @ViewBuilder
    private func strokeOverlay(width: Double, height: Double, shape: StrokeShape) -> some View {
        if let stroke = layer.stroke {
            switch shape {
            case .rounded(let cornerRadius):
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(iconHex: stroke.color), lineWidth: stroke.width * scale)
                    .frame(width: width * scale, height: height * scale)
            case .circle:
                Circle()
                    .stroke(Color(iconHex: stroke.color), lineWidth: stroke.width * scale)
                    .frame(width: width * scale, height: height * scale)
            case .capsule:
                Capsule(style: .continuous)
                    .stroke(Color(iconHex: stroke.color), lineWidth: stroke.width * scale)
                    .frame(width: width * scale, height: height * scale)
            case .triangle:
                TriangleShape()
                    .stroke(Color(iconHex: stroke.color), lineWidth: stroke.width * scale)
                    .frame(width: width * scale, height: height * scale)
            }
        }
    }

    private func paint(_ paint: IconPaint) -> AnyShapeStyle {
        switch paint {
        case .color(let value):
            return AnyShapeStyle(Color(iconHex: value))
        case .linearGradient(let colors, let startPoint, let endPoint):
            return AnyShapeStyle(
                LinearGradient(
                    colors: colors.map(Color.init(iconHex:)),
                    startPoint: UnitPoint(iconPoint: startPoint),
                    endPoint: UnitPoint(iconPoint: endPoint)
                )
            )
        case .radialGradient(let colors, let center, let startRadius, let endRadius):
            return AnyShapeStyle(
                RadialGradient(
                    colors: colors.map(Color.init(iconHex:)),
                    center: UnitPoint(iconPoint: center),
                    startRadius: startRadius * scale,
                    endRadius: endRadius * scale
                )
            )
        }
    }
}

private func iconFontWeight(_ value: String) -> Font.Weight {
    switch value.lowercased() {
    case "ultralight": return .ultraLight
    case "thin": return .thin
    case "light": return .light
    case "medium": return .medium
    case "semibold": return .semibold
    case "bold": return .bold
    case "heavy": return .heavy
    case "black": return .black
    default: return .regular
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
