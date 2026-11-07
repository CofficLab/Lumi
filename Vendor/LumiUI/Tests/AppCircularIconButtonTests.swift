import Testing
@testable import LumiUI

struct AppCircularIconButtonTests {
    @Test
    @MainActor
    func defaultSizeIsTheDenseToolbarSize() {
        let button = AppCircularIconButton(systemImage: "play.fill") {}

        #expect(button.size == 32)
    }
}
