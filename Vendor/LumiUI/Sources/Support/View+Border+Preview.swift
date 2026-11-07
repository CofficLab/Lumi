import SwiftUI

#Preview("边框扩展方法示例") {
    ScrollView {
        VStack(spacing: 24) {
            Text("View 边框扩展示例")
                .font(.title)
                .padding()
            
            VStack(spacing: 16) {
                exampleCard("无边框")
                
                exampleCard("顶部边框")
                    .borderTop()
                
                exampleCard("底部边框")
                    .borderBottom()
                
                exampleCard("左侧边框")
                    .borderLeading()
                
                exampleCard("右侧边框")
                    .borderTrailing()
                
                exampleCard("上下边框")
                    .borderVertical()
                
                exampleCard("左右边框")
                    .borderHorizontal()
                
                exampleCard("四周边框")
                    .borderAll()
                
                exampleCard("组合：底部边框 + 中等阴影")
                    .borderBottom()
                    .shadowMd()
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
}
