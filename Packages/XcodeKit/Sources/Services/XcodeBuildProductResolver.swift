import Foundation

/// Resolves runnable build products from Xcode build settings or SPM output directories.
public enum XcodeBuildProductResolver {

  public static func resolveFromBuildSettings(_ settings: [String: String]) -> URL? {
    findBuildProduct(from: settings)
  }

  public static func resolveFromBuildSettings(
    _ allSettings: [[String: String]],
    preferredTargetNames: [String]
  ) -> URL? {
    if let selected = selectSettings(from: allSettings, preferredTargetNames: preferredTargetNames),
       let product = findBuildProduct(from: selected) {
      return product
    }
    for settings in allSettings {
      if let product = findBuildProduct(from: settings) {
        return product
      }
    }
    return nil
  }

  public static func resolveFromDerivedDataDirectory(
    _ derivedDataDirectory: URL,
    configuration: String,
    preferredTargetNames: [String]
  ) -> URL? {
    let fileManager = FileManager.default
    let productsDirectory = derivedDataDirectory
      .appendingPathComponent("Build/Products", isDirectory: true)
      .appendingPathComponent(configuration, isDirectory: true)

    guard fileManager.fileExists(atPath: productsDirectory.path) else {
      return nil
    }

    for name in preferredTargetNames where !name.isEmpty {
      let candidate = productsDirectory.appendingPathComponent("\(name).app", isDirectory: true)
      if isRunnableProduct(at: candidate) {
        return candidate
      }
    }

    guard let entries = try? fileManager.contentsOfDirectory(
      at: productsDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return nil
    }

    let appBundles = entries.filter { entry in
      entry.pathExtension == "app" && isRunnableProduct(at: entry)
    }

    if appBundles.count == 1 {
      return appBundles[0]
    }

    for name in preferredTargetNames where !name.isEmpty {
      if let match = appBundles.first(where: { $0.deletingPathExtension().lastPathComponent == name }) {
        return match
      }
    }

    return appBundles.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
      .first
  }

  public static func resolveFromBuildOutput(
    _ output: String,
    preferredTargetNames: [String],
    derivedDataDirectory: URL? = nil
  ) -> URL? {
    let fileManager = FileManager.default
    var candidates: [URL] = []

    for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
      for rawPath in extractAppBundlePaths(from: String(line)) {
        let url = normalizedProductURL(rawPath, derivedDataDirectory: derivedDataDirectory)
        if fileManager.fileExists(atPath: url.path), isRunnableProduct(at: url) {
          candidates.append(url)
        }
      }
    }

    guard !candidates.isEmpty else { return nil }

    var uniqueCandidates: [URL] = []
    var seen = Set<String>()
    for candidate in candidates {
      let key = candidate.standardizedFileURL.path
      if seen.insert(key).inserted {
        uniqueCandidates.append(candidate.standardizedFileURL)
      }
    }

    for name in preferredTargetNames where !name.isEmpty {
      if let match = uniqueCandidates.first(where: { $0.deletingPathExtension().lastPathComponent == name }) {
        return match
      }
    }

    return uniqueCandidates.last
  }

  public static func resolveXcodeProduct(
    buildSettings: [[String: String]]? = nil,
    derivedDataDirectory: URL? = nil,
    configuration: String? = nil,
    preferredTargetNames: [String] = [],
    buildOutput: String = ""
  ) -> URL? {
    let names = preferredTargetNames.filter { !$0.isEmpty }

    // Prefer plugin-local DerivedData first: user builds always pass -derivedDataPath there.
    if let derivedDataDirectory,
       let configuration,
       let product = resolveFromDerivedDataDirectory(
         derivedDataDirectory,
         configuration: configuration,
         preferredTargetNames: names
       ) {
      return product
    }

    if !buildOutput.isEmpty,
       let product = resolveFromBuildOutput(
         buildOutput,
         preferredTargetNames: names,
         derivedDataDirectory: derivedDataDirectory
       ) {
      return product
    }

    if let buildSettings,
       let product = resolveFromBuildSettings(buildSettings, preferredTargetNames: names) {
      return product
    }

    return nil
  }

  public static func resolveSPMProduct(
    packageRoot: URL,
    targetName: String,
    configuration: String
  ) -> URL? {
    let fileManager = FileManager.default
    let buildDirectory = packageRoot.appendingPathComponent(".build", isDirectory: true)
    let configFolder = configuration.lowercased() == "release" ? "release" : "debug"

    for debugDirectory in candidateBuildDirectories(in: buildDirectory, configFolder: configFolder) {
      for candidate in finalProductCandidates(targetName: targetName, buildDirectory: debugDirectory) {
        if fileManager.fileExists(atPath: candidate.path), isRunnableProduct(at: candidate) {
          return candidate
        }
      }
    }
    return nil
  }

  public static func isRunnableProduct(at url: URL) -> Bool {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return false
    }

    if isDirectory.boolValue {
      let infoPlist = url.appendingPathComponent("Contents/Info.plist")
      return fileManager.fileExists(atPath: infoPlist.path)
    }

    return fileManager.isExecutableFile(atPath: url.path)
  }

  // MARK: - Private

  private static func selectSettings(
    from allSettings: [[String: String]],
    preferredTargetNames: [String]
  ) -> [String: String]? {
    guard !preferredTargetNames.isEmpty else { return allSettings.first }
    for name in preferredTargetNames {
      if let match = allSettings.first(where: { ($0["TARGET_NAME"] ?? $0["PRODUCT_NAME"]) == name }) {
        return match
      }
    }
    return allSettings.first
  }

  private static func findBuildProduct(from settings: [String: String]) -> URL? {
    let fileManager = FileManager.default
    let directoryKeys = ["TARGET_BUILD_DIR", "BUILT_PRODUCTS_DIR", "CONFIGURATION_BUILD_DIR"]
    let productKeys = ["FULL_PRODUCT_NAME", "WRAPPER_NAME", "EXECUTABLE_PATH", "EXECUTABLE_NAME"]

    for directoryKey in directoryKeys {
      guard let directory = settings[directoryKey] else { continue }
      for productKey in productKeys {
        guard let product = settings[productKey] else { continue }
        let candidate: URL
        if product.hasPrefix("/") {
          candidate = URL(fileURLWithPath: product)
        } else {
          candidate = URL(fileURLWithPath: directory).appendingPathComponent(product)
        }
        if fileManager.fileExists(atPath: candidate.path), isRunnableProduct(at: candidate) {
          return candidate
        }
      }
    }
    return nil
  }

  private static func candidateBuildDirectories(in buildDirectory: URL, configFolder: String) -> [URL] {
    let fileManager = FileManager.default
    var directories = [buildDirectory.appendingPathComponent(configFolder, isDirectory: true)]

    guard let entries = try? fileManager.contentsOfDirectory(
      at: buildDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    ) else {
      return directories
    }

    for entry in entries {
      let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
      guard values?.isDirectory == true else { continue }
      let configDirectory = entry.appendingPathComponent(configFolder, isDirectory: true)
      if fileManager.fileExists(atPath: configDirectory.path) {
        directories.append(configDirectory)
      }
    }
    return directories
  }

  private static func finalProductCandidates(targetName: String, buildDirectory: URL) -> [URL] {
    [
      buildDirectory.appendingPathComponent(targetName),
      buildDirectory.appendingPathComponent("\(targetName).app"),
      buildDirectory.appendingPathComponent("lib\(targetName).dylib"),
    ]
  }

  private static func extractAppBundlePaths(from line: String) -> [String] {
    var paths: [String] = []
    var searchStart = line.startIndex

    while searchStart < line.endIndex,
          let appSuffix = line.range(of: ".app", range: searchStart..<line.endIndex) {
      let pathEnd = appSuffix.upperBound
      var index = appSuffix.lowerBound
      var pathStart: String.Index?

      while index > line.startIndex {
        index = line.index(before: index)
        let character = line[index]

        if character == "(" {
          pathStart = line.index(after: index)
          break
        }

        if character == " " {
          if index > line.startIndex, line[line.index(before: index)] == "\\" {
            continue
          }
          pathStart = line.index(after: index)
          break
        }

        if character.isWhitespace {
          pathStart = line.index(after: index)
          break
        }
      }

      if pathStart == nil {
        pathStart = line.startIndex
      }

      let rawPath = String(line[pathStart!..<pathEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
      let path = unescapeXcodebuildPath(rawPath)
      if path.hasPrefix("/"), path.hasSuffix(".app") {
        paths.append(path)
      }
      searchStart = pathEnd
    }

    return paths
  }

  private static func unescapeXcodebuildPath(_ path: String) -> String {
    path
      .replacingOccurrences(of: "\\ ", with: " ")
      .replacingOccurrences(of: "\\(", with: "(")
      .replacingOccurrences(of: "\\)", with: ")")
  }

  private static func normalizedProductURL(_ rawPath: String, derivedDataDirectory: URL?) -> URL {
    let path = unescapeXcodebuildPath(rawPath)
    if path.hasPrefix("/") {
      return URL(fileURLWithPath: path)
    }

    if let derivedDataDirectory {
      let derivedDataPrefix = derivedDataDirectory.standardizedFileURL.path
      if path.hasPrefix(derivedDataPrefix) {
        return URL(fileURLWithPath: path)
      }

      if path.contains("/Build/Products/") {
        if let range = path.range(of: "/DerivedData/") {
          let suffix = String(path[range.lowerBound...])
          if suffix.hasPrefix("/DerivedData/") {
            let relativeToDerivedData = String(suffix.dropFirst("/DerivedData/".count))
            return derivedDataDirectory.appendingPathComponent(relativeToDerivedData)
          }
        }

        if let buildProductsRange = path.range(of: "/Build/Products/") {
          let suffix = String(path[buildProductsRange.lowerBound...])
          return derivedDataDirectory.appendingPathComponent(String(suffix.dropFirst()))
        }
      }
    }

    return URL(fileURLWithPath: path)
  }
}
