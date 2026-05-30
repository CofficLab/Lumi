import SwiftUI

/// Owns the per-window container for a SwiftUI window scene.
struct MainWindowSceneContent: View {
    @StateObject private var windowContainer: WindowContainer
    @State private var initialProjectPath: String?

    init() {
        self.init(route: CoreWindowIDStore.consumeNextWindowRoute())
    }

    init(route: Binding<LumiWindowRoute?>) {
        self.init(route: route.wrappedValue ?? CoreWindowIDStore.consumeNextWindowRoute())
    }

    init(route initialRoute: LumiWindowRoute) {
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
