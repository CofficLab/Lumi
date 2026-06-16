import EditorService
import Foundation
import LumiCoreKit
import SwiftUI
import XcodeKit

@MainActor
enum XcodeProjectStatusPresentation {
    enum SemanticStatusAppearance: Equatable {
        case indexing
        case unknown
        case resolving
        case available
        case unavailable
        case needsResync
    }

    static func makeSemanticReport(
        snapshot: XcodeEditorContextSnapshot?,
        cachedState: BridgeCachedState?,
        buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    ) -> XcodeSemanticAvailability.Report {
        localizedSemanticReport(
            XcodeSemanticAvailability.inspectCurrentFileContext(
                snapshot: snapshot,
                cachedState: cachedState,
                buildContextStatus: buildContextStatus
            )
        )
    }

    static func semanticStatusText(
        indexingTask: ProgressTask?,
        buildContextStatus: XcodeBuildContextProvider.BuildContextStatus,
        resolutionProgress: BuildContextResolutionProgress? = nil,
        now: Date = Date()
    ) -> String {
        if let indexingTask {
            return localizedIndexingTaskText(indexingTask)
        }
        if case .resolving = buildContextStatus, let resolutionProgress {
            return localizedResolutionProgressText(resolutionProgress, now: now)
        }
        return localizedSemanticStatusText(for: buildContextStatus)
    }

    static func semanticStatusDescription(
        indexingTask: ProgressTask?,
        buildContextStatusDescription: String,
        resolutionProgress: BuildContextResolutionProgress? = nil,
        now: Date = Date()
    ) -> String {
        if let indexingTask {
            var parts = [LumiPluginLocalization.string("Swift semantic indexing in progress", bundle: .module)]
            if !indexingTask.title.isEmpty {
                parts.append(indexingTask.title)
            }
            if let message = indexingTask.message, !message.isEmpty {
                parts.append(message)
            }
            return parts.joined(separator: " · ")
        }
        if let resolutionProgress {
            return localizedResolutionProgressDetail(resolutionProgress, now: now)
        }
        return buildContextStatusDescription
    }

    static func resolvingSchemePlaceholder(
        activeScheme: String?,
        resolutionProgress: BuildContextResolutionProgress?
    ) -> String {
        if let activeScheme {
            return activeScheme
        }
        if let resolutionProgress {
            return localizedResolutionProgressText(resolutionProgress)
        }
        return LumiPluginLocalization.string("Resolving build context...", bundle: .module)
    }

    static func localizedResolutionProgressText(
        _ progress: BuildContextResolutionProgress,
        now: Date = Date()
    ) -> String {
        var text = localizedResolutionPhaseTitle(progress.phase)
        if let currentItem = progress.currentItem, !currentItem.isEmpty {
            text += " · \(currentItem)"
        } else if let detail = progress.detail, !detail.isEmpty {
            text += " · \(detail)"
        }
        if progress.showsElapsedTime(at: now) {
            let elapsed = BuildContextResolutionProgress.formattedElapsed(since: progress.startedAt, now: now)
            text += " (\(elapsed))"
        }
        return text
    }

    static func localizedResolutionProgressDetail(
        _ progress: BuildContextResolutionProgress,
        now: Date = Date()
    ) -> String {
        var parts = [localizedResolutionPhaseTitle(progress.phase)]
        if let detail = progress.detail, !detail.isEmpty {
            parts.append(detail)
        }
        if let currentItem = progress.currentItem, !currentItem.isEmpty {
            parts.append(currentItem)
        }
        if progress.showsElapsedTime(at: now) {
            let elapsed = BuildContextResolutionProgress.formattedElapsed(since: progress.startedAt, now: now)
            parts.append(
                String(
                    format: LumiPluginLocalization.string("Elapsed %@", bundle: .module),
                    elapsed
                )
            )
        }
        return parts.joined(separator: " · ")
    }

    static func localizedResolutionPhaseTitle(_ phase: BuildContextResolutionProgress.Phase) -> String {
        switch phase {
        case .locatingWorkspace:
            return LumiPluginLocalization.string("Locating workspace...", bundle: .module)
        case .discoveringSchemes:
            return LumiPluginLocalization.string("Discovering schemes...", bundle: .module)
        case .parsingProjectMembership:
            return LumiPluginLocalization.string("Parsing project membership...", bundle: .module)
        case .runningXcodebuildList:
            return LumiPluginLocalization.string("Running xcodebuild -list...", bundle: .module)
        case .selectingScheme:
            return LumiPluginLocalization.string("Selecting scheme...", bundle: .module)
        case .generatingBuildServer:
            return LumiPluginLocalization.string("Generating buildServer.json...", bundle: .module)
        }
    }

    static func semanticStatusAppearance(
        isIndexing: Bool,
        isResolving: Bool = false,
        buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    ) -> SemanticStatusAppearance {
        if isIndexing { return .indexing }
        if isResolving { return .resolving }
        switch buildContextStatus {
        case .unknown: return .unknown
        case .resolving: return .resolving
        case .available: return .available
        case .unavailable: return .unavailable
        case .needsResync: return .needsResync
        }
    }

    static func color(for appearance: SemanticStatusAppearance) -> Color {
        switch appearance {
        case .indexing: return .blue
        case .unknown: return .gray
        case .resolving: return .yellow
        case .available: return .green
        case .unavailable: return .red
        case .needsResync: return .orange
        }
    }

    static func localizedSemanticReport(
        _ report: XcodeSemanticAvailability.Report
    ) -> XcodeSemanticAvailability.Report {
        XcodeSemanticAvailability.Report(
            reasons: report.reasons.map(localizedSemanticReason(_:))
        )
    }

    static func localizedSemanticReason(
        _ reason: XcodeSemanticAvailability.Reason
    ) -> XcodeSemanticAvailability.Reason {
        XcodeSemanticAvailability.Reason(
            id: reason.id,
            severity: reason.severity,
            title: localizedSemanticReasonTitle(reason),
            message: localizedSemanticReasonMessage(reason)
        )
    }

    static func localizedSemanticReasonTitle(
        _ reason: XcodeSemanticAvailability.Reason
    ) -> String {
        switch reason.id {
        case "server-not-started":
            return LumiPluginLocalization.string("LSP Not Initialized", bundle: .module)
        case "build-context-unavailable":
            return LumiPluginLocalization.string("Build Context Unavailable", bundle: .module)
        case "build-context-resync":
            return LumiPluginLocalization.string("Build Context Needs Sync", bundle: .module)
        case "file-not-in-target":
            return LumiPluginLocalization.string("File Not in Target", bundle: .module)
        case "scheme-excludes-targets":
            return LumiPluginLocalization.string("Scheme Does Not Cover File Target", bundle: .module)
        case "multiple-targets-resolved":
            return LumiPluginLocalization.string("Multi-Target File", bundle: .module)
        case "multiple-targets-ambiguous":
            return LumiPluginLocalization.string("Multi-Target Ambiguity", bundle: .module)
        case "destination-unknown":
            return LumiPluginLocalization.string("Destination Undetermined", bundle: .module)
        default:
            return reason.title
        }
    }

    static func localizedSemanticReasonMessage(
        _ reason: XcodeSemanticAvailability.Reason
    ) -> String {
        switch reason.id {
        case "server-not-started":
            return LumiPluginLocalization.string("The current Xcode project context has not yet completed initialization.", bundle: .module)
        case "build-context-resync":
            return LumiPluginLocalization.string("The current build context has expired, workspace semantic results may be inaccurate.", bundle: .module)
        case "destination-unknown":
            return LumiPluginLocalization.string("The current target platform has not yet been resolved.", bundle: .module)
        case "build-context-unavailable":
            return localizedBuildContextStatusDescription(reason.message)
        case "file-not-in-target":
            let fileName = extractSingleQuotedValue(from: reason.message) ?? ""
            return String(
                format: LumiPluginLocalization.string("'%@' does not belong to any compilation target.", bundle: .module),
                fileName
            )
        case "scheme-excludes-targets":
            if let match = reason.message.firstMatch(of: #/Current scheme \'(.+)\' does not include (.+)\./#) {
                return String(
                    format: LumiPluginLocalization.string("Current scheme '%@' does not include %@.", bundle: .module),
                    String(match.1),
                    String(match.2)
                )
            }
            return reason.message
        case "multiple-targets-resolved":
            if let target = extractSingleQuotedValue(from: reason.message) {
                return String(
                    format: LumiPluginLocalization.string("Current file matches multiple targets, currently resolving with '%@'.", bundle: .module),
                    target
                )
            }
            return reason.message
        case "multiple-targets-ambiguous":
            if let match = reason.message.firstMatch(of: #/Current file belongs to (.+), but current scheme cannot uniquely determine semantic context\./#) {
                return String(
                    format: LumiPluginLocalization.string("Current file belongs to %@, but current scheme cannot uniquely determine semantic context.", bundle: .module),
                    String(match.1)
                )
            }
            return reason.message
        default:
            return reason.message
        }
    }

    static func extractSingleQuotedValue(from text: String) -> String? {
        text.firstMatch(of: #/'([^']+)'/#).map { String($0.1) }
    }

    static func localizedBuildContextStatusDescription(
        _ status: XcodeBuildContextProvider.BuildContextStatus
    ) -> String {
        switch status {
        case .unknown:
            return LumiPluginLocalization.string("Unknown", bundle: .module)
        case .resolving:
            return LumiPluginLocalization.string("Resolving build context...", bundle: .module)
        case .available(let config):
            return String(
                format: LumiPluginLocalization.string("Available (scheme: %@)", bundle: .module),
                config.scheme
            )
        case .unavailable(let reason):
            return String(
                format: LumiPluginLocalization.string("Unavailable: %@", bundle: .module),
                reason
            )
        case .needsResync:
            return LumiPluginLocalization.string("Needs resync", bundle: .module)
        }
    }

    static func localizedBuildContextStatusDescription(_ text: String) -> String {
        if let match = text.firstMatch(of: #/Available \(scheme: (.+)\)/#) {
            return String(
                format: LumiPluginLocalization.string("Available (scheme: %@)", bundle: .module),
                String(match.1)
            )
        }
        if let match = text.firstMatch(of: #/Unavailable: (.+)/#) {
            return String(
                format: LumiPluginLocalization.string("Unavailable: %@", bundle: .module),
                String(match.1)
            )
        }
        switch text {
        case "Unknown":
            return LumiPluginLocalization.string("Unknown", bundle: .module)
        case "Resolving build context...":
            return LumiPluginLocalization.string("Resolving build context...", bundle: .module)
        case "Needs resync":
            return LumiPluginLocalization.string("Needs resync", bundle: .module)
        case "Not Initialized":
            return LumiPluginLocalization.string("Not Initialized", bundle: .module)
        default:
            return text
        }
    }

    static func localizedIndexingTaskText(_ indexingTask: ProgressTask) -> String {
        if let percentage = indexingTask.percentage {
            return String(
                format: LumiPluginLocalization.string("Indexing %d%%", bundle: .module),
                Int(percentage)
            )
        }
        if let message = indexingTask.message, !message.isEmpty {
            return message
        }
        return indexingTask.title.isEmpty
            ? LumiPluginLocalization.string("Indexing...", bundle: .module)
            : indexingTask.title
    }

    static func localizedSemanticStatusText(
        for buildContextStatus: XcodeBuildContextProvider.BuildContextStatus
    ) -> String {
        switch buildContextStatus {
        case .unknown:
            return LumiPluginLocalization.string("Not Detected", bundle: .module)
        case .resolving:
            return LumiPluginLocalization.string("Resolving...", bundle: .module)
        case .available:
            return LumiPluginLocalization.string("Ready", bundle: .module)
        case .unavailable:
            return LumiPluginLocalization.string("Error", bundle: .module)
        case .needsResync:
            return LumiPluginLocalization.string("Needs Sync", bundle: .module)
        }
    }
}
