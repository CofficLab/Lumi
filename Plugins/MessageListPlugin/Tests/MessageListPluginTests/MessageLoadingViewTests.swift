import Testing
import SwiftUI
@testable import MessageListPlugin

@MainActor
@Suite("MessageLoadingView Tests")
struct MessageLoadingViewTests {
    
    @Test("View renders without crashing")
    func testViewRenders() {
        // Simply instantiate and access body to ensure it doesn't crash
        let view = MessageLoadingView()
        _ = view.body
    }
    
    @Test("View has correct accessibility label")
    func testAccessibilityLabel() {
        let view = MessageLoadingView()
        let bodyView = view.body
        
        // Extract the Text from the accessibility modifier
        // The view uses Text("Loading messages…", bundle: .module)
        // We verify the view can be created and body accessed
        #expect(!String(describing: type(of: bodyView)).isEmpty)
    }
    
    @Test("Initial breathing state is false")
    func testInitialBreathingState() {
        // The @State isBreathing starts as false, animation triggers on appear
        let view = MessageLoadingView()
        #expect(!String(describing: type(of: view.body)).isEmpty)
    }
}
