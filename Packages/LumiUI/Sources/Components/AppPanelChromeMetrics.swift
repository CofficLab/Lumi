import SwiftUI

/// Shared dimensions for editor panel and chat section chrome rows.
public enum AppPanelChromeMetrics {
    public static let tabBarHeight: CGFloat = 40
    public static let tabBarPadding = EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)

    public static let breadcrumbContentHeight: CGFloat = 20
    public static let breadcrumbHorizontalPadding: CGFloat = 10
    public static let breadcrumbVerticalPadding: CGFloat = 4

    public static var breadcrumbBarHeight: CGFloat {
        breadcrumbContentHeight + breadcrumbVerticalPadding * 2
    }
}
