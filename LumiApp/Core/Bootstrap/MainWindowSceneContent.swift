import SwiftUI

/// Owns the per-window container for a SwiftUI window scene.
struct MainWindowSceneContent: View {
    @StateObject private var windowContainer: WindowContainer
    @State private var initialProjectPath: String?

    init(route: Binding<LumiWindowRoute?>) {
        let initialRoute = route.wrappedValue ?? CoreWindowIDStore.consumeDefaultWindowRoute() ?? LumiWindowRoute()
        _windowContainer = StateObject(
            wrappedValue: WindowContainer(
                id: initialRoute.id,
                container: RootContainer.shared,
                projectPath: initialRoute.projectPath
            )
        )
        _initialProjectPath = State(initialValue: initialRoute.projectPath)
    }

    var body: some View {
        ContentLayout(projectPath: initialProjectPath)
            .inRootView(container: windowContainer)
            .restoreCoreWindowIDs()
    }
}
