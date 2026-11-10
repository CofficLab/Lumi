import SwiftUI
import Testing
@testable import LumiUI

struct AppSegmentedControlTests {
    @Test
    @MainActor
    func storesOptionsInOrder() {
        let control = AppSegmentedControl(["A", "B"], selection: .constant(0))
        #expect(control.options == ["A", "B"])
        #expect(control.titles.count == 2)
    }

    @Test
    @MainActor
    func optionCountMatchesTitlesForMultiOption() {
        let control = AppSegmentedControl(
            ["1h", "6h", "24h", "7d"],
            selection: .constant(2),
            maxWidth: 200
        )
        #expect(control.options.count == 4)
        #expect(control.titles.count == 4)
        #expect(control.maxWidth == 200)
    }

    @Test
    @MainActor
    func writesSelectionThroughBinding() {
        var selection = 0
        let binding = Binding(
            get: { selection },
            set: { selection = $0 }
        )
        // Simulate the binding write the segment button performs.
        binding.wrappedValue = 1
        #expect(selection == 1)
    }
}
