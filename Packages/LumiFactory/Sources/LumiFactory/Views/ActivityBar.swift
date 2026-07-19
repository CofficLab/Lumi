import LumiKernel
import SwiftUI

/// 活动栏 - 显示所有视图容器的图标
struct ActivityBar: View {
    @ObservedObject var kernel: LumiKernel
    @Binding var activeContainerID: String?

    var body: some View {
        VStack(spacing: 6) {
            ForEach(kernel.allViewContainers) { container in
                ActivityBarButton(
                    systemImage: container.systemImage,
                    label: container.title,
                    isActive: activeContainerID == container.id
                ) {
                    activeContainerID = container.id
                }
            }

            Spacer()

            // 设置按钮
            Button {
                // TODO: 打开设置窗口
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ActivityBarButton: View {
    let systemImage: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .foregroundColor(isActive ? .accentColor : .secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(label)
    }
}