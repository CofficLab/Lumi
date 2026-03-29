import SwiftUI

/// 正在扫描相关文件状态视图
struct AppManagerScanningView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(AppUI.Color.semantic.primary)
                    .symbolRenderingMode(.hierarchical)
                
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(String(localized: "Scanning related files...", table: "AppManager"))
                    .font(.subheadline)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Preview

#Preview("AppManagerScanningView") {
    AppManagerScanningView()
        .frame(width: 400, height: 300)
}
