import Foundation

/// Plans and validates user-initiated Build & Run requests for Xcode and SPM projects.
@MainActor
public enum SwiftProjectRunPlanner {

  public static func preflight(
    provider: XcodeBuildContextProvider?,
    projectPath: String?,
    currentFileURL: URL?,
    store: XcodeBuildServerStore,
    fallbackScheme: String? = nil,
    fallbackConfiguration: String? = nil,
    fallbackDestinationQuery: String? = nil
  ) async -> SwiftBuildRunPreflightResult {
    if let provider, let workspace = provider.currentWorkspace {
      let scheme = provider.activeScheme
        ?? fallbackScheme.flatMap { name in workspace.schemes.first { $0.name == name } }
        ?? workspace.schemes.first
      if let scheme {
        return await preflightXcode(provider: provider, workspace: workspace, scheme: scheme, store: store)
      }
    }

    if let projectPath, !projectPath.isEmpty,
       let fallback = await preflightXcodeFromProjectPath(
         projectPath: projectPath,
         provider: provider,
         store: store,
         fallbackScheme: fallbackScheme,
         fallbackConfiguration: fallbackConfiguration,
         fallbackDestinationQuery: fallbackDestinationQuery
       ) {
      return fallback
    }

    if let spmResult = preflightSPM(projectPath: projectPath, currentFileURL: currentFileURL) {
      return spmResult
    }

    return .failed(.unsupportedProject, disabledReason: "Open an Xcode project or Swift package to run.")
  }

  public static func canRun(preflight: SwiftBuildRunPreflightResult) -> Bool {
    preflight.isReady
  }

  // MARK: - Xcode

  private static func preflightXcode(
    provider: XcodeBuildContextProvider,
    workspace: XcodeWorkspaceContext,
    scheme: XcodeSchemeContext,
    store: XcodeBuildServerStore
  ) async -> SwiftBuildRunPreflightResult {
    guard FileManager.default.isExecutableFile(atPath: "/usr/bin/xcodebuild") else {
      return .failed(.toolNotFound("xcodebuild"), disabledReason: "xcodebuild is not available.")
    }

    let destination = provider.activeDestination
      ?? scheme.activeDestination
      ?? XcodeBuildContextProvider.defaultDestination()

    guard destination.platform.lowercased() == "macos"
      || destination.destinationQuery.lowercased().contains("platform=macos") else {
      return .failed(.nonMacOSDestination, disabledReason: "Run is only supported for macOS destinations.")
    }

    guard let runnableTarget = preferredRunnableTarget(in: workspace, scheme: scheme) else {
      return .failed(.noRunnableTarget, disabledReason: "No runnable macOS application target in the active scheme.")
    }

    let configuration = provider.activeConfiguration ?? scheme.activeConfiguration
    let workspaceURL = workspace.path
    let derivedDataPath = store.derivedDataDirectory(forWorkspace: workspaceURL.path)

    return .ready(
      .xcode(
        workspaceURL: workspaceURL,
        scheme: scheme.name,
        configuration: configuration,
        destinationQuery: destination.destinationQuery,
        derivedDataPath: derivedDataPath,
        preferredTargetName: runnableTarget.name
      )
    )
  }

  private static func preferredRunnableTarget(
    in workspace: XcodeWorkspaceContext,
    scheme: XcodeSchemeContext
  ) -> XcodeTargetContext? {
    let allTargets = workspace.projects.flatMap(\.targets)
    let buildableOrder = XcodeBuildContextProvider.buildableTargetOrder(scheme.buildableTargets)

    let candidates = allTargets.filter { target in
      guard scheme.buildableTargets.contains(target.name) || target.name == scheme.name else {
        return false
      }
      return isRunnableApplicationTarget(target, schemeName: scheme.name)
    }

    return candidates.max { lhs, rhs in
      targetPriority(lhs, schemeName: scheme.name, buildableOrder: buildableOrder)
        < targetPriority(rhs, schemeName: scheme.name, buildableOrder: buildableOrder)
    }
  }

  private static func isRunnableApplicationTarget(_ target: XcodeTargetContext, schemeName: String) -> Bool {
    if let productType = target.productType?.lowercased() {
      return isMacOSApplicationProductType(productType)
    }
    // Fallback when pbxproj product type hasn't been loaded yet.
    return target.name == schemeName
  }

  private static func isMacOSApplicationProductType(_ productType: String) -> Bool {
    productType.contains("application")
      && !productType.contains("watchapp")
      && !productType.contains("watchkit")
      && !productType.contains("messages")
      && !productType.contains("tv-app")
      && !productType.contains("on-demand-install")
  }

  private static func targetPriority(
    _ target: XcodeTargetContext,
    schemeName: String,
    buildableOrder: [String: Int]
  ) -> Int {
    var score = 0
    if target.name == schemeName { score += 10_000 }
    if let order = buildableOrder[target.name] { score += 5_000 - order }
    score += productTypePriority(target.productType)
    return score
  }

  private static func productTypePriority(_ productType: String?) -> Int {
    guard let productType = productType?.lowercased() else { return 0 }
    if productType.contains("application") { return 400 }
    if productType.contains("app-extension") || productType.contains("extension") { return 300 }
    if productType.contains("framework") || productType.contains("library") { return 250 }
    if productType.contains("bundle.unit-test") || productType.contains("test") { return 100 }
    return 200
  }

  // MARK: - Xcode Fallback

  private static func preflightXcodeFromProjectPath(
    projectPath: String,
    provider: XcodeBuildContextProvider?,
    store: XcodeBuildServerStore,
    fallbackScheme: String?,
    fallbackConfiguration: String?,
    fallbackDestinationQuery: String?
  ) async -> SwiftBuildRunPreflightResult? {
    let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
    guard let workspaceURL = XcodeProjectResolver.findWorkspace(in: projectURL) else {
      return nil
    }

    let resolver = provider?.resolver ?? XcodeProjectResolver()
    guard let workspace = await resolver.resolve(workspaceURL: workspaceURL) else {
      return nil
    }

    let schemeName = fallbackScheme ?? provider?.activeScheme?.name ?? workspace.schemes.first?.name
    guard let schemeName,
          var scheme = workspace.schemes.first(where: { $0.name == schemeName }) ?? workspace.schemes.first else {
      return .failed(.missingScheme, disabledReason: "Select a scheme before running.")
    }

    if let fallbackConfiguration, !fallbackConfiguration.isEmpty {
      scheme.activeConfiguration = fallbackConfiguration
    }

    let destination = provider?.activeDestination
      ?? scheme.activeDestination
      ?? XcodeBuildContextProvider.defaultDestination()

    var mutableWorkspace = workspace
    mutableWorkspace.activeScheme = scheme
    mutableWorkspace.activeDestination = destination

    return await preflightXcode(
      provider: provider ?? XcodeBuildContextProvider(resolver: resolver, store: store),
      workspace: mutableWorkspace,
      scheme: scheme,
      store: store
    )
  }

  // MARK: - SPM

  private static func preflightSPM(
    projectPath: String?,
    currentFileURL: URL?
  ) -> SwiftBuildRunPreflightResult? {
    guard SPMUserBuildRunner.locateSwiftExecutable() != nil else {
      return .failed(.toolNotFound("swift"), disabledReason: "swift command is not available.")
    }

    let packageRoot: URL?
    if let currentFileURL, let fromFile = SwiftPackageManifestParser.findPackageDirectory(for: currentFileURL) {
      packageRoot = fromFile
    } else if let projectPath, !projectPath.isEmpty {
      let projectURL = URL(fileURLWithPath: projectPath, isDirectory: true)
      packageRoot = SwiftPackageManifestParser.findPackageDirectory(for: projectURL)
        ?? (FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) ? projectURL : nil)
    } else {
      packageRoot = nil
    }

    guard let packageRoot else { return nil }

    let executables = SwiftPackageManifestParser.executableTargetNames(packageRoot: packageRoot)
    guard !executables.isEmpty else {
      return .failed(.noRunnableTarget, disabledReason: "No executable target found in Package.swift.")
    }

    let selectedTarget: String
    if let currentFileURL, let fileTarget = SwiftPackageManifestParser.targetName(forFile: currentFileURL, packageRoot: packageRoot),
       executables.contains(fileTarget) {
      selectedTarget = fileTarget
    } else if executables.count == 1 {
      selectedTarget = executables[0]
    } else {
      return .failed(
        .needsTargetSelection(executables),
        disabledReason: "Multiple executable targets found. Open a file in the target you want to run."
      )
    }

    return .ready(
      .spm(
        packageRoot: packageRoot,
        executableTarget: selectedTarget,
        configuration: "debug"
      )
    )
  }
}
