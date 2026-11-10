import SwiftUI

/// The silhouette used by a skeleton placeholder.
public enum AppSkeletonShape: Equatable {
    case rectangle
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
    case circle
}

/// A theme-aware placeholder block for composing content-shaped loading states.
public struct AppSkeletonBlock: View {
    @LumiTheme private var theme

    private let width: CGFloat?
    private let height: CGFloat
    private let shape: AppSkeletonShape
    private let color: Color?
    private let isActive: Bool

    public init(
        width: CGFloat? = nil,
        height: CGFloat = 12,
        shape: AppSkeletonShape = .roundedRectangle(cornerRadius: 3),
        color: Color? = nil,
        isActive: Bool = true
    ) {
        self.width = width
        self.height = height
        self.shape = shape
        self.color = color
        self.isActive = isActive
    }

    public var body: some View {
        skeletonShape
            .fill(color ?? theme.textSecondary.opacity(0.13))
            .frame(width: resolvedWidth, height: height)
            .shimmer(isActive: isActive)
            .accessibilityHidden(true)
    }

    private var skeletonShape: AnyShape {
        switch shape {
        case .rectangle:
            AnyShape(Rectangle())
        case let .roundedRectangle(cornerRadius):
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .capsule:
            AnyShape(Capsule())
        case .circle:
            AnyShape(Circle())
        }
    }

    private var resolvedWidth: CGFloat? {
        if let width { return width }
        if shape == .circle { return height }
        return nil
    }
}

#Preview("Skeleton placeholders") {
    VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
            AppSkeletonBlock(width: 36, height: 36, shape: .circle)
            AppSkeletonText(lineWidths: [0.7, 0.42], lineHeight: 9)
        }
        AppSkeletonText(lineWidths: [1, 0.92, 0.64], lineHeight: 10)
        HStack(spacing: 8) {
            AppSkeletonBlock(width: 60, height: 20, shape: .capsule)
            AppSkeletonBlock(width: 60, height: 20, shape: .capsule)
        }
    }
    .padding()
    .frame(width: 280)
}

/// A group of skeleton lines whose widths are fractions of the available width.
public struct AppSkeletonText: View {
    private let lineWidths: [CGFloat]
    private let lineHeight: CGFloat
    private let lineSpacing: CGFloat
    private let isActive: Bool

    public init(
        lineWidths: [CGFloat] = [1, 0.78],
        lineHeight: CGFloat = 10,
        lineSpacing: CGFloat = 7,
        isActive: Bool = true
    ) {
        self.lineWidths = lineWidths
        self.lineHeight = lineHeight
        self.lineSpacing = lineSpacing
        self.isActive = isActive
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: lineSpacing) {
                ForEach(Array(lineWidths.enumerated()), id: \.offset) { _, width in
                    AppSkeletonBlock(
                        width: geometry.size.width * min(max(width, 0), 1),
                        height: lineHeight,
                        isActive: isActive
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(height: CGFloat(lineWidths.count) * lineHeight + CGFloat(max(lineWidths.count - 1, 0)) * lineSpacing)
        .accessibilityHidden(true)
    }
}
