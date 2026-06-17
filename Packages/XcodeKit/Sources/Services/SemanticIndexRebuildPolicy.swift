import Foundation

/// Decides how to rebuild a stale semantic compile database.
public enum SemanticIndexRebuildPolicy {
    public enum Strategy: Equatable, Sendable {
        case skip
        case parseFromDerivedDataOnly
        case cleanBuildAndParse
    }

    public static func strategy(
        manifest: IndexManifest?,
        inputs: IndexManifest.InputFingerprints,
        scheme: String,
        configuration: String,
        destination: String
    ) -> Strategy {
        guard let manifest else { return .cleanBuildAndParse }

        if manifest.scheme == scheme,
           manifest.configuration == configuration,
           manifest.destination == destination,
           manifest.inputs == inputs,
           manifest.hasValidCompileDatabase {
            return .skip
        }

        if manifest.inputs.pbxprojHash != inputs.pbxprojHash
            || manifest.inputs.packageResolvedHash != inputs.packageResolvedHash {
            return .cleanBuildAndParse
        }

        if manifest.scheme != scheme
            || manifest.configuration != configuration
            || manifest.destination != destination {
            return .parseFromDerivedDataOnly
        }

        return .cleanBuildAndParse
    }
}
