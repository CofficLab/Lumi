import Foundation

/// Decides how to rebuild a stale semantic compile database.
public enum SemanticIndexRebuildPolicy {
    public enum Strategy: Equatable, Sendable {
        case skip
        case parseFromDerivedDataOnly
        case cleanBuildAndParse
        /// An incremental `xcodebuild build` (no `clean`) whose parsed result is merged into the
        /// existing `.compile`. Used when the project structure changed (pbxproj / Package.resolved)
        /// but the DerivedData is still valid, so only the affected targets need recompiling.
        case incrementalBuildAndMerge
    }

    public static func strategy(
        manifest: IndexManifest?,
        inputs: IndexManifest.InputFingerprints,
        scheme: String,
        configuration: String,
        destination: String
    ) -> Strategy {
        // No manifest → nothing to merge into, so the first build must be a (clean) full build that
        // produces a complete `.compile` from scratch.
        guard let manifest else { return .cleanBuildAndParse }

        if manifest.scheme == scheme,
           manifest.configuration == configuration,
           manifest.destination == destination,
           manifest.inputs == inputs,
           manifest.hasValidCompileDatabase {
            return .skip
        }

        // Project structure changed but we already have a database to merge into → recompile only the
        // affected targets (incremental) and merge, instead of a costly clean full rebuild.
        if manifest.inputs.pbxprojHash != inputs.pbxprojHash
            || manifest.inputs.packageResolvedHash != inputs.packageResolvedHash {
            return .incrementalBuildAndMerge
        }

        if manifest.scheme != scheme
            || manifest.configuration != configuration
            || manifest.destination != destination {
            return .parseFromDerivedDataOnly
        }

        return .incrementalBuildAndMerge
    }
}
