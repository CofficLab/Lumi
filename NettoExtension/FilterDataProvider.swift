import NetworkExtension
import os
import SuperLogKit
import NettoPlugin

class FilterDataProvider: NEFilterDataProvider, SuperLog {
    static let emoji: String = "🎈"

    private var ipc = IPCConnection.shared
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "netto.filter-data-provider")
    private var verbose: Bool = false

    /**
     * Start Filter
     */
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.info("\(Self.t)🚀 startFilter")

        // Filter all network traffic by default so we can manage permissions
        let filterSettings = NEFilterSettings(rules: [], defaultAction: .filterData)

        apply(filterSettings) { error in
            if let applyError = error {
                if self.verbose {
                                    self.logger.error("\(Self.t)Failed to apply filter settings: \(applyError.localizedDescription)")
                }
            } else {
                if self.verbose {
                                    self.logger.info("\(Self.t)🎉 Success to apply filter settings")
                }
            }

            completionHandler(error)
        }
    }

    /**
     * Stop Filter
     */
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("\(Self.t)🤚 stopFilter with reason -> \(reason.rawValue)")
        completionHandler()
    }

    /**
     * Handle New Flow
     */
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        logger.info("\(Self.t)🍋 handleNewFlow")
        
        // Ask the app to prompt the user
        // This is a blocking call (async wait) if we want to pause.
        // IPC promptUser takes a closure.
        // We need to pause the flow and resume it later.
        
        let prompted = self.ipc.promptUser(flow: flow) { (allow: Bool) in
            let userVerdict: NEFilterNewFlowVerdict = allow ? .allow() : .drop()
            self.resumeFlow(flow, with: userVerdict)
        }

        guard prompted else {
            logger.error("\(Self.t)Failed to call promptUser, allowing flow by default")
            return .allow()
        }

        // Pause the flow while waiting for user decision
        return .pause()
    }
    
    // MARK: - Data Handling (Optional, usually for Content Filter not just Firewall)
    
    override func handleInboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        return .allow()
    }

    override func handleOutboundData(from flow: NEFilterFlow, readBytesStartOffset offset: Int, readBytes: Data) -> NEFilterDataVerdict {
        return .allow()
    }

    override func handleInboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
        return .allow()
    }

    override func handleOutboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
        return .allow()
    }
}
