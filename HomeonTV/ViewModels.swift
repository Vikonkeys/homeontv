import Foundation

struct RoomVM: Identifiable, Equatable {
    let id: UUID
    let name: String
    let accessories: [AccessoryVM]
}

struct AccessoryVM: Identifiable, Equatable {
    let id: UUID
    let name: String
    let roomName: String
    let reachable: Bool
    let servicesSummary: String

    let hasToggle: Bool
    let hasBrightness: Bool
    let hasVolume: Bool
    let hasMute: Bool
    let hasRotationSpeed: Bool
    let hasHue: Bool
    let hasSaturation: Bool
    let hasColorTemperature: Bool

    let toggleState: Bool?
    let brightness: Int?
    let volume: Int?
    let isMuted: Bool?
    let rotationSpeed: Int?
    let hue: Int?
    let saturation: Int?
    let colorTemperature: Int?

    let brightnessRange: ClosedRange<Int>
    let brightnessStep: Int
    let volumeRange: ClosedRange<Int>
    let volumeStep: Int
    let rotationSpeedRange: ClosedRange<Int>
    let rotationSpeedStep: Int
    let hueRange: ClosedRange<Int>
    let hueStep: Int
    let saturationRange: ClosedRange<Int>
    let saturationStep: Int
    let colorTemperatureRange: ClosedRange<Int>
    let colorTemperatureStep: Int

    let lastError: String?
    let lastWriteStatus: String?
}
