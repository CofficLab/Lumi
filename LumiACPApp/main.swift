import Foundation
import FactoryLumiACP

// Headless ACP server entry point.
//
// LumiACPApp is a minimal Xcode app target that directly depends on
// FactoryLumiACP. It replaces the old ACPBootstrap SwiftPM package,
// eliminating the need for a separate Package.resolved and build phase script.
//
// The built executable is embedded into Lumi.app as lumi-acp by the
// "Embed ACP Helper" build phase.

setenv("LUMI_ACP_HEADLESS", "1", 1)

do {
    try FactoryLumiACP.runACPServer()
} catch {
    fputs("ACP_BOOTSTRAP_FAILED \(error)\n", stderr)
    exit(1)
}
