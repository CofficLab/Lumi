import Foundation
import LumiCoreKit
import LumiUI
import SwiftUI

public enum PortManagerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let category: LumiPluginCategory = .system
    public static let iconName = "arrow.up.arrow.down.circle"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.port-manager",
        displayName: "Port Manager",
        description: "Inspect local listening ports.",
        order: 43
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                PortManagerView()
            }
        ]
    }
}

private struct PortManagerView: View {
    @LumiTheme private var theme
    @State private var ports: [PortInfo] = []
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var filteredPorts: [PortInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return ports }
        return ports.filter { port in
            port.port.localizedCaseInsensitiveContains(query)
                || port.command.localizedCaseInsensitiveContains(query)
                || port.pid.localizedCaseInsensitiveContains(query)
                || port.user.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                AppSearchBar(text: $searchText, placeholder: "搜索端口、PID 或进程")
                    .frame(maxWidth: 420)

                Text("\(filteredPorts.count) listening ports")
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                AppButton("Refresh", systemImage: "arrow.clockwise", size: .small) {
                    refresh()
                }
                .disabled(isLoading)
            }
            .padding(16)
            .background(theme.appToolbarBackground)

            Divider()

            if isLoading && ports.isEmpty {
                AppLoadingOverlay(message: "Loading Ports", size: .medium)
            } else if let errorMessage {
                AppEmptyState(
                    icon: "network.slash",
                    title: "Ports Unavailable",
                    description: errorMessage,
                    actionTitle: "Refresh",
                    action: refresh
                )
            } else if filteredPorts.isEmpty {
                AppEmptyState(
                    icon: "network",
                    title: "No Listening Ports",
                    description: "No listening ports matched the current filter."
                )
            } else {
                List(filteredPorts) { port in
                    PortRow(port: port)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(theme.appWindowBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if ports.isEmpty {
                refresh()
            }
        }
    }

    private func refresh() {
        isLoading = true
        Task.detached {
            let result = Result { try PortScanner.scanPorts() }
            await MainActor.run {
                switch result {
                case let .success(ports):
                    self.ports = ports
                    self.errorMessage = nil
                case let .failure(error):
                    self.ports = []
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }
}

private struct PortRow: View {
    @LumiTheme private var theme
    let port: PortInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.title3)
                .foregroundStyle(theme.primary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(theme.appAccentSoftFill))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(port.command)
                        .font(.appBodyEmphasized)
                        .foregroundStyle(theme.textPrimary)
                    Text(":\(port.port)")
                        .font(.appCaptionEmphasized)
                        .monospacedDigit()
                        .foregroundStyle(theme.primary)
                }

                Text("\(port.protocolName)  \(port.address)  PID \(port.pid)  \(port.user)")
                    .font(.appCaption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appSurface(style: .listRow, cornerRadius: 8)
    }
}

private struct PortInfo: Identifiable, Hashable, Sendable {
    let id: String
    let command: String
    let pid: String
    let user: String
    let protocolName: String
    let port: String
    let address: String
}

private enum PortScanner {
    static func scanPorts() throws -> [PortInfo] {
        let output = try run("/usr/sbin/lsof", arguments: ["-iTCP", "-sTCP:LISTEN", "-n", "-P"])
        return parseLsofOutput(output)
    }

    private static func run(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ""
            }
            throw PortScannerError.scanFailed(error.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output
    }

    private static func parseLsofOutput(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines.dropFirst() {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 8 else { continue }
            guard let protoIndex = parts.firstIndex(where: { $0 == "TCP" || $0 == "UDP" }) else { continue }
            guard let address = listeningAddress(in: parts[(protoIndex + 1)...]) else { continue }

            let command = parts[0]
            let pid = parts[1]
            let user = parts[2]
            let proto = parts[protoIndex]
            let id = "\(pid)-\(proto)-\(address.raw)"

            ports.append(
                PortInfo(
                    id: id,
                    command: command,
                    pid: pid,
                    user: user,
                    protocolName: proto,
                    port: address.port,
                    address: address.raw
                )
            )
        }

        return ports.sorted {
            (Int($0.port) ?? .max, $0.command) < (Int($1.port) ?? .max, $1.command)
        }
    }

    private static func listeningAddress(in parts: ArraySlice<String>) -> (raw: String, port: String)? {
        for part in parts {
            let address = part.trimmingCharacters(in: CharacterSet(charactersIn: ","))
            guard let port = port(from: address) else { continue }
            return (address, port)
        }
        return nil
    }

    private static func port(from address: String) -> String? {
        if address.hasPrefix("[") {
            guard let closeBracket = address.lastIndex(of: "]") else { return nil }
            let separatorIndex = address.index(after: closeBracket)
            guard separatorIndex < address.endIndex, address[separatorIndex] == ":" else { return nil }
            let portStart = address.index(after: separatorIndex)
            guard portStart < address.endIndex else { return nil }
            let port = String(address[portStart...])
            return Int(port) == nil ? nil : port
        }

        guard let separatorIndex = address.lastIndex(of: ":") else { return nil }
        let portStart = address.index(after: separatorIndex)
        guard portStart < address.endIndex else { return nil }
        let port = String(address[portStart...])
        return Int(port) == nil ? nil : port
    }
}

private enum PortScannerError: LocalizedError {
    case scanFailed(String)

    var errorDescription: String? {
        switch self {
        case let .scanFailed(message):
            message
        }
    }
}
