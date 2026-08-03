import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

enum PageIndexing {
    static func clampedIndex(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(index, 0), pageCount - 1)
    }
}

// MARK: - ViewModel

@MainActor
public final class PluginViewModel: ObservableObject, SuperLog {
    // MARK: - 属性

    @Published var isPresentingOnboarding = false
    @Published var currentStep = 0
    @Published var isTransitioning = false
    @Published var persistenceErrorMessage: String?

    private let store: PluginStore

    // MARK: - 初始化

    public init(store: PluginStore = .init(pluginId: "Onboarding")) {
        self.store = store
    }

    // MARK: - 计算属性

    private var hasCompletedOnboarding: Bool {
        store.completed
    }

    // MARK: - 公开方法

    public func presentIfNeededOnLaunch() {
        guard !hasCompletedOnboarding else { return }
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        start()
    }

    public func start() {
        currentStep = 0
        isPresentingOnboarding = true
    }

    public func show(forceReset: Bool) {
        if forceReset {
            guard store.setCompleted(false) else {
                persistenceErrorMessage = LumiPluginLocalization.string("Failed to reset onboarding state. Please check if Lumi data directory is writable.", bundle: .module)
                return
            }
        }
        start()
    }

    public func skip() {
        complete()
    }

    public func complete() {
        guard store.setCompleted(true) else {
            persistenceErrorMessage = LumiPluginLocalization.string("Failed to save onboarding state. Please check if Lumi data directory is writable.", bundle: .module)
            return
        }
        isPresentingOnboarding = false
        currentStep = 0
    }

    public func nextStep(totalSteps: Int) {
        guard totalSteps > 0 else {
            complete()
            return
        }
        guard !isTransitioning else { return }

        currentStep = PageIndexing.clampedIndex(currentStep, pageCount: totalSteps)
        if currentStep >= totalSteps - 1 {
            complete()
        } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isTransitioning = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.currentStep = PageIndexing.clampedIndex(self.currentStep + 1, pageCount: totalSteps)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.isTransitioning = false
                }
            }
        }
    }

    public func previousStep() {
        guard !isTransitioning else { return }
        guard currentStep > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.currentStep = max(self.currentStep - 1, 0)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.isTransitioning = false
            }
        }
    }
}
