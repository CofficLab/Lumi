import EditorBreadcrumbPlugin
import EditorService
import EditorStickySymbolBarPlugin
import EditorTabStripPlugin
import SwiftUI

struct EditorHeaderView: View {
    let service: EditorService

    var body: some View {
        VStack(spacing: 0) {
            EditorTabHeaderView(service: service)
            Divider()
            BreadcrumbNavHeaderView(service: service)
            EditorStickySymbolBarHeaderView(service: service)
        }
    }
}
