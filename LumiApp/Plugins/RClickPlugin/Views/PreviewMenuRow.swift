import SwiftUI

struct PreviewMenuRow: View {
    let item: RClickMenuItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.iconName)
                .font(.system(size: 14))
                .frame(width: 16)
                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            Text(item.title)
                .font(.system(size: 13))
                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

            Spacer()

            if item.type == .newFile {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "98989E"))
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}
