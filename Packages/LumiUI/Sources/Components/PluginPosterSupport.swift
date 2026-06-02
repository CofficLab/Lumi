import SwiftUI

public enum PluginPosterSupport {
    @MainActor
    public static func poster(
        title: String,
        subtitle: String,
        icon: String,
        accent: Color,
        metrics: [AppPluginPosterMetric] = [],
        rows: [String] = [],
        chips: [String] = []
    ) -> AnyView {
        AnyView(
            AppPluginPosterView(
                title: title,
                subtitle: subtitle,
                icon: icon,
                accent: accent,
                metrics: metrics,
                rows: rows,
                chips: chips
            )
        )
    }

    public static func metric(_ value: String, _ label: String) -> AppPluginPosterMetric {
        AppPluginPosterMetric(value: value, label: label)
    }
}
