import Foundation

enum PluginAboutContentBuilder {
    struct Content: Sendable {
        let features: [PluginAboutView.Feature]
        let steps: [String]
        let tips: [String]
    }

    static func make(
        icon: String,
        displayName: String,
        description: String,
        kind: PluginAboutContentKind,
        locale: Locale
    ) -> Content {
        let bundle = Bundle.module
        func text(_ key: String) -> String {
            LumiPluginLocalization.string(key, bundle: bundle, locale: locale)
        }
        func format(_ key: String, _ arguments: CVarArg...) -> String {
            String(format: text(key), locale: locale, arguments: arguments)
        }

        let secondary: (String, String)
        let tertiary: (String, String)
        let steps: [String]
        let tips: [String]

        switch kind {
        case .general:
            secondary = ("about.general.feature.integration.title", "about.general.feature.integration.description")
            tertiary = ("about.general.feature.configurable.title", "about.general.feature.configurable.description")
            steps = [
                format("about.general.step.enable", displayName),
                text("about.general.step.register"),
                text("about.general.step.use"),
            ]
            tips = [
                text("about.general.tip.toggle"),
                text("about.general.tip.settings"),
            ]
        case .manager:
            secondary = ("about.manager.feature.ui.title", "about.manager.feature.ui.description")
            tertiary = ("about.manager.feature.configurable.title", "about.manager.feature.configurable.description")
            steps = [
                format("about.manager.step.enable", displayName),
                text("about.manager.step.open"),
                text("about.manager.step.manage"),
            ]
            tips = [
                text("about.manager.tip.permissions"),
                text("about.manager.tip.disable"),
            ]
        case .editorBottom:
            secondary = ("about.editorBottom.feature.panel.title", "about.editorBottom.feature.panel.description")
            tertiary = ("about.editorBottom.feature.context.title", "about.editorBottom.feature.context.description")
            steps = [
                text("about.editorBottom.step.enable"),
                text("about.editorBottom.step.openFile"),
                text("about.editorBottom.step.openTab"),
            ]
            tips = [
                text("about.editorBottom.tip.shortcut"),
                text("about.editorBottom.tip.layout"),
            ]
        case .editorRail:
            secondary = ("about.editorRail.feature.rail.title", "about.editorRail.feature.rail.description")
            tertiary = ("about.editorRail.feature.context.title", "about.editorRail.feature.context.description")
            steps = [
                text("about.editorRail.step.enable"),
                text("about.editorRail.step.openFile"),
                text("about.editorRail.step.openTab"),
            ]
            tips = [
                text("about.editorRail.tip.collapse"),
                text("about.editorRail.tip.combine"),
            ]
        case .editor:
            secondary = ("about.editor.feature.extension.title", "about.editor.feature.extension.description")
            tertiary = ("about.editor.feature.language.title", "about.editor.feature.language.description")
            steps = [
                text("about.editor.step.enable"),
                text("about.editor.step.openFile"),
                text("about.editor.step.use"),
            ]
            tips = [
                text("about.editor.tip.enable"),
                text("about.editor.tip.tooling"),
            ]
        case .openIn:
            secondary = ("about.openIn.feature.access.title", "about.openIn.feature.access.description")
            tertiary = ("about.openIn.feature.project.title", "about.openIn.feature.project.description")
            steps = [
                text("about.openIn.step.enable"),
                text("about.openIn.step.openProject"),
                text("about.openIn.step.launch"),
            ]
            tips = [
                text("about.openIn.tip.installed"),
                text("about.openIn.tip.path"),
            ]
        }

        let secondaryDescription: String
        if kind == .general {
            secondaryDescription = format("about.general.feature.integration.description", displayName)
        } else {
            secondaryDescription = text(secondary.1)
        }

        return Content(
            features: [
                .init(icon: icon, title: displayName, description: description),
                .init(icon: secondaryFeatureIcon(for: kind), title: text(secondary.0), description: secondaryDescription),
                .init(icon: "gearshape", title: text(tertiary.0), description: text(tertiary.1)),
            ],
            steps: steps,
            tips: tips
        )
    }

    private static func secondaryFeatureIcon(for kind: PluginAboutContentKind) -> String {
        switch kind {
        case .general: "puzzlepiece.extension"
        case .manager: "slider.horizontal.3"
        case .editorBottom: "rectangle.bottomhalf.inset.filled"
        case .editorRail: "sidebar.left"
        case .editor: "chevron.left.forwardslash.chevron.right"
        case .openIn: "arrow.up.right.square"
        }
    }
}
