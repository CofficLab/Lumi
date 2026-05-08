import SwiftUI

public struct ErrorIconView: View {
    let size: CGFloat
    let weight: Font.Weight

    public init(size: CGFloat = 16, weight: Font.Weight = .medium) {
        self.size = size
        self.weight = weight
    }

    public var body: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: size, weight: weight))
            .foregroundColor(AppUI.Color.semantic.error)
    }
}
