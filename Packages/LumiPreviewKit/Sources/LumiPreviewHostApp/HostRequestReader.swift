import AppKit
import Foundation

final class HostRequestReader: @unchecked Sendable {
    private weak var host: StdioPreviewHost?

    init(host: StdioPreviewHost) {
        self.host = host
    }

    func start() {
        Thread.detachNewThread { [weak self] in
            self?.readLoop()
        }
    }

    private func readLoop() {
        while let line = readLine() {
            let result = ResponseDataBox()
            let semaphore = DispatchSemaphore(value: 0)

            Task { @MainActor [weak self] in
                if let host = self?.host {
                    result.data = host.handleLine(line)
                } else {
                    result.data = Data(#"{"message":"Preview host is no longer available."}"#.utf8)
                }
                semaphore.signal()
            }

            semaphore.wait()
            FileHandle.standardOutput.write(result.data)
            FileHandle.standardOutput.write(Data([0x0A]))
        }

        Task { @MainActor in
            NSApplication.shared.terminate(nil)
        }
    }
}

private final class ResponseDataBox: @unchecked Sendable {
    var data = Data()
}
