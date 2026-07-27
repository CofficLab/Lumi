import LumiUI
import SwiftUI

public struct RegistryManagerView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var viewModel = RegistryManagerViewModel()
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LumiPluginLocalization.string("Registry Manager", bundle: .module))
                        .font(.appLargeTitle)
                        .foregroundColor(theme.textPrimary)
                    
                    Text(LumiPluginLocalization.string("Manage all your package registries in one place", bundle: .module))
                        .font(.appBody)
                        .foregroundColor(theme.textSecondary)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320))], spacing: 16) {
                    ForEach(RegistryType.allCases) { type in
                        RegistryCard(type: type, viewModel: viewModel)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.success)
                    Text(viewModel.toastMessage)
                        .font(.appCaption)
                        .foregroundColor(theme.textPrimary)
                }
                .padding()
                .appSurface(style: .panel, cornerRadius: 12)
                .shadow(radius: 5)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring, value: viewModel.showToast)
    }
}
