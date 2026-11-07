import CoreGraphics

/// Configurable sizing rules for responsive audio and video player layouts.
///
/// The defaults are a practical starting point for a compact desktop player;
/// applications can supply their own thresholds while sharing the same layout
/// calculations.
public struct AppResponsivePlayerLayoutMetrics: Equatable, Sendable {
    public let minimumWindowSize: CGSize
    public let controlMinimumHeight: CGFloat
    public let contentMinimumHeight: CGFloat
    public let secondaryColumnMinimumWidth: CGFloat
    public let compactStateHeightThreshold: CGFloat
    public let expandedStateHeightThreshold: CGFloat
    public let compactStateHeight: CGFloat
    public let regularStateHeight: CGFloat
    public let expandedStateHeight: CGFloat

    /// Height reserved for the control area while there is no current item to
    /// present, so an empty player does not feel roomy.
    public let emptyControlHeight: CGFloat

    /// Below this window height the secondary column is dropped even if it would
    /// otherwise fit by width alone.
    public let secondaryColumnDropHeightThreshold: CGFloat

    /// Height the secondary column needs before showing it is worthwhile.
    public let secondaryColumnMinimumHeight: CGFloat

    /// Horizontal gap between the control buttons.
    public let controlButtonSpacing: CGFloat

    /// Space reserved beneath the control row, covering the home indicator and
    /// the shadow the row casts.
    public let controlButtonBottomPadding: CGFloat

    /// Smallest and largest diameter a control button may take.
    public let controlButtonMinimumSize: CGFloat
    public let controlButtonMaximumSize: CGFloat

    public init(
        minimumWindowSize: CGSize = CGSize(width: 400, height: 250),
        controlMinimumHeight: CGFloat = 250,
        contentMinimumHeight: CGFloat = 200,
        secondaryColumnMinimumWidth: CGFloat = 768,
        compactStateHeightThreshold: CGFloat = 250,
        expandedStateHeightThreshold: CGFloat = 450,
        compactStateHeight: CGFloat = 24,
        regularStateHeight: CGFloat = 36,
        expandedStateHeight: CGFloat = 48,
        emptyControlHeight: CGFloat = 150,
        secondaryColumnDropHeightThreshold: CGFloat = 270,
        secondaryColumnMinimumHeight: CGFloat = 450,
        controlButtonSpacing: CGFloat = 12,
        controlButtonBottomPadding: CGFloat = 20,
        controlButtonMinimumSize: CGFloat = 44,
        controlButtonMaximumSize: CGFloat = 72
    ) {
        self.minimumWindowSize = minimumWindowSize
        self.controlMinimumHeight = controlMinimumHeight
        self.contentMinimumHeight = contentMinimumHeight
        self.secondaryColumnMinimumWidth = secondaryColumnMinimumWidth
        self.compactStateHeightThreshold = compactStateHeightThreshold
        self.expandedStateHeightThreshold = expandedStateHeightThreshold
        self.compactStateHeight = compactStateHeight
        self.regularStateHeight = regularStateHeight
        self.expandedStateHeight = expandedStateHeight
        self.emptyControlHeight = emptyControlHeight
        self.secondaryColumnDropHeightThreshold = secondaryColumnDropHeightThreshold
        self.secondaryColumnMinimumHeight = secondaryColumnMinimumHeight
        self.controlButtonSpacing = controlButtonSpacing
        self.controlButtonBottomPadding = controlButtonBottomPadding
        self.controlButtonMinimumSize = controlButtonMinimumSize
        self.controlButtonMaximumSize = controlButtonMaximumSize
    }

    public func stateHeight(for windowHeight: CGFloat) -> CGFloat {
        if windowHeight <= compactStateHeightThreshold { return compactStateHeight }
        if windowHeight <= expandedStateHeightThreshold { return regularStateHeight }
        return expandedStateHeight
    }

    /// Height the control row should occupy.
    ///
    /// A compact window still needs room for a tappable button plus the bottom
    /// padding, so the result never falls below that floor.
    public func controlButtonHeight(width: CGFloat, height: CGFloat, maximum: CGFloat = 900) -> CGFloat {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else { return 0 }

        let widthLimitedButtonSize = max(0, (width - controlButtonSpacing * 4) / 5)
        let minimumAreaHeight = min(controlButtonMinimumSize, widthLimitedButtonSize) + controlButtonBottomPadding
        let responsiveHeight = max(0, min(width / 5, maximum, height / 4))

        return max(minimumAreaHeight, responsiveHeight)
    }

    /// Diameter for a control button, constrained by both the width available
    /// for the row and the height reserved for it.
    ///
    /// Reserving space via `controlButtonHeight(width:height:)` and sizing the
    /// button here keeps the hit target and its container from disagreeing.
    public func controlButtonSize(width: CGFloat, areaHeight: CGFloat) -> CGFloat {
        guard width.isFinite, areaHeight.isFinite, width > 0, areaHeight > 0 else { return 0 }

        let widthLimitedButtonSize = max(0, (width - controlButtonSpacing * 4) / 5)
        let heightLimitedButtonSize = max(0, areaHeight - controlButtonBottomPadding)
        return min(controlButtonMaximumSize, widthLimitedButtonSize, heightLimitedButtonSize)
    }

    public func shouldShowSecondaryColumn(width: CGFloat) -> Bool {
        width > secondaryColumnMinimumWidth
    }

    /// Centers content when a platform container proposes a width wider than the
    /// window's actual content area.
    ///
    /// - Returns: The horizontal inset that re-centers the content, or `0` when
    ///   the proposal already fits.
    public func horizontalCenteringOffset(proposedWidth: CGFloat, visibleWidth: CGFloat) -> CGFloat {
        guard proposedWidth.isFinite, visibleWidth.isFinite else { return 0 }
        return max(0, (proposedWidth - max(0, visibleWidth)) / 2)
    }

    public func needsExpandedWindow(for windowHeight: CGFloat) -> Bool {
        windowHeight - controlMinimumHeight <= contentMinimumHeight
    }
}

public extension AppResponsivePlayerLayoutMetrics {
    /// The default layout rules, for views that do not need custom thresholds.
    ///
    /// This is a value type, so reaching for a shared instance avoids rebuilding
    /// the same defaults on every property read.
    static let shared = AppResponsivePlayerLayoutMetrics()
}