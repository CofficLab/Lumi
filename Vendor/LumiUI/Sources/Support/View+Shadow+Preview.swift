import SwiftUI

#Preview("阴影扩展方法示例") {
    ScrollView {
        VStack(spacing: 24) {
            Text("View 阴影扩展示例")
                .font(.title)
                .padding()
            
            VStack(spacing: 16) {
                exampleCard("无阴影")
                    .shadowNone()
                
                exampleCard("极轻微阴影 (.xs)")
                    .shadowXs()
                
                exampleCard("轻微阴影 (.sm)")
                    .shadowSm()
                
                exampleCard("中等阴影 (.md)")
                    .shadowMd()
                
                exampleCard("较强阴影 (.lg)")
                    .shadowLg()
                
                exampleCard("强阴影 (.xl)")
                    .shadowXl()
                
                exampleCard("极强阴影 (.xxl)")
                    .shadowXxl()
                
                exampleCard("超强阴影 (.xxxl)")
                    .shadowXxxl()
            }
            .padding()
        }
    }
    .background(Color.gray.opacity(0.1))
}

private func exampleCard(_ text: String) -> some View {
    Text(text)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
}
