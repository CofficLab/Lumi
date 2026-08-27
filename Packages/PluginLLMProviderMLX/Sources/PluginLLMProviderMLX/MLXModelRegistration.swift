/// A model that can be downloaded from Hugging Face and loaded by MLXLMCommon.
public struct MLXModelRegistration: Sendable, Equatable, Identifiable {
    public let id: String
    public let displayName: String
    public let series: String
    public let providerID: String
    public let contextWindowSize: Int
    public let minimumRAMGB: Int
    public let supportsVision: Bool
    public let supportsTools: Bool

    public init(
        id: String,
        displayName: String,
        series: String,
        providerID: String,
        contextWindowSize: Int = 32_768,
        minimumRAMGB: Int = 8,
        supportsVision: Bool = false,
        supportsTools: Bool = true
    ) {
        self.id = id
        self.displayName = displayName
        self.series = series
        self.providerID = providerID
        self.contextWindowSize = contextWindowSize
        self.minimumRAMGB = minimumRAMGB
        self.supportsVision = supportsVision
        self.supportsTools = supportsTools
    }
}
