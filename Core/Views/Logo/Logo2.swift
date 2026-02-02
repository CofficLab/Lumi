import MagicKit
import SwiftUI

/// 方案二：精灵助手主题
/// 概念：小精灵/魔法助手，亲切友好的感觉
struct Logo2: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let faceSize = size * 0.8
            
            ZStack {
                // 头部
                Circle()
                    .fill(Color(red: 0.6, green: 0.9, blue: 0.95)) // 柔和的淡蓝色
                    .shadow(radius: 5)
                
                // 脸部表情
                VStack(spacing: faceSize * 0.1) {
                    // 眼睛
                    HStack(spacing: faceSize * 0.3) {
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: faceSize * 0.15, height: faceSize * 0.15)
                        Circle()
                            .fill(Color.black.opacity(0.8))
                            .frame(width: faceSize * 0.15, height: faceSize * 0.15)
                    }
                    .padding(.top, faceSize * 0.2)
                    
                    // 微笑
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addQuadCurve(to: CGPoint(x: faceSize * 0.3, y: 0), control: CGPoint(x: faceSize * 0.15, y: faceSize * 0.15))
                    }
                    .stroke(Color.black.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: faceSize * 0.3, height: faceSize * 0.1)
                }
            }
            .frame(width: faceSize, height: faceSize)
            .position(x: size / 2, y: size / 2)
        }
    }
}

#Preview("Logo2 - Elf Assistant") {
    Logo2()
        .frame(width: 200, height: 200)
}
