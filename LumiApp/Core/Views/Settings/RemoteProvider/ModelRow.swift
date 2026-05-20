import SwiftUI
import LumiUI

/// 模型选择行组件 - 支持 hover 效果、选中/默认状态高亮
struct ModelRow: View {
    let model: String
    let isDefault: Bool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        AppListRow(isSelected: isSelected, action: action) {
            HStack(spacing: 8) {
                Text(model)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                
                Spacer()
                
                if isDefault {
                    AppTag("默认", style: .accent)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("双击选择此模型")
    }
    
    private var accessibilityLabel: String {
        var label = model
        if isDefault {
            label += "，默认模型"
        }
        return label
    }
}
