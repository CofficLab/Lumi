import SwiftUI

struct GlassCard<Content: View>: View {
    var content: Content
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 16
    var material: Material = .ultraThinMaterial
    var hasBorder: Bool = true
    
    init(padding: CGFloat = 16, cornerRadius: CGFloat = 16, material: Material = .ultraThinMaterial, hasBorder: Bool = true, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.material = material
        self.hasBorder = hasBorder
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // 毛玻璃背景
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(material)
                    
                    // 额外的半透明白色层，增加亮度，模拟玻璃质感
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.05))
                }
            )
            .overlay(
                // 渐变边框，增加精致感
                Group {
                    if hasBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .white.opacity(0.1),
                                        .black.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.2)
        GlassCard {
            Text("Glass Card Content")
                .padding()
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}
