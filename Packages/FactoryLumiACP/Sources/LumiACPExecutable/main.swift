import FactoryLumiACP
import Foundation

setenv("LUMI_ACP_HEADLESS", "1", 1)

do {
    try FactoryLumiACP.runACPServer()
} catch {
    fputs("ACP_BOOTSTRAP_FAILED \(error)\n", stderr)
    exit(1)
}
