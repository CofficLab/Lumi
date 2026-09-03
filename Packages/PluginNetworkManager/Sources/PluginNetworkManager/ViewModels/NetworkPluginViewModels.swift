import Foundation
import Combine

@MainActor
final class NetworkHistoryViewModel: ObservableObject {
    @Published private(set) var recentHistory: [NetworkDataPoint] = []
    @Published private(set) var longTermHistory: [NetworkDataPoint] = []

    func apply(recent: [NetworkDataPoint], longTerm: [NetworkDataPoint]) {
        recentHistory = recent
        longTermHistory = longTerm
    }
}

@MainActor
final class NetworkPluginViewModels {
    let network = NetworkManagerViewModel()
    let history = NetworkHistoryViewModel()
}
