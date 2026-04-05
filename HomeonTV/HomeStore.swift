import Foundation
import Combine
import HomeKit

@MainActor
final class HomeStore: NSObject, ObservableObject {
    @Published var authorizationStatus: HMHomeManagerAuthorizationStatus = .determined
    @Published var homes: [HMHome] = []
    @Published var selectedHomeID: UUID?
    @Published var roomVMs: [RoomVM] = []
    @Published var isRefreshing = false

    private let homeManager = HMHomeManager()
    private var accessoryContexts: [UUID: AccessoryContext] = [:]
    private var accessoryStates: [UUID: AccessoryState] = [:]
    private var syntheticContextIDs: [String: UUID] = [:]
    private var syntheticRoomIDs: [String: UUID] = [:]
    private var roomVMRebuildWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        homeManager.delegate = self
        authorizationStatus = homeManager.authorizationStatus
    }

    var selectedHome: HMHome? {
        guard let id = selectedHomeID else { return nil }
        return homes.first { $0.uniqueIdentifier == id }
    }

    var isAuthorized: Bool {
        authorizationStatus.contains(.authorized)
    }

    func start() {
        authorizationStatus = homeManager.authorizationStatus
        // Home data is not available in the tvOS Simulator; test on a real Apple TV.
        homes = homeManager.homes
        if selectedHomeID == nil {
            // primaryHome is deprecated on tvOS; use the first available home.
            selectedHomeID = homes.first?.uniqueIdentifier
        }
        rebuildRoomVMs()
        refresh()
    }

    func selectHome(id: UUID) {
        selectedHomeID = id
        rebuildRoomVMs()
        refresh()
    }

    func refresh() {
        authorizationStatus = homeManager.authorizationStatus
        guard selectedHome != nil else {
            roomVMs = []
            isRefreshing = false
            return
        }
        guard !isRefreshing else { return }

        isRefreshing = true
        let group = DispatchGroup()

        for context in accessoryContexts.values {
            if let toggle = context.toggleCharacteristic {
                group.enter()
                toggle.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: toggle, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let brightness = context.brightnessInfo?.characteristic {
                group.enter()
                brightness.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: brightness, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let volume = context.volumeInfo?.characteristic {
                group.enter()
                volume.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: volume, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let mute = context.muteCharacteristic {
                group.enter()
                mute.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: mute, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let rotation = context.rotationSpeedInfo?.characteristic {
                group.enter()
                rotation.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: rotation, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let hue = context.hueInfo?.characteristic {
                group.enter()
                hue.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: hue, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let saturation = context.saturationInfo?.characteristic {
                group.enter()
                saturation.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: saturation, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
            if let colorTemp = context.colorTemperatureInfo?.characteristic {
                group.enter()
                colorTemp.readValue { [weak self] error in
                    DispatchQueue.main.async {
                        self?.handleRead(characteristic: colorTemp, accessoryID: context.id, error: error)
                        group.leave()
                    }
                }
            }
        }

        if accessoryContexts.isEmpty {
            isRefreshing = false
        } else {
            group.notify(queue: .main) { [weak self] in
                self?.isRefreshing = false
            }
        }
    }

    func togglePower(accessoryID: UUID, value: Bool) {
        setToggle(accessoryID: accessoryID, value: value)
    }

    func setToggle(accessoryID: UUID, value: Bool) {
        guard let context = accessoryContexts[accessoryID], let toggle = context.toggleCharacteristic else { return }
        if !context.accessory.isReachable {
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.lastError = "Accessory not reachable."
                state.lastWriteStatus = ""
            }
            return
        }

        let previous = accessoryStates[accessoryID]?.toggleOn
        updateAccessoryState(accessoryID: accessoryID) { state in
            state.toggleOn = value
            state.lastError = nil
            state.lastWriteStatus = value ? "Turning On" : "Turning Off"
        }

        let writeValue: NSNumber
        if toggle.characteristicType == HMCharacteristicTypeActive {
            writeValue = NSNumber(value: value ? 1 : 0)
        } else {
            writeValue = NSNumber(value: value)
        }

        toggle.writeValue(writeValue) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.toggleOn = previous
                        state.lastError = error.localizedDescription
                        state.lastWriteStatus = "Failed to update"
                    }
                } else {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.lastError = nil
                        state.lastWriteStatus = value ? "On" : "Off"
                    }
                    LaunchFeedbackPlayer.playPaymentTapTone()
                }
            }
        }
    }

    func setBrightness(accessoryID: UUID, value: Double) {
        guard let context = accessoryContexts[accessoryID], let brightness = context.brightnessInfo?.characteristic else { return }
        if !context.accessory.isReachable {
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.lastError = "Accessory not reachable."
                state.lastWriteStatus = ""
            }
            return
        }

        let clamped = clamp(value, within: context.brightnessInfo?.range ?? 0...100)
        let previous = accessoryStates[accessoryID]?.brightness

        updateAccessoryState(accessoryID: accessoryID) { state in
            state.brightness = clamped
            state.lastError = nil
            state.lastWriteStatus = "Setting brightness"
        }

        brightness.writeValue(NSNumber(value: clamped)) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.brightness = previous
                        state.lastError = error.localizedDescription
                        state.lastWriteStatus = "Failed to update brightness"
                    }
                } else {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.lastError = nil
                        state.lastWriteStatus = "Brightness \(clamped)%"
                    }
                }
            }
        }
    }

    func setVolume(accessoryID: UUID, value: Double) {
        guard let context = accessoryContexts[accessoryID], let volume = context.volumeInfo?.characteristic else { return }
        writeIntValue(accessoryID: accessoryID, characteristic: volume, value: value, range: context.volumeInfo?.range ?? 0...100, key: .volume, label: "Volume")
    }

    func setMute(accessoryID: UUID, value: Bool) {
        guard let context = accessoryContexts[accessoryID], let mute = context.muteCharacteristic else { return }
        if !context.accessory.isReachable {
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.lastError = "Accessory not reachable."
                state.lastWriteStatus = ""
            }
            return
        }

        let previous = accessoryStates[accessoryID]?.isMuted
        updateAccessoryState(accessoryID: accessoryID) { state in
            state.isMuted = value
            state.lastError = nil
            state.lastWriteStatus = value ? "Muting" : "Unmuting"
        }

        mute.writeValue(NSNumber(value: value)) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.isMuted = previous
                        state.lastError = error.localizedDescription
                        state.lastWriteStatus = "Failed to update mute"
                    }
                } else {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.lastError = nil
                        state.lastWriteStatus = value ? "Muted" : "Unmuted"
                    }
                }
            }
        }
    }

    func setRotationSpeed(accessoryID: UUID, value: Double) {
        guard let context = accessoryContexts[accessoryID], let rotation = context.rotationSpeedInfo?.characteristic else { return }
        writeIntValue(accessoryID: accessoryID, characteristic: rotation, value: value, range: context.rotationSpeedInfo?.range ?? 0...100, key: .rotationSpeed, label: "Speed")
    }

    func setHue(accessoryID: UUID, value: Double) {
        guard let context = accessoryContexts[accessoryID], let hue = context.hueInfo?.characteristic else { return }
        writeIntValue(accessoryID: accessoryID, characteristic: hue, value: value, range: context.hueInfo?.range ?? 0...360, key: .hue, label: "Hue")
    }

    func setSaturation(accessoryID: UUID, value: Double) {
        guard let context = accessoryContexts[accessoryID], let sat = context.saturationInfo?.characteristic else { return }
        writeIntValue(accessoryID: accessoryID, characteristic: sat, value: value, range: context.saturationInfo?.range ?? 0...100, key: .saturation, label: "Saturation")
    }

    func setColorTemperature(accessoryID: UUID, value: Double) {
        guard let context = accessoryContexts[accessoryID], let ct = context.colorTemperatureInfo?.characteristic else { return }
        writeIntValue(accessoryID: accessoryID, characteristic: ct, value: value, range: context.colorTemperatureInfo?.range ?? 140...500, key: .colorTemperature, label: "Color Temp")
    }

    func accessories(for roomID: UUID?) -> [AccessoryVM] {
        guard let roomID else {
            if let allAccessoriesRoom = roomVMs.first(where: { $0.name == "All Accessories" }) {
                return allAccessoriesRoom.accessories
            }
            return roomVMs.flatMap(\.accessories)
        }
        return roomVMs.first(where: { $0.id == roomID })?.accessories ?? []
    }

    func accessoryVM(id: UUID) -> AccessoryVM? {
        guard let context = accessoryContexts[id] else { return nil }
        return accessoryVM(from: context)
    }

    struct CameraControls {
        let streamControl: HMCameraStreamControl
        let snapshotControl: HMCameraSnapshotControl?
    }

    func cameraControls(accessoryID: UUID) -> CameraControls? {
        guard let context = accessoryContexts[accessoryID], let stream = context.cameraStreamControl else { return nil }
        return CameraControls(streamControl: stream, snapshotControl: context.cameraSnapshotControl)
    }

    func cameraAccessoryVMs() -> [AccessoryVM] {
        accessoryContexts.values
            .filter { $0.cameraStreamControl != nil }
            .map { accessoryVM(from: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func updateAccessoryState(accessoryID: UUID, update: (inout AccessoryState) -> Void) {
        var state = accessoryStates[accessoryID] ?? AccessoryState()
        update(&state)
        accessoryStates[accessoryID] = state
        scheduleRoomListRebuild()
    }

    private func scheduleRoomListRebuild() {
        roomVMRebuildWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.rebuildRoomListOnly()
        }
        roomVMRebuildWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
    }

    private func handleRead(characteristic: HMCharacteristic, accessoryID: UUID, error: Error?) {
        if let error {
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.lastError = error.localizedDescription
            }
            return
        }

        if characteristic.characteristicType == HMCharacteristicTypePowerState {
            let value = (characteristic.value as? NSNumber)?.boolValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.toggleOn = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeActive {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.toggleOn = (value == 1)
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeBrightness {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.brightness = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeVolume {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.volume = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeMute {
            let value = (characteristic.value as? NSNumber)?.boolValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.isMuted = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeRotationSpeed {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.rotationSpeed = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeHue {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.hue = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeSaturation {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.saturation = value
                state.lastError = nil
            }
        } else if characteristic.characteristicType == HMCharacteristicTypeColorTemperature {
            let value = (characteristic.value as? NSNumber)?.intValue
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.colorTemperature = value
                state.lastError = nil
            }
        }
    }

    private func rebuildRoomVMs() {
        roomVMRebuildWorkItem?.cancel()
        guard let home = selectedHome else {
            roomVMRebuildWorkItem?.cancel()
            roomVMs = []
            accessoryContexts = [:]
            return
        }

        home.delegate = self
        homes = homeManager.homes

        var newContexts: [UUID: AccessoryContext] = [:]
        for accessory in home.accessories {
            accessory.delegate = self
            for context in buildContexts(for: accessory) {
                newContexts[context.id] = context
            }
        }
        accessoryContexts = newContexts
        rebuildRoomListOnly()
    }

    private func rebuildRoomListOnly() {
        guard let home = selectedHome else {
            roomVMs = []
            return
        }

        let allAccessories = accessoryContexts.values
            .map { accessoryVM(from: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let allAccessoriesRoom = RoomVM(
            id: home.roomForEntireHome().uniqueIdentifier,
            name: "All Accessories",
            accessories: allAccessories
        )
        var rooms: [RoomVM] = []

        var grouped: [String: [AccessoryVM]] = [:]
        for accessory in allAccessories {
            let roomKey = normalizedRoomKey(for: accessory.roomName)
            grouped[roomKey, default: []].append(accessory)
        }

        var roomIDsByKey: [String: UUID] = [:]
        var roomNamesByKey: [String: String] = [:]
        for room in home.rooms {
            let key = normalizedRoomKey(for: room.name)
            if roomIDsByKey[key] == nil {
                roomIDsByKey[key] = room.uniqueIdentifier
                roomNamesByKey[key] = normalizedRoomDisplayName(for: room.name)
            }
        }

        let rankedRoomKeys = grouped.keys.sorted { lhs, rhs in
            let leftRank = preferredRoomRank(for: lhs)
            let rightRank = preferredRoomRank(for: rhs)
            if leftRank != rightRank {
                return leftRank < rightRank
            }

            let leftSource = grouped[lhs]?.first?.roomName ?? lhs
            let rightSource = grouped[rhs]?.first?.roomName ?? rhs
            let leftName = roomNamesByKey[lhs] ?? normalizedRoomDisplayName(for: leftSource)
            let rightName = roomNamesByKey[rhs] ?? normalizedRoomDisplayName(for: rightSource)
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }

        for roomKey in rankedRoomKeys {
            guard let accessories = grouped[roomKey], !accessories.isEmpty else { continue }
            guard preferredRoomRank(for: roomKey) < preferredRoomOrder.count else { continue }

            let roomName = roomNamesByKey[roomKey]
                ?? normalizedRoomDisplayName(for: accessories.first?.roomName ?? roomKey)

            let id = roomIDsByKey[roomKey] ?? {
                let syntheticKey = "\(home.uniqueIdentifier.uuidString)|\(roomKey)"
                if let existing = syntheticRoomIDs[syntheticKey] {
                    return existing
                }
                let generated = UUID()
                syntheticRoomIDs[syntheticKey] = generated
                return generated
            }()

            let uniqueAccessories = Array(
                Dictionary(uniqueKeysWithValues: accessories.map { ($0.id, $0) }).values
            )
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            rooms.append(
                RoomVM(
                    id: id,
                    name: roomName,
                    accessories: uniqueAccessories
                )
            )
        }

        rooms.append(allAccessoriesRoom)
        roomVMs = rooms
    }

    private func buildContexts(for accessory: HMAccessory) -> [AccessoryContext] {
        if !isDiffuser(accessory) {
            let cameraProfile = accessory.profiles.compactMap { $0 as? HMCameraProfile }.first
            let roomName = accessory.room?.name ?? "Unassigned"
            let context = buildContext(
                accessory: accessory,
                id: accessory.uniqueIdentifier,
                displayName: accessory.name,
                roomName: roomName,
                services: accessory.services,
                cameraStreamControl: cameraProfile?.streamControl,
                cameraSnapshotControl: cameraProfile?.snapshotControl
            )

            // Camera-only accessories are intentionally excluded from the rooms list
            // until live-stream support is fully stable on tvOS.
            if cameraProfile != nil && !context.hasSupportedControls {
                return []
            }
            return [context]
        }

        let baseRoomName = accessory.room?.name ?? "Unassigned"
        let lightServices = accessory.services.filter { isLightService($0) }
        let lightIDs = Set(lightServices.map { ObjectIdentifier($0) })
        let mistServices = accessory.services.filter { !lightIDs.contains(ObjectIdentifier($0)) && isMistService($0) }
        let cameraProfile = accessory.profiles.compactMap { $0 as? HMCameraProfile }.first

        var contexts: [AccessoryContext] = []

        if !lightServices.isEmpty {
            let displayName = "\(accessory.name) Light"
            let key = "\(accessory.uniqueIdentifier.uuidString)|diffuser|light"
            let roomName = resolvedRoomName(for: displayName, defaultRoomName: baseRoomName)
            contexts.append(
                buildContext(
                    accessory: accessory,
                    id: contextID(for: key),
                    displayName: displayName,
                    roomName: roomName,
                    services: lightServices,
                    cameraStreamControl: nil,
                    cameraSnapshotControl: nil
                )
            )
        }

        if !mistServices.isEmpty {
            let displayName = "\(accessory.name) Mist"
            let key = "\(accessory.uniqueIdentifier.uuidString)|diffuser|mist"
            let roomName = resolvedRoomName(for: displayName, defaultRoomName: baseRoomName)
            contexts.append(
                buildContext(
                    accessory: accessory,
                    id: contextID(for: key),
                    displayName: displayName,
                    roomName: roomName,
                    services: mistServices,
                    cameraStreamControl: nil,
                    cameraSnapshotControl: nil
                )
            )
        }

        if contexts.isEmpty {
            contexts = [
                buildContext(
                    accessory: accessory,
                    id: accessory.uniqueIdentifier,
                    displayName: accessory.name,
                    roomName: baseRoomName,
                    services: accessory.services,
                    cameraStreamControl: cameraProfile?.streamControl,
                    cameraSnapshotControl: cameraProfile?.snapshotControl
                )
            ]
            return contexts
        }

        return contexts
    }

    private func buildContext(
        accessory: HMAccessory,
        id: UUID,
        displayName: String,
        roomName: String,
        services: [HMService],
        cameraStreamControl: HMCameraStreamControl?,
        cameraSnapshotControl: HMCameraSnapshotControl?
    ) -> AccessoryContext {
        var power: HMCharacteristic?
        var active: HMCharacteristic?
        var brightness: CharacteristicInfo?
        var volume: CharacteristicInfo?
        var mute: HMCharacteristic?
        var rotationSpeed: CharacteristicInfo?
        var hue: CharacteristicInfo?
        var saturation: CharacteristicInfo?
        var colorTemperature: CharacteristicInfo?

        for service in services {
            for characteristic in service.characteristics {
                if characteristic.characteristicType == HMCharacteristicTypePowerState {
                    power = characteristic
                } else if characteristic.characteristicType == HMCharacteristicTypeActive {
                    active = characteristic
                } else if characteristic.characteristicType == HMCharacteristicTypeBrightness {
                    brightness = CharacteristicInfo(characteristic: characteristic, range: rangeFor(characteristic, fallback: 0...100), step: stepFor(characteristic, fallback: 5))
                } else if characteristic.characteristicType == HMCharacteristicTypeVolume {
                    volume = CharacteristicInfo(characteristic: characteristic, range: rangeFor(characteristic, fallback: 0...100), step: stepFor(characteristic, fallback: 5))
                } else if characteristic.characteristicType == HMCharacteristicTypeMute {
                    mute = characteristic
                } else if characteristic.characteristicType == HMCharacteristicTypeRotationSpeed {
                    rotationSpeed = CharacteristicInfo(characteristic: characteristic, range: rangeFor(characteristic, fallback: 0...100), step: stepFor(characteristic, fallback: 5))
                } else if characteristic.characteristicType == HMCharacteristicTypeHue {
                    hue = CharacteristicInfo(characteristic: characteristic, range: rangeFor(characteristic, fallback: 0...360), step: stepFor(characteristic, fallback: 5))
                } else if characteristic.characteristicType == HMCharacteristicTypeSaturation {
                    saturation = CharacteristicInfo(characteristic: characteristic, range: rangeFor(characteristic, fallback: 0...100), step: stepFor(characteristic, fallback: 5))
                } else if characteristic.characteristicType == HMCharacteristicTypeColorTemperature {
                    colorTemperature = CharacteristicInfo(characteristic: characteristic, range: rangeFor(characteristic, fallback: 140...500), step: stepFor(characteristic, fallback: 10))
                }
            }
        }

        return AccessoryContext(
            id: id,
            accessory: accessory,
            displayName: displayName,
            roomName: normalizedRoomDisplayName(for: roomName),
            servicesSummary: servicesSummary(for: services),
            toggleCharacteristic: power ?? active,
            brightnessInfo: brightness,
            volumeInfo: volume,
            muteCharacteristic: mute,
            rotationSpeedInfo: rotationSpeed,
            hueInfo: hue,
            saturationInfo: saturation,
            colorTemperatureInfo: colorTemperature,
            cameraStreamControl: cameraStreamControl,
            cameraSnapshotControl: cameraSnapshotControl
        )
    }

    private func contextID(for key: String) -> UUID {
        if let existing = syntheticContextIDs[key] {
            return existing
        }
        let generated = UUID()
        syntheticContextIDs[key] = generated
        return generated
    }

    private func isDiffuser(_ accessory: HMAccessory) -> Bool {
        accessory.name.lowercased().contains("diffuser")
    }

    private func isLightService(_ service: HMService) -> Bool {
        let name = service.name.lowercased()
        if name.contains("light") {
            return true
        }
        if service.serviceType == HMServiceTypeLightbulb {
            return true
        }
        return service.characteristics.contains { characteristic in
            characteristic.characteristicType == HMCharacteristicTypeBrightness
                || characteristic.characteristicType == HMCharacteristicTypeHue
                || characteristic.characteristicType == HMCharacteristicTypeSaturation
                || characteristic.characteristicType == HMCharacteristicTypeColorTemperature
        }
    }

    private func isMistService(_ service: HMService) -> Bool {
        let name = service.name.lowercased()
        if name.contains("mist") || name.contains("humidifier") || name.contains("diffuser") {
            return true
        }
        if service.serviceType == HMServiceTypeHumidifierDehumidifier
            || service.serviceType == HMServiceTypeFan {
            return true
        }

        let hasColorControls = service.characteristics.contains { characteristic in
            characteristic.characteristicType == HMCharacteristicTypeBrightness
                || characteristic.characteristicType == HMCharacteristicTypeHue
                || characteristic.characteristicType == HMCharacteristicTypeSaturation
                || characteristic.characteristicType == HMCharacteristicTypeColorTemperature
        }
        let hasMistControls = service.characteristics.contains { characteristic in
            characteristic.characteristicType == HMCharacteristicTypeRotationSpeed
        }

        if hasMistControls {
            return true
        }

        let hasActive = service.characteristics.contains { $0.characteristicType == HMCharacteristicTypeActive }
        return hasActive && !hasColorControls
    }

    private func resolvedRoomName(for displayName: String, defaultRoomName: String) -> String {
        let normalized = displayName.lowercased()
        if normalized.contains("diffuser") && normalized.contains("light") {
            return "Vik's Lights"
        }
        if normalized.contains("diffuser") && normalized.contains("mist") {
            return "Vik's Room"
        }
        return defaultRoomName
    }

    private func normalizedRoomKey(for roomName: String) -> String {
        let trimmed = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = trimmed.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let scalarView = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let rawKey = String(String.UnicodeScalarView(scalarView))
        return canonicalRoomKey(rawKey)
    }

    private func canonicalRoomKey(_ key: String) -> String {
        if key.hasPrefix("viksroom") || key == "vikroom" {
            return "viksroom"
        }
        if key.hasPrefix("vikslight") || key.hasPrefix("viklight") {
            return "vikslights"
        }
        if key.hasPrefix("sonybravia") || key == "sonytv" {
            return "sonybravia"
        }
        return key
    }

    private func normalizedRoomDisplayName(for roomName: String) -> String {
        let key = normalizedRoomKey(for: roomName)
        if key == "viksroom" {
            return "Vik's Room"
        }
        if key == "vikslights" {
            return "Vik's Lights"
        }
        if key == "sonybravia" {
            return "Sony Bravia"
        }
        let trimmed = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Room" : trimmed
    }

    private var preferredRoomOrder: [String] {
        ["viksroom", "vikslights", "sonybravia", "livingroom"]
    }

    private func preferredRoomRank(for key: String) -> Int {
        if let index = preferredRoomOrder.firstIndex(of: key) {
            return index
        }
        return preferredRoomOrder.count
    }

    private func servicesSummary(for services: [HMService]) -> String {
        var serviceNames = services.compactMap { service in
            let trimmed = service.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if serviceNames.isEmpty {
            serviceNames = services.map { service in
                if service.serviceType == HMServiceTypeLightbulb {
                    return "Light"
                }
                if service.serviceType == HMServiceTypeHumidifierDehumidifier {
                    return "Humidifier"
                }
                if service.serviceType == HMServiceTypeFan {
                    return "Fan"
                }
                return "Service"
            }
        }

        if serviceNames.isEmpty {
            return "No services"
        }
        if serviceNames.count <= 3 {
            return serviceNames.joined(separator: ", ")
        }
        return serviceNames.prefix(3).joined(separator: ", ") + "..."
    }

    private func accessoryVM(from context: AccessoryContext) -> AccessoryVM {
        let state = accessoryStates[context.id]
        return AccessoryVM(
            id: context.id,
            name: context.displayName,
            roomName: context.roomName,
            reachable: context.accessory.isReachable,
            servicesSummary: context.servicesSummary,
            hasToggle: context.toggleCharacteristic != nil,
            hasBrightness: context.brightnessInfo?.characteristic != nil,
            hasVolume: context.volumeInfo?.characteristic != nil,
            hasMute: context.muteCharacteristic != nil,
            hasRotationSpeed: context.rotationSpeedInfo?.characteristic != nil,
            hasHue: context.hueInfo?.characteristic != nil,
            hasSaturation: context.saturationInfo?.characteristic != nil,
            hasColorTemperature: context.colorTemperatureInfo?.characteristic != nil,
            toggleState: state?.toggleOn,
            brightness: state?.brightness,
            volume: state?.volume,
            isMuted: state?.isMuted,
            rotationSpeed: state?.rotationSpeed,
            hue: state?.hue,
            saturation: state?.saturation,
            colorTemperature: state?.colorTemperature,
            brightnessRange: context.brightnessInfo?.range ?? 0...100,
            brightnessStep: context.brightnessInfo?.step ?? 5,
            volumeRange: context.volumeInfo?.range ?? 0...100,
            volumeStep: context.volumeInfo?.step ?? 5,
            rotationSpeedRange: context.rotationSpeedInfo?.range ?? 0...100,
            rotationSpeedStep: context.rotationSpeedInfo?.step ?? 5,
            hueRange: context.hueInfo?.range ?? 0...360,
            hueStep: context.hueInfo?.step ?? 5,
            saturationRange: context.saturationInfo?.range ?? 0...100,
            saturationStep: context.saturationInfo?.step ?? 5,
            colorTemperatureRange: context.colorTemperatureInfo?.range ?? 140...500,
            colorTemperatureStep: context.colorTemperatureInfo?.step ?? 10,
            lastError: state?.lastError,
            lastWriteStatus: state?.lastWriteStatus
        )
    }
}

private struct CharacteristicInfo {
    let characteristic: HMCharacteristic
    let range: ClosedRange<Int>
    let step: Int
}

private struct AccessoryContext {
    let id: UUID
    let accessory: HMAccessory
    let displayName: String
    let roomName: String
    let servicesSummary: String
    let toggleCharacteristic: HMCharacteristic?
    let brightnessInfo: CharacteristicInfo?
    let volumeInfo: CharacteristicInfo?
    let muteCharacteristic: HMCharacteristic?
    let rotationSpeedInfo: CharacteristicInfo?
    let hueInfo: CharacteristicInfo?
    let saturationInfo: CharacteristicInfo?
    let colorTemperatureInfo: CharacteristicInfo?
    let cameraStreamControl: HMCameraStreamControl?
    let cameraSnapshotControl: HMCameraSnapshotControl?
}

private extension AccessoryContext {
    var hasSupportedControls: Bool {
        toggleCharacteristic != nil
            || brightnessInfo != nil
            || volumeInfo != nil
            || muteCharacteristic != nil
            || rotationSpeedInfo != nil
            || hueInfo != nil
            || saturationInfo != nil
            || colorTemperatureInfo != nil
    }
}

private struct AccessoryState {
    var toggleOn: Bool?
    var brightness: Int?
    var volume: Int?
    var isMuted: Bool?
    var rotationSpeed: Int?
    var hue: Int?
    var saturation: Int?
    var colorTemperature: Int?
    var lastError: String?
    var lastWriteStatus: String?
}

private enum IntStateKey: Sendable {
    case volume
    case rotationSpeed
    case hue
    case saturation
    case colorTemperature
}

private func getInt(_ key: IntStateKey, from state: AccessoryState) -> Int? {
    switch key {
    case .volume:
        return state.volume
    case .rotationSpeed:
        return state.rotationSpeed
    case .hue:
        return state.hue
    case .saturation:
        return state.saturation
    case .colorTemperature:
        return state.colorTemperature
    }
}

private func setInt(_ key: IntStateKey, in state: inout AccessoryState, value: Int?) {
    switch key {
    case .volume:
        state.volume = value
    case .rotationSpeed:
        state.rotationSpeed = value
    case .hue:
        state.hue = value
    case .saturation:
        state.saturation = value
    case .colorTemperature:
        state.colorTemperature = value
    }
}

private func clamp(_ value: Double, within range: ClosedRange<Int>) -> Int {
    let rounded = Int(value.rounded())
    return max(range.lowerBound, min(range.upperBound, rounded))
}

private func rangeFor(_ characteristic: HMCharacteristic, fallback: ClosedRange<Int>) -> ClosedRange<Int> {
    let min = (characteristic.metadata?.minimumValue as? NSNumber)?.intValue
    let max = (characteristic.metadata?.maximumValue as? NSNumber)?.intValue
    if let min, let max, min < max {
        return min...max
    }
    return fallback
}

private func stepFor(_ characteristic: HMCharacteristic, fallback: Int) -> Int {
    let step = (characteristic.metadata?.stepValue as? NSNumber)?.intValue
    if let step, step > 0 {
        return step
    }
    return fallback
}

private extension HomeStore {
    func writeIntValue(
        accessoryID: UUID,
        characteristic: HMCharacteristic,
        value: Double,
        range: ClosedRange<Int>,
        key: IntStateKey,
        label: String
    ) {
        guard let context = accessoryContexts[accessoryID] else { return }
        if !context.accessory.isReachable {
            updateAccessoryState(accessoryID: accessoryID) { state in
                state.lastError = "Accessory not reachable."
                state.lastWriteStatus = ""
            }
            return
        }

        let clamped = clamp(value, within: range)
        let previous = getInt(key, from: accessoryStates[accessoryID] ?? AccessoryState())

        updateAccessoryState(accessoryID: accessoryID) { state in
            setInt(key, in: &state, value: clamped)
            state.lastError = nil
            state.lastWriteStatus = "Setting \(label)"
        }

        characteristic.writeValue(NSNumber(value: clamped)) { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        setInt(key, in: &state, value: previous)
                        state.lastError = error.localizedDescription
                        state.lastWriteStatus = "Failed to update \(label)"
                    }
                } else {
                    self?.updateAccessoryState(accessoryID: accessoryID) { state in
                        state.lastError = nil
                        state.lastWriteStatus = "\(label) \(clamped)"
                    }
                }
            }
        }
    }
}

extension HomeStore: HMHomeManagerDelegate {
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        authorizationStatus = homeManager.authorizationStatus
        homes = manager.homes
        if selectedHomeID == nil || !homes.contains(where: { $0.uniqueIdentifier == selectedHomeID }) {
            selectedHomeID = manager.homes.first?.uniqueIdentifier
        }
        rebuildRoomVMs()
        refresh()
    }

    func homeManagerDidUpdatePrimaryHome(_ manager: HMHomeManager) {
        authorizationStatus = homeManager.authorizationStatus
        if selectedHomeID != manager.homes.first?.uniqueIdentifier {
            selectedHomeID = manager.homes.first?.uniqueIdentifier
            rebuildRoomVMs()
            refresh()
        }
    }

    func homeManager(_ manager: HMHomeManager, didUpdate authorizationStatus: HMHomeManagerAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
        rebuildRoomVMs()
    }

    func homeManager(_ manager: HMHomeManager, didAdd home: HMHome) {
        homes = manager.homes
        rebuildRoomVMs()
    }

    func homeManager(_ manager: HMHomeManager, didRemove home: HMHome) {
        homes = manager.homes
        if selectedHomeID == home.uniqueIdentifier {
            selectedHomeID = manager.homes.first?.uniqueIdentifier
        }
        rebuildRoomVMs()
    }
}

extension HomeStore: HMHomeDelegate {
    func homeDidUpdateName(_ home: HMHome) {
        rebuildRoomVMs()
    }

    func home(_ home: HMHome, didAdd accessory: HMAccessory) {
        rebuildRoomVMs()
        refresh()
    }

    func home(_ home: HMHome, didRemove accessory: HMAccessory) {
        rebuildRoomVMs()
    }

    func home(_ home: HMHome, didAdd room: HMRoom) {
        rebuildRoomVMs()
    }

    func home(_ home: HMHome, didRemove room: HMRoom) {
        rebuildRoomVMs()
    }
}

@MainActor
extension HomeStore: @preconcurrency HMAccessoryDelegate {
    func accessoryDidUpdateReachability(_ accessory: HMAccessory) {
        scheduleRoomListRebuild()
    }

    func accessory(_ accessory: HMAccessory, service: HMService, didUpdateValueFor characteristic: HMCharacteristic) {
        let matchingContextIDs = accessoryContexts.values.compactMap { context -> UUID? in
            guard context.accessory.uniqueIdentifier == accessory.uniqueIdentifier else {
                return nil
            }

            if context.toggleCharacteristic === characteristic
                || context.brightnessInfo?.characteristic === characteristic
                || context.volumeInfo?.characteristic === characteristic
                || context.muteCharacteristic === characteristic
                || context.rotationSpeedInfo?.characteristic === characteristic
                || context.hueInfo?.characteristic === characteristic
                || context.saturationInfo?.characteristic === characteristic
                || context.colorTemperatureInfo?.characteristic === characteristic {
                return context.id
            }
            return nil
        }

        for contextID in matchingContextIDs {
            handleRead(characteristic: characteristic, accessoryID: contextID, error: nil)
        }
    }
}
