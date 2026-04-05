import SwiftUI

struct AccessoryDetailView: View {
    @EnvironmentObject private var store: HomeStore
    let accessoryID: UUID

    var body: some View {
        ZStack {
            HomeBackdropView()

            ScrollView {
                if let accessory = store.accessoryVM(id: accessoryID) {
                    VStack(alignment: .leading, spacing: 16) {
                        heroCard(accessory)

                        if accessory.hasToggle {
                            powerCard(accessory)
                        }

                        if accessory.hasBrightness {
                            NumericControlCard(
                                title: "Brightness",
                                value: accessory.brightness ?? accessory.brightnessRange.lowerBound,
                                range: accessory.brightnessRange,
                                step: accessory.brightnessStep,
                                unit: "%",
                                tint: .yellow,
                                isEnabled: accessory.reachable,
                                onChange: { value in
                                    store.setBrightness(accessoryID: accessory.id, value: value)
                                }
                            )
                        }

                        if accessory.hasVolume {
                            NumericControlCard(
                                title: "Volume",
                                value: accessory.volume ?? accessory.volumeRange.lowerBound,
                                range: accessory.volumeRange,
                                step: accessory.volumeStep,
                                unit: "",
                                tint: .blue,
                                isEnabled: accessory.reachable,
                                onChange: { value in
                                    store.setVolume(accessoryID: accessory.id, value: value)
                                }
                            )
                        }

                        if accessory.hasMute {
                            muteCard(accessory)
                        }

                        if accessory.hasRotationSpeed {
                            NumericControlCard(
                                title: "Fan Speed",
                                value: accessory.rotationSpeed ?? accessory.rotationSpeedRange.lowerBound,
                                range: accessory.rotationSpeedRange,
                                step: accessory.rotationSpeedStep,
                                unit: "",
                                tint: .mint,
                                isEnabled: accessory.reachable,
                                onChange: { value in
                                    store.setRotationSpeed(accessoryID: accessory.id, value: value)
                                }
                            )
                        }

                        if accessory.hasHue {
                            NumericControlCard(
                                title: "Hue",
                                value: accessory.hue ?? accessory.hueRange.lowerBound,
                                range: accessory.hueRange,
                                step: accessory.hueStep,
                                unit: "",
                                tint: .pink,
                                isEnabled: accessory.reachable,
                                onChange: { value in
                                    store.setHue(accessoryID: accessory.id, value: value)
                                }
                            )
                        }

                        if accessory.hasSaturation {
                            NumericControlCard(
                                title: "Saturation",
                                value: accessory.saturation ?? accessory.saturationRange.lowerBound,
                                range: accessory.saturationRange,
                                step: accessory.saturationStep,
                                unit: "%",
                                tint: .purple,
                                isEnabled: accessory.reachable,
                                onChange: { value in
                                    store.setSaturation(accessoryID: accessory.id, value: value)
                                }
                            )
                        }

                        if accessory.hasColorTemperature {
                            NumericControlCard(
                                title: "Color Temperature",
                                value: accessory.colorTemperature ?? accessory.colorTemperatureRange.lowerBound,
                                range: accessory.colorTemperatureRange,
                                step: accessory.colorTemperatureStep,
                                unit: "",
                                tint: .orange,
                                isEnabled: accessory.reachable,
                                onChange: { value in
                                    store.setColorTemperature(accessoryID: accessory.id, value: value)
                                }
                            )
                        }

                        if accessory.hasHue || accessory.hasSaturation || accessory.hasColorTemperature {
                            LightPaletteCard(
                                accessory: accessory,
                                isEnabled: accessory.reachable,
                                onApplyColor: { hue, saturation in
                                    if accessory.hasHue {
                                        store.setHue(accessoryID: accessory.id, value: Double(hue))
                                    }
                                    if accessory.hasSaturation {
                                        store.setSaturation(accessoryID: accessory.id, value: Double(saturation))
                                    }
                                    if accessory.hasToggle, accessory.toggleState != true {
                                        store.setToggle(accessoryID: accessory.id, value: true)
                                    }
                                },
                                onApplyTemperature: { temperature in
                                    store.setColorTemperature(accessoryID: accessory.id, value: Double(temperature))
                                    if accessory.hasToggle, accessory.toggleState != true {
                                        store.setToggle(accessoryID: accessory.id, value: true)
                                    }
                                }
                            )
                        }

                        if !accessory.hasToggle
                            && !accessory.hasBrightness
                            && !accessory.hasVolume
                            && !accessory.hasMute
                            && !accessory.hasRotationSpeed
                            && !accessory.hasHue
                            && !accessory.hasSaturation
                            && !accessory.hasColorTemperature {
                            noControlsCard
                        }

                        if let status = accessory.lastWriteStatus, !status.isEmpty {
                            statusCard(title: "Status", value: status, color: .secondary)
                        }

                        if let error = accessory.lastError, !error.isEmpty {
                            statusCard(title: "Error", value: error, color: .red)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                } else {
                    VStack(spacing: 12) {
                        Text("Accessory unavailable")
                            .font(.title2.weight(.semibold))
                        Text("Select another accessory or refresh.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
            }
        }
    }

    private func heroCard(_ accessory: AccessoryVM) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accessory.detailTint.opacity(0.22))
                    .frame(width: 68, height: 68)
                Image(systemName: accessory.detailIcon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accessory.detailTint)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(accessory.name)
                    .font(.largeTitle.weight(.bold))
                if !accessory.detailBadges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(accessory.detailBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 12)

            Text(accessory.reachable ? "Reachable" : "Offline")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((accessory.reachable ? Color.green : Color.red).opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(18)
        .homeonTVCard(cornerRadius: 24)
    }

    private func powerCard(_ accessory: AccessoryVM) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Power")
                    .font(.headline)
                Text(accessory.toggleState == true ? "Currently On" : "Currently Off")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.setToggle(accessoryID: accessory.id, value: !(accessory.toggleState ?? false))
            } label: {
                Label(accessory.toggleState == true ? "Turn Off" : "Turn On", systemImage: accessory.toggleState == true ? "power.circle.fill" : "power.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!accessory.reachable)
        }
        .padding(16)
        .homeonTVCard(cornerRadius: 20)
    }

    private func muteCard(_ accessory: AccessoryVM) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio")
                    .font(.headline)
                Text(accessory.isMuted == true ? "Muted" : "Unmuted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.setMute(accessoryID: accessory.id, value: !(accessory.isMuted ?? false))
            } label: {
                Label(accessory.isMuted == true ? "Unmute" : "Mute", systemImage: accessory.isMuted == true ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!accessory.reachable)
        }
        .padding(16)
        .homeonTVCard(cornerRadius: 20)
    }

    private var noControlsCard: some View {
        Text("No supported controls for this accessory yet.")
            .font(.headline)
            .foregroundStyle(.secondary)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeonTVCard(cornerRadius: 20)
    }

    private func statusCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeonTVCard(cornerRadius: 14)
    }
}

private struct NumericControlCard: View {
    let title: String
    let value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let tint: Color
    let isEnabled: Bool
    let onChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(value)\(unit)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
            }

            HStack(spacing: 12) {
                Button {
                    stepBy(-step)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 64, height: 38)
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled)

                progressTrack
                    .frame(height: 22)
                    .focusable(isEnabled)
                    .onMoveCommand { direction in
                        switch direction {
                        case .left:
                            stepBy(-step)
                        case .right:
                            stepBy(step)
                        default:
                            break
                        }
                    }

                Button {
                    stepBy(step)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 64, height: 38)
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled)
            }
        }
        .padding(16)
        .homeonTVCard(cornerRadius: 20)
    }

    private var progressTrack: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let clamped = max(range.lowerBound, min(range.upperBound, value))
            let span = max(1, range.upperBound - range.lowerBound)
            let progress = CGFloat(clamped - range.lowerBound) / CGFloat(span)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: max(8, width * progress))
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .offset(x: max(0, min(width - 20, width * progress - 10)))
            }
        }
    }

    private func stepBy(_ delta: Int) {
        guard isEnabled else { return }
        let next = max(range.lowerBound, min(range.upperBound, value + delta))
        onChange(Double(next))
    }
}

private struct LightPaletteCard: View {
    let accessory: AccessoryVM
    let isEnabled: Bool
    let onApplyColor: (_ hue: Int, _ saturation: Int) -> Void
    let onApplyTemperature: (_ value: Int) -> Void

    private let presets: [LightPreset] = [
        LightPreset(name: "Warm", hue: 32, saturation: 42, color: Color(red: 1, green: 0.72, blue: 0.45)),
        LightPreset(name: "Sunset", hue: 18, saturation: 90, color: Color(red: 1, green: 0.43, blue: 0.22)),
        LightPreset(name: "Rose", hue: 336, saturation: 66, color: Color(red: 1, green: 0.33, blue: 0.58)),
        LightPreset(name: "Lavender", hue: 270, saturation: 50, color: Color(red: 0.74, green: 0.58, blue: 1)),
        LightPreset(name: "Ocean", hue: 199, saturation: 82, color: Color(red: 0.2, green: 0.63, blue: 1)),
        LightPreset(name: "Forest", hue: 124, saturation: 68, color: Color(red: 0.26, green: 0.82, blue: 0.42))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Palette")
                .font(.headline)

            if accessory.hasHue || accessory.hasSaturation {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(presets) { preset in
                            Button {
                                onApplyColor(preset.hue, preset.saturation)
                            } label: {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(preset.color)
                                        .frame(width: 42, height: 42)
                                    Text(preset.name)
                                        .font(.caption2)
                                }
                                .frame(width: 68)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isEnabled)
                        }
                    }
                }
            }

            if accessory.hasColorTemperature {
                HStack(spacing: 10) {
                    Button("Cool") {
                        onApplyTemperature(coolTemp)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled)

                    Button("Neutral") {
                        onApplyTemperature(neutralTemp)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled)

                    Button("Warm") {
                        onApplyTemperature(warmTemp)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isEnabled)
                }
            }

            HStack(spacing: 10) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))

                Text("Current light preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .homeonTVCard(cornerRadius: 20)
    }

    private var coolTemp: Int {
        accessory.colorTemperatureRange.lowerBound
    }

    private var warmTemp: Int {
        accessory.colorTemperatureRange.upperBound
    }

    private var neutralTemp: Int {
        let range = accessory.colorTemperatureRange
        return range.lowerBound + (range.upperBound - range.lowerBound) / 2
    }

    private var currentColor: Color {
        if accessory.hasHue || accessory.hasSaturation {
            let hueRange = max(1, accessory.hueRange.upperBound - accessory.hueRange.lowerBound)
            let hueValue = accessory.hue ?? accessory.hueRange.lowerBound
            let satValue = accessory.saturation ?? accessory.saturationRange.lowerBound
            let brightness = max(0.25, Double(accessory.brightness ?? accessory.brightnessRange.upperBound) / 100.0)

            let hueProgress = Double(hueValue - accessory.hueRange.lowerBound) / Double(hueRange)
            let satRange = max(1, accessory.saturationRange.upperBound - accessory.saturationRange.lowerBound)
            let satProgress = Double(satValue - accessory.saturationRange.lowerBound) / Double(satRange)
            return Color(hue: hueProgress, saturation: satProgress, brightness: brightness)
        }

        if accessory.hasColorTemperature {
            let denom = max(1, accessory.colorTemperatureRange.upperBound - accessory.colorTemperatureRange.lowerBound)
            let value = accessory.colorTemperature ?? accessory.colorTemperatureRange.lowerBound
            let progress = Double(value - accessory.colorTemperatureRange.lowerBound) / Double(denom)
            let red = min(1.0, 0.7 + (progress * 0.3))
            let blue = max(0.4, 1.0 - (progress * 0.6))
            return Color(red: red, green: 0.78, blue: blue)
        }

        return .white
    }
}

private struct LightPreset: Identifiable {
    let id = UUID()
    let name: String
    let hue: Int
    let saturation: Int
    let color: Color
}

private extension AccessoryVM {
    var detailIcon: String {
        let identity = "\(name) \(servicesSummary)".lowercased()
        if identity.contains("doorbell") || identity.contains("ring") { return "doorbell.video.fill" }
        if identity.contains("camera") { return "video.fill" }
        if identity.contains("apple tv") { return "appletv.fill" }
        if identity.contains("sony") || identity.contains("bravia") || identity.contains(" tv") || identity.hasSuffix("tv") {
            return "tv.fill"
        }
        if identity.contains("vacuum") || identity.contains("robot") { return "fanblades.fill" }
        if identity.contains("blind") || identity.contains("shade") || identity.contains("curtain") { return "blinds.horizontal.closed" }
        if identity.contains("motion") { return "figure.walk.motion" }
        if identity.contains("contact") || identity.contains("window sensor") { return "sensor.tag.radiowaves.forward" }
        if identity.contains("water leak") || identity.contains("leak") { return "drop.triangle.fill" }
        if identity.contains("smoke") || identity.contains("co ") || identity.hasPrefix("co") { return "smoke.fill" }
        if identity.contains("heater") || identity.contains("radiator") { return "heat.waves" }
        if identity.contains("air conditioner") || identity.contains("ac") { return "snowflake" }
        if identity.contains("air purifier") || identity.contains("purifier") { return "wind" }
        if identity.contains("diffuser") && (identity.contains("mist") || identity.contains("humidifier")) { return "drop.fill" }
        if identity.contains("diffuser") && identity.contains("light") { return "lightbulb.max.fill" }
        if hasHue || hasSaturation || hasBrightness || hasColorTemperature { return "lightbulb.fill" }
        if identity.contains("fan") || hasRotationSpeed { return "fan.fill" }
        if identity.contains("speaker") || hasVolume { return "speaker.wave.2.fill" }
        if identity.contains("lock") { return "lock.fill" }
        if identity.contains("thermostat") || identity.contains("temperature") { return "thermometer.sun.fill" }
        if identity.contains("garage") { return "door.garage.closed" }
        if identity.contains("door") { return "door.left.hand.open" }
        return "switch.2.fill"
    }

    var detailTint: Color {
        let identity = "\(name) \(servicesSummary)".lowercased()
        if identity.contains("doorbell") || identity.contains("ring") || identity.contains("camera") { return .cyan }
        if identity.contains("apple tv") { return .indigo }
        if identity.contains("sony") || identity.contains("bravia") || identity.contains(" tv") || identity.hasSuffix("tv") { return .indigo }
        if identity.contains("motion") || identity.contains("contact") || identity.contains("sensor") { return .orange }
        if identity.contains("smoke") || identity.contains("co ") || identity.hasPrefix("co") { return .red }
        if identity.contains("water leak") || identity.contains("leak") { return .blue }
        if identity.contains("air purifier") || identity.contains("purifier") { return .mint }
        if identity.contains("diffuser") && (identity.contains("mist") || identity.contains("humidifier")) { return .blue }
        if hasHue || hasSaturation { return .pink }
        if hasBrightness || hasColorTemperature { return .yellow }
        if hasRotationSpeed { return .mint }
        if hasVolume { return .blue }
        return .teal
    }

    var detailBadges: [String] {
        var badges: [String] = []
        if hasToggle { badges.append(toggleState == true ? "ON" : "OFF") }
        if hasBrightness { badges.append("DIM") }
        if hasHue || hasSaturation { badges.append("COLOR") }
        if hasColorTemperature { badges.append("TEMP") }
        if hasRotationSpeed { badges.append("FLOW") }
        if hasVolume { badges.append("AUDIO") }
        if hasMute { badges.append("MUTE") }
        return Array(badges.prefix(4))
    }
}

#Preview {
    AccessoryDetailView(accessoryID: UUID())
        .environmentObject(HomeStore())
}
