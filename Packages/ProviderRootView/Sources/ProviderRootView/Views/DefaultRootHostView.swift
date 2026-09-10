import Foundation
import LumiUI
import SwiftUI

@MainActor
struct DefaultRootHostView: View {
    let provider: DefaultRootViewProvider
    @LumiTheme private var theme
    @State private var observationRevision = 0
    @State private var observerHandle: (any RootViewObserverHandle)?

    var body: some View {
        VStack(spacing: 0) {
            if let toolbarView = provider.toolbarView {
                toolbarView
                // 与旧版 AppLayoutView 一致：工具栏下方使用主题分隔线。
                AppDivider()
            }

            HStack(spacing: 0) {
                if let activityBarView = provider.activityBarView {
                    activityBarView
                }

                WorkbenchSplitView(provider: provider)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background)
        .appThemedAppearance()
        #if os(macOS)
        .background {
            ThemeWindowAppearanceBridge()
        }
        #endif
        .environmentObject(AppThemeVM.shared)
        #if os(macOS)
            .ignoresSafeArea()
        #endif
        .id(observationRevision)
        .onAppear {
            guard observerHandle == nil else { return }
            observerHandle = provider.addRootViewObserver { event in
                switch event {
                case .toolbarViewChanged, .activityBarViewChanged:
                    observationRevision += 1
                default:
                    break
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }
}
