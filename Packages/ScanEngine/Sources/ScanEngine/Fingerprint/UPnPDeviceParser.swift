import Foundation

public struct UPnPDeviceInfo: Sendable, Equatable {
    public var friendlyName: String?
    public var manufacturer: String?
    public var modelName: String?
    public var modelNumber: String?
    public var serialNumber: String?
    public var deviceType: String?

    public init(
        friendlyName: String? = nil,
        manufacturer: String? = nil,
        modelName: String? = nil,
        modelNumber: String? = nil,
        serialNumber: String? = nil,
        deviceType: String? = nil
    ) {
        self.friendlyName = friendlyName
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
        self.deviceType = deviceType
    }

    public var isEmpty: Bool {
        [friendlyName, manufacturer, modelName, modelNumber, serialNumber, deviceType]
            .allSatisfy { $0 == nil }
    }
}

public enum UPnPDeviceParser: Sendable {
    public static func parse(_ xml: String) -> UPnPDeviceInfo {
        UPnPDeviceInfo(
            friendlyName: tag("friendlyName", in: xml),
            manufacturer: tag("manufacturer", in: xml),
            modelName: tag("modelName", in: xml),
            modelNumber: tag("modelNumber", in: xml),
            serialNumber: tag("serialNumber", in: xml),
            deviceType: tag("deviceType", in: xml)
        )
    }

    public static func locationURL(from evidencePayload: String) -> URL? {
        let trimmed = evidencePayload.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("http") {
            return URL(string: trimmed)
        }
        return nil
    }

    private static func tag(_ name: String, in xml: String) -> String? {
        let pattern = "<\(name)[^>]*>([^<]*)</\(name)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let valueRange = Range(match.range(at: 1), in: xml)
        else {
            return nil
        }
        let value = xml[valueRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : String(value.prefix(200))
    }
}
