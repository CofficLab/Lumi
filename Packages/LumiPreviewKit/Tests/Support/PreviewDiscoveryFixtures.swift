import Foundation
import LumiPreviewKit

enum PreviewDiscoveryFixtures {
    static func makeDiscovery(
        fileURL: URL = URL(fileURLWithPath: "/tmp/Preview.swift"),
        bodySource: String = "ContentView()",
        title: String = "Preview",
        id: String = "preview-1",
        lineNumber: Int = 1,
        endLineNumber: Int = 3,
        primaryTypeName: String? = "ContentView",
        sourceText: String? = nil
    ) -> LumiPreviewFacade.PreviewDiscovery {
        let resolvedSourceText = sourceText ?? """
        import SwiftUI

        #Preview("\(title)") {
            \(bodySource)
        }
        """
        return LumiPreviewFacade.PreviewDiscovery(
            id: id,
            title: title,
            sourceFileURL: fileURL,
            lineNumber: lineNumber,
            endLineNumber: endLineNumber,
            primaryTypeName: primaryTypeName,
            bodySource: bodySource,
            sourceText: resolvedSourceText
        )
    }
}
