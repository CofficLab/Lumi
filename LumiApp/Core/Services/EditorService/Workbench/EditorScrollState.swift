import Foundation
import CoreGraphics

struct EditorScrollState: Equatable {
    var viewportOrigin: CGPoint

    init(viewportOrigin: CGPoint = .zero) {
        self.viewportOrigin = viewportOrigin
    }
}
