import SwiftUI
import Testing
@testable import LumiUI

struct AppMetadataCardTests {
    @Test
    @MainActor
    func metadataRowPreservesDisplayConfiguration() {
        let row = AppMetadataRow(title: "URL", systemImage: "link", labelWidth: 128) {
            Text("https://example.com")
        }

        #expect(row.title == "URL")
        #expect(row.systemImage == "link")
        #expect(row.labelWidth == 128)
    }
}
