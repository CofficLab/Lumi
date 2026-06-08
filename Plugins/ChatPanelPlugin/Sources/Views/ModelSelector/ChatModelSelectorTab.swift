import Foundation

enum ChatModelSelectorTab: Equatable {
    case current
    case frequent
    case fast
    case auto
    case availability
    case all
    case provider(String)
}
