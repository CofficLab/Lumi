import CoreGraphics
import Foundation

public struct EditorScrollState: Equatable {
    public var viewportOrigin: CGPoint

    public init(viewportOrigin: CGPoint = .zero) {
        self.viewportOrigin = viewportOrigin
    }
}
