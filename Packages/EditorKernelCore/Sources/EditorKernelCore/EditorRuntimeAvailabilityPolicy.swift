import Foundation

public enum EditorRuntimeAvailabilityPolicy {
    public static func clampedVisibleRange(
        startLine: Int,
        endLine: Int,
        totalLines: Int
    ) -> Range<Int> {
        let clampedTotalLines = max(0, totalLines)
        let clampedStart = max(0, min(startLine, clampedTotalLines))
        let clampedEnd = max(clampedStart, min(endLine, clampedTotalLines))
        return clampedStart..<clampedEnd
    }

    public static func shouldClearTransientProviders(isPrimaryCursorRendered: Bool) -> Bool {
        !isPrimaryCursorRendered
    }

    public static func shouldClearProvider(isEnabled: Bool) -> Bool {
        !isEnabled
    }
}
