import SwiftUI
import MagicKit

struct RegistryManagerView: View {
    @StateObject private var viewModel = RegistryManagerViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Registry Manager")
                        .font(.system(size: 26, weight: .bold))
                    
                    Text("Manage all your package registries in one place")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
        .overlay(alignment: .bottom) {
            if viewModel.showToast {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(viewModel.toastMessage)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring, value: viewModel.showToast)
    }
}
