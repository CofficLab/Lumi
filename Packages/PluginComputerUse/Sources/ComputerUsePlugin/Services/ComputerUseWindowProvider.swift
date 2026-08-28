import AppKit
import CoreGraphics
import Foundation

enum ComputerUseWindowProvider {
    @MainActor
    static func availableWindows() -> [ComputerUseWindow] {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        return rawWindows.compactMap { raw -> ComputerUseWindow? in
            guard let number = raw[kCGWindowNumber] as? NSNumber,
                  let pidNumber = raw[kCGWindowOwnerPID] as? NSNumber,
                  let layer = raw[kCGWindowLayer] as? NSNumber,
                  layer.intValue == 0,
                  let boundsValue = raw[kCGWindowBounds]
            else { return nil }
            let boundsDictionary = boundsValue as! CFDictionary
            guard let frame = CGRect(dictionaryRepresentation: boundsDictionary),
                  frame.width >= 80,
                  frame.height >= 60
            else { return nil }

            let pid = pid_t(pidNumber.int32Value)
            guard pid != ownPID,
                  let application = NSRunningApplication(processIdentifier: pid),
                  application.activationPolicy == .regular,
                  let bundleIdentifier = application.bundleIdentifier,
                  !bundleIdentifier.isEmpty
            else { return nil }

            let applicationName = application.localizedName
                ?? (raw[kCGWindowOwnerName] as? String)
                ?? bundleIdentifier
            let title = (raw[kCGWindowName] as? String) ?? ""
            return ComputerUseWindow(
                id: CGWindowID(number.uint32Value),
                processIdentifier: pid,
                bundleIdentifier: bundleIdentifier,
                applicationName: applicationName,
                windowTitle: title,
                frame: frame
            )
        }
    }

    static func select(
        from windows: [ComputerUseWindow],
        application: String?,
        windowTitle: String?,
        frontmostBundleIdentifier: String?
    ) -> ComputerUseWindow? {
        let appQuery = application?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let titleQuery = windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = windows.filter { window in
            let matchesApplication = appQuery.map { query in
                window.bundleIdentifier.lowercased() == query
                    || window.applicationName.lowercased().contains(query)
            } ?? true
            let matchesTitle = titleQuery.map { query in
                window.windowTitle.lowercased().contains(query)
            } ?? true
            return matchesApplication && matchesTitle
        }
        if appQuery == nil, titleQuery == nil, let frontmostBundleIdentifier,
           let frontmost = matches.first(where: { $0.bundleIdentifier == frontmostBundleIdentifier }) {
            return frontmost
        }
        return matches.first
    }
}
