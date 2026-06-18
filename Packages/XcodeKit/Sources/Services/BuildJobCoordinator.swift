import Foundation

/// Coordinates user builds with semantic indexing jobs.
@MainActor
public enum BuildJobCoordinator {

  public static func prepareForUserBuild(provider: XcodeBuildContextProvider?) {
    provider?.pauseSemanticIndexingForUserBuild()
    SemanticIndexJobController.shared.cancelCurrentJob()
  }
}
