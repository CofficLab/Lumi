import CoreGraphics
import Foundation
import IOKit
import os
import SuperLogKit

private let ddcLog = Logger(subsystem: "com.coffic.lumi", category: "plugin.display-control.ddc")

// MARK: - Private API Declarations

@_silgen_name("DisplayServicesGetBrightness")
func _DisplayServicesGetBrightness(_: CGDirectDisplayID, _: UnsafeMutablePointer<Float>) -> Int32

@_silgen_name("DisplayServicesSetBrightness")
func _DisplayServicesSetBrightness(_: CGDirectDisplayID, _: Float) -> Int32

// CoreDisplay_DisplayCreateInfoDictionary follows Create rule — returns retained CFDictionary (or NULL).
@_silgen_name("CoreDisplay_DisplayCreateInfoDictionary")
func _CoreDisplay_DisplayCreateInfoDictionary(_: CGDirectDisplayID) -> CFDictionary?

@_silgen_name("IOAVServiceWriteI2C")
func _IOAVServiceWriteI2C(_: CFTypeRef, _: UInt32, _: UInt32, _: UnsafePointer<UInt8>, _: UInt32) -> Bool

@_silgen_name("IOAVServiceReadI2C")
func _IOAVServiceReadI2C(_: CFTypeRef, _: UInt32, _: UInt32, _: UnsafeMutablePointer<UInt8>, _: UInt32) -> Bool

// IOAVServiceCreateWithService is a private IOKit function.
// It follows the Core Foundation "Create" rule — returns a retained CFTypeRef or NULL.
// We use dlsym to call it dynamically to avoid @_silgen_name ABI issues that cause crashes.
// Note: allocator param should be NULL (not kCFAllocatorDefault) since kCFAllocatorDefault is nil on macOS.
private let ioAVServiceCreateWithService: (@convention(c) (UnsafeRawPointer?, io_service_t) -> UnsafeRawPointer?) = {
    let sym = dlsym(dlopen(nil, RTLD_LAZY), "IOAVServiceCreateWithService")!
    return unsafeBitCast(sym, to: (@convention(c) (UnsafeRawPointer?, io_service_t) -> UnsafeRawPointer?).self)
}()

// MARK: - DDC VCP Codes

private enum DDCVCPCode: UInt8 {
    case luminance = 0x10
    case contrast = 0x12
    case backlightControlLegacy = 0x13
    case audioSpeakerVolume = 0x62
    case audioMuteScreenBlank = 0x8D

    static func candidates(for control: DisplayControlKind) -> [DDCVCPCode] {
        switch control {
        case .brightness: [.luminance, .backlightControlLegacy]
        case .contrast: [.contrast]
        case .volume: [.audioSpeakerVolume]
        }
    }
}

// MARK: - DDC Service (stored per display)

private struct DDCService {
    let displayID: CGDirectDisplayID
    let service: CFTypeRef
    let serviceLocation: Int
    let matchScore: Int
}

private struct RegistryService {
    var edidUUID = ""
    var productName = ""
    var serialNumber: Int64 = 0
    var ioDisplayLocation = ""
    var service: CFTypeRef?
    var serviceLocation = 0
}

// MARK: - DisplayDDCBridge

final class DisplayDDCBridge: SuperLog, @unchecked Sendable {
    private var servicesByDisplayID: [CGDirectDisplayID: DDCService] = [:]
    private var maxValues: [ControlKey: UInt16] = [:]
    private var controlCodes: [ControlKey: DDCVCPCode] = [:]
    private let maxDetectLimit: UInt16 = 100

    func refresh(displayIDs: [CGDirectDisplayID]) {
        servicesByDisplayID = Arm64DDCMatcher().matchedServices(for: displayIDs)
    }

    func hasService(for displayID: CGDirectDisplayID) -> Bool {
        servicesByDisplayID[displayID] != nil
    }

    func read(_ control: DisplayControlKind, displayID: CGDirectDisplayID) -> Double? {
        guard let service = servicesByDisplayID[displayID] else {
            return nil
        }

        let key = ControlKey(displayID: displayID, control: control)
        for vcp in orderedCandidates(for: key) {
            guard let values = DDCTransport.read(service: service.service, vcpCode: vcp.rawValue),
                  values.max > 0
            else {
                continue
            }

            let effectiveMax = min(values.max, maxDetectLimit)
            let effectiveCurrent = min(values.current, effectiveMax)
            maxValues[key] = effectiveMax
            controlCodes[key] = vcp

            let percentage = Double(effectiveCurrent) / Double(effectiveMax) * 100
            return min(100, max(0, percentage))
        }

        return nil
    }

    func write(_ value: Double, for control: DisplayControlKind, displayID: CGDirectDisplayID) -> Bool {
        guard let service = servicesByDisplayID[displayID] else {
            return false
        }

        let key = ControlKey(displayID: displayID, control: control)
        let maxValue = maxValues[key] ?? maxDetectLimit
        var ddcValue = UInt16((min(100, max(0, value)) / 100 * Double(maxValue)).rounded())
        if control == .volume, value > 0 {
            ddcValue = max(1, ddcValue)
        }

        // Handle mute for volume control
        if control == .volume {
            let muteValue: UInt16 = value > 0 ? 2 : 1
            let muteSuccess = DDCTransport.write(
                service: service.service,
                vcpCode: DDCVCPCode.audioMuteScreenBlank.rawValue,
                value: muteValue
            )
            if value <= 0, muteSuccess {
                return true
            }
        }

        for vcp in orderedCandidates(for: key) {
            let success = DDCTransport.write(service: service.service, vcpCode: vcp.rawValue, value: ddcValue)
            if success {
                controlCodes[key] = vcp
                return true
            }
        }

        return false
    }

    private func orderedCandidates(for key: ControlKey) -> [DDCVCPCode] {
        let candidates = DDCVCPCode.candidates(for: key.control)
        guard let preferred = controlCodes[key], candidates.contains(preferred) else {
            return candidates
        }
        return [preferred] + candidates.filter { $0 != preferred }
    }
}

// MARK: - DDC Transport (I2C)

private enum DDCTransport {
    private static let sevenBitAddress: UInt8 = 0x37
    private static let dataAddress: UInt8 = 0x51

    static func read(service: CFTypeRef, vcpCode: UInt8) -> (current: UInt16, max: UInt16)? {
        var send = [vcpCode]
        var reply = [UInt8](repeating: 0, count: 11)
        guard communicate(service: service, send: &send, reply: &reply) else {
            return nil
        }
        let maxValue = (UInt16(reply[6]) << 8) + UInt16(reply[7])
        let currentValue = (UInt16(reply[8]) << 8) + UInt16(reply[9])
        return (currentValue, maxValue)
    }

    static func write(service: CFTypeRef, vcpCode: UInt8, value: UInt16) -> Bool {
        var send = [vcpCode, UInt8(value >> 8), UInt8(value & 0xFF)]
        var reply: [UInt8] = []
        return communicate(service: service, send: &send, reply: &reply)
    }

    private static func communicate(
        service: CFTypeRef,
        send: inout [UInt8],
        reply: inout [UInt8]
    ) -> Bool {
        var packet = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send + [0]
        let checksumSeed = send.count == 1
            ? Self.sevenBitAddress << 1
            : Self.sevenBitAddress << 1 ^ Self.dataAddress
        packet[packet.count - 1] = checksum(seed: checksumSeed, data: packet, start: 0, end: packet.count - 2)

        var success = false
        for _ in 0..<5 {
            for _ in 0..<2 {
                usleep(10_000)
                let packetCount = UInt32(packet.count)
                success = packet.withUnsafeMutableBufferPointer { buffer in
                    guard let baseAddress = buffer.baseAddress else { return false }
                    return _IOAVServiceWriteI2C(
                        service,
                        UInt32(Self.sevenBitAddress),
                        UInt32(Self.dataAddress),
                        baseAddress,
                        packetCount
                    )
                }
            }

            if reply.isEmpty {
                if success { return true }
            } else {
                usleep(50_000)
                let replyCount = UInt32(reply.count)
                success = reply.withUnsafeMutableBufferPointer { buffer in
                    guard let baseAddress = buffer.baseAddress else { return false }
                    return _IOAVServiceReadI2C(
                        service,
                        UInt32(Self.sevenBitAddress),
                        0,
                        baseAddress,
                        replyCount
                    )
                }
                if success, reply.count >= 2 {
                    success = checksum(seed: 0x50, data: reply, start: 0, end: reply.count - 2) == reply[reply.count - 1]
                }
                if success { return true }
            }

            usleep(20_000)
        }

        return false
    }

    private static func checksum(seed: UInt8, data: [UInt8], start: Int, end: Int) -> UInt8 {
        guard start <= end else { return seed }
        var value = seed
        for index in start...end {
            value ^= data[index]
        }
        return value
    }
}

// MARK: - Arm64 DDC Matcher

private final class Arm64DDCMatcher {
    private static let maxMatchScore = 20

    func matchedServices(for displayIDs: [CGDirectDisplayID]) -> [CGDirectDisplayID: DDCService] {
        let registryServices = registryServicesForMatching()
        var candidatesByScore: [Int: [DDCService]] = [:]

        for displayID in displayIDs where CGDisplayIsBuiltin(displayID) == 0 {
            for registryService in registryServices {
                let score = matchScore(displayID: displayID, registryService: registryService)
                guard score > 0, let service = registryService.service else {
                    continue
                }
                let candidate = DDCService(
                    displayID: displayID,
                    service: service,
                    serviceLocation: registryService.serviceLocation,
                    matchScore: score
                )
                candidatesByScore[score, default: []].append(candidate)
            }
        }

        var matched: [CGDirectDisplayID: DDCService] = [:]
        var usedDisplayIDs: Set<CGDirectDisplayID> = []
        var usedLocations: Set<Int> = []

        for score in stride(from: Self.maxMatchScore, through: 1, by: -1) {
            guard let candidates = candidatesByScore[score] else { continue }
            for candidate in candidates {
                guard !usedDisplayIDs.contains(candidate.displayID),
                      !usedLocations.contains(candidate.serviceLocation)
                else {
                    continue
                }
                matched[candidate.displayID] = candidate
                usedDisplayIDs.insert(candidate.displayID)
                usedLocations.insert(candidate.serviceLocation)
            }
        }

        ddcLog.debug("DDC: Matched \(matched.count) services from \(registryServices.count) registry services")
        return matched
    }

    /// Safety wrapper for creating AV service — logs failures instead of crashing.
    /// Passes NULL for the allocator (kCFAllocatorDefault is nil on macOS, meaning "use default").
    private func safeCreateAVService(entry: io_service_t) -> CFTypeRef? {
        guard let rawPtr = ioAVServiceCreateWithService(nil, entry) else {
            ddcLog.warning("DDC: IOAVServiceCreateWithService returned nil for entry")
            return nil
        }
        // The C function follows Create rule — returns a retained CF object.
        // We bridge it back to a CFTypeRef via Unmanaged.
        let unmanaged = Unmanaged<CFTypeRef>.fromOpaque(rawPtr)
        return unmanaged.takeRetainedValue()
    }

    private func registryServicesForMatching() -> [RegistryService] {
        var services: [RegistryService] = []
        var serviceLocation = 0
        var current = RegistryService()
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != IO_OBJECT_NULL else { return [] }
        defer { IOObjectRelease(root) }

        var iterator = io_iterator_t()
        guard IORegistryEntryCreateIterator(
            root,
            kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        ) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        let framebufferNames = ["AppleCLCD2", "IOMobileFramebufferShim"]
        let serviceName = "DCPAVServiceProxy"

        while let object = nextObject(namedLike: framebufferNames + [serviceName], iterator: &iterator) {
            defer { IOObjectRelease(object.entry) }

            if framebufferNames.contains(object.name) {
                current = registryDisplayProperties(entry: object.entry)
                serviceLocation += 1
                current.serviceLocation = serviceLocation
            } else if object.name == serviceName {
                attachAVService(entry: object.entry, to: &current)
                if current.service != nil {
                    services.append(current)
                }
            }
        }

        return services
    }

    private func nextObject(
        namedLike names: [String],
        iterator: inout io_iterator_t
    ) -> (name: String, entry: io_service_t)? {
        let namePointer = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
        defer { namePointer.deallocate() }

        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != IO_OBJECT_NULL,
                  IORegistryEntryGetName(entry, namePointer) == KERN_SUCCESS
            else {
                return nil
            }

            let name = String(cString: namePointer)
            if names.contains(where: { name.contains($0) }) {
                return (name, entry)
            }
            IOObjectRelease(entry)
        }
    }

    private func registryDisplayProperties(entry: io_service_t) -> RegistryService {
        var service = RegistryService()

        if let unmanagedValue = IORegistryEntryCreateCFProperty(
            entry,
            "EDID UUID" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        ), let value = unmanagedValue.takeRetainedValue() as? String {
            service.edidUUID = value
        }

        let path = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
        defer { path.deallocate() }
        if IORegistryEntryGetPath(entry, kIOServicePlane, path) == KERN_SUCCESS {
            service.ioDisplayLocation = String(cString: path)
        }

        if let unmanagedAttributes = IORegistryEntryCreateCFProperty(
            entry,
            "DisplayAttributes" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        ), let attributes = unmanagedAttributes.takeRetainedValue() as? NSDictionary {
            if let productAttributes = attributes["ProductAttributes"] as? NSDictionary {
                service.productName = productAttributes["ProductName"] as? String ?? ""
                service.serialNumber = productAttributes["SerialNumber"] as? Int64 ?? 0
            }
        }

        return service
    }

    private func attachAVService(entry: io_service_t, to service: inout RegistryService) {
        guard let unmanagedLocation = IORegistryEntryCreateCFProperty(
            entry,
            "Location" as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively)
        ), let location = unmanagedLocation.takeRetainedValue() as? String,
           location == "External",
           let avService = safeCreateAVService(entry: entry)
        else {
            return
        }

        service.service = avService
    }

    private func matchScore(displayID: CGDirectDisplayID, registryService: RegistryService) -> Int {
        guard let infoDict = _CoreDisplay_DisplayCreateInfoDictionary(displayID) else {
            return 0
        }
        let info = infoDict as NSDictionary
        var score = 0

        if let location = info[kIODisplayLocationKey] as? String,
           !registryService.ioDisplayLocation.isEmpty,
           location == registryService.ioDisplayLocation {
            score += 10
        }

        if let productNames = info["DisplayProductName"] as? [String: String],
           let displayName = productNames["en_US"] ?? productNames.first?.value,
           !registryService.productName.isEmpty,
           displayName.lowercased() == registryService.productName.lowercased() {
            score += 1
        }

        if let serial = info[kDisplaySerialNumber] as? Int64,
           serial != 0,
           serial == registryService.serialNumber {
            score += 1
        }

        for searchKey in edidSearchKeys(from: info) {
            let prefix = registryService.edidUUID.prefix(searchKey.location + 4)
            guard searchKey.value != "0000",
                  prefix.suffix(4) == searchKey.value
            else {
                continue
            }
            score += 1
        }

        return score
    }

    private func edidSearchKeys(from info: NSDictionary) -> [(value: String, location: Int)] {
        guard let vendorID = info[kDisplayVendorID] as? Int64,
              let productID = info[kDisplayProductID] as? Int64,
              let week = info[kDisplayWeekOfManufacture] as? Int64,
              let year = info[kDisplayYearOfManufacture] as? Int64,
              let horizontalSize = info[kDisplayHorizontalImageSize] as? Int64,
              let verticalSize = info[kDisplayVerticalImageSize] as? Int64
        else {
            return []
        }

        let product = UInt16(max(0, min(productID, 65_535)))
        return [
            (String(format: "%04X", UInt16(max(0, min(vendorID, 65_535)))), 0),
            (
                String(format: "%02X", UInt8((product >> 0) & 0xFF))
                    + String(format: "%02X", UInt8((product >> 8) & 0xFF)),
                4
            ),
            (
                String(format: "%02X", UInt8(max(0, min(week, 255))))
                    + String(format: "%02X", UInt8(max(0, min(year - 1990, 255)))),
                19
            ),
            (
                String(format: "%02X", UInt8(max(0, min(horizontalSize / 10, 255))))
                    + String(format: "%02X", UInt8(max(0, min(verticalSize / 10, 255)))),
                30
            )
        ]
    }
}
