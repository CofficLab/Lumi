import Foundation

/// Port scanning/kill operations the port manager view model depends on.
///
/// `PortScanner` is the production implementation; tests inject gated stubs
/// to construct out-of-order scan completions (issue #247).
public protocol PortScanning: Sendable {
    func scanPorts() async throws -> [PortInfo]
    func killProcess(_ port: PortInfo) async throws
}

extension PortScanner: PortScanning {}