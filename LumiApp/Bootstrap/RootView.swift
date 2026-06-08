import SwiftUI

struct RootView<Content: View>: View {
    @ObservedObject private var container: RootContainer
    private let content: Content

    init(container: RootContainer, @ViewBuilder content: () -> Content) {
        self.container = container
        self.content = content()
    }

    var body: some View {
        content
    }
}
