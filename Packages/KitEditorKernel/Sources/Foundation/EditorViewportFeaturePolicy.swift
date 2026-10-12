import Foundation

public enum EditorViewportFeaturePolicy {
    public static func isLongLineProtectionSuppressingSyntaxHighlighting(
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        largeFileMode.isLongLineProtectionEnabled && longestDetectedLine != nil
    }

    public static func isViewportSyntaxFeatureEnabled(
        viewportRange: Range<Int>,
        maxLine: Int,
        largeFileMode: LargeFileMode,
        longestDetectedLine: LongestDetectedLine?
    ) -> Bool {
        guard !isLongLineProtectionSuppressingSyntaxHighlighting(
            largeFileMode: largeFileMode,
            longestDetectedLine: longestDetectedLine
        ) else {
            return false
        }
        return isViewportFeatureEnabled(
            viewportRange: viewportRange,
            maxLine: maxLine
        )
    }

    public static func isViewportFeatureEnabled(viewportRange: Range<Int>, maxLine: Int) -> Bool {
        if maxLine == .max {
            return true
        }
        if viewportRange.isEmpty {
            return true
        }
        return viewportRange.lowerBound < maxLine
    }
}
