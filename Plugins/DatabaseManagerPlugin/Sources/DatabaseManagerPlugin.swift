import LumiCoreKit
import LumiUI
import os
import SwiftUI
import SuperLogKit

public enum DatabaseManagerPlugin: LumiPlugin {
    public static let verbose: Bool = true

    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.database-manager")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.database-manager",
        displayName: LumiPluginLocalization.string("Database", bundle: .module),
        description: LumiPluginLocalization.string("Manage SQLite, MySQL, PostgreSQL, and Redis", bundle: .module),
        order: 50,
        category: .general,
        policy: .disabled,
        stage: .beta,
        iconName: "server.rack",
    )

    @MainActor
    public static func viewContainers(context: any LumiCoreAccessing) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                DatabaseMainView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: any LumiCoreAccessing) -> [any LumiAgentTool] {
        [
            DatabaseListConnectionsTool(),
            DatabaseDescribeSchemaTool(),
            DatabaseReadonlyQueryTool(),
            DatabaseSampleTableTool(),
        ]
    }

    @MainActor
    public static func pluginAboutView(context: any LumiCoreAccessing) -> AnyView? {
        AnyView(DatabaseManagerAboutView())
    }

    @MainActor
    public static func onboardingPages(context: any LumiCoreAccessing) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "server.rack",
                            title: LumiPluginLocalization.string("Multiple engines", bundle: .module),
                            description: LumiPluginLocalization.string("SQLite, MySQL, PostgreSQL, and Redis", bundle: .module)
                        ),
                        .init(
                            icon: "tablecells",
                            title: LumiPluginLocalization.string("Browse data", bundle: .module),
                            description: LumiPluginLocalization.string("Inspect schemas and run read-only queries", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("Open Database from the sidebar to connect to a server.", bundle: .module)
                )
            )
        ]
    }
}
