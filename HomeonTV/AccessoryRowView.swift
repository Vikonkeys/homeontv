import SwiftUI

struct AccessoryRowView: View {
    let accessory: AccessoryVM

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(HomeonTVTheme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(HomeonTVTheme.cardStroke, lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(accessory.iconColor.opacity(0.65))
                .frame(width: 6)
                .padding(.vertical, 10)
                .padding(.leading, 6)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accessory.iconColor.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: accessory.iconName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accessory.iconColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(accessory.name)
                            .font(.headline.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                            .fixedSize(horizontal: false, vertical: true)

                        if accessory.hasToggle {
                            Image(systemName: accessory.toggleState == true ? "bolt.fill" : "bolt.slash")
                                .font(.caption)
                                .foregroundStyle(accessory.toggleState == true ? .green : .secondary)
                        }
                    }

                    Text(accessory.statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(accessory.roomName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        ForEach(accessory.capabilityBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer(minLength: 12)

                if !accessory.reachable {
                    Text("Offline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Text(accessory.trailingStatus)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(accessory.primaryStatusColor)
                }
            }
            .padding(16)
            .padding(.leading, 6)
        }
        .frame(maxWidth: 980, alignment: .leading)
        .shadow(color: HomeonTVTheme.softShadow, radius: 10, x: 0, y: 6)
    }
}

private extension AccessoryVM {
    var iconName: String {
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
        if identity.contains("thermostat") || identity.contains("temperature") { return "thermometer.sun.fill" }
        if identity.contains("heater") || identity.contains("radiator") { return "heat.waves" }
        if identity.contains("air conditioner") || identity.contains("ac") { return "snowflake" }
        if identity.contains("air purifier") || identity.contains("purifier") { return "wind" }
        if identity.contains("diffuser") && (identity.contains("mist") || identity.contains("humidifier")) { return "drop.fill" }
        if identity.contains("diffuser") && identity.contains("light") { return "lightbulb.max.fill" }
        if hasHue || hasSaturation || hasColorTemperature || hasBrightness { return "lightbulb.fill" }
        if identity.contains("speaker") || hasVolume { return "speaker.wave.2.fill" }
        if identity.contains("fan") || hasRotationSpeed { return "fan.fill" }
        if identity.contains("lock") { return "lock.fill" }
        if identity.contains("thermostat") || identity.contains("temperature") { return "thermometer.sun.fill" }
        if identity.contains("garage") { return "door.garage.closed" }
        if identity.contains("door") { return "door.left.hand.open" }
        if identity.contains("outlet") || identity.contains("plug") { return "poweroutlet.type.b.fill" }
        return "switch.2.fill"
    }

    var iconColor: Color {
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
        if hasVolume { return .blue }
        if hasRotationSpeed { return .mint }
        return .teal
    }

    var statusLine: String {
        if hasToggle {
            return toggleState == true ? "Power on" : "Power off"
        }
        if hasBrightness, let brightness {
            return "Brightness \(brightness)%"
        }
        if hasVolume, let volume {
            return "Volume \(volume)"
        }
        if hasRotationSpeed, let rotationSpeed {
            return "Speed \(rotationSpeed)"
        }
        return roomName
    }

    var trailingStatus: String {
        if hasToggle {
            return toggleState == true ? "On" : "Off"
        }
        if hasBrightness, let brightness {
            return "\(brightness)%"
        }
        if hasVolume, let volume {
            return "\(volume)"
        }
        if hasRotationSpeed, let rotationSpeed {
            return "\(rotationSpeed)"
        }
        return "Details"
    }

    var primaryStatusColor: Color {
        guard reachable else { return .secondary }
        if hasToggle { return toggleState == true ? .green : .secondary }
        if hasBrightness || hasHue || hasSaturation || hasColorTemperature { return .yellow }
        return .primary
    }

    var capabilityBadges: [String] {
        var badges: [String] = []
        if hasBrightness { badges.append("DIM") }
        if hasHue || hasSaturation { badges.append("COLOR") }
        if hasColorTemperature { badges.append("TEMP") }
        if hasRotationSpeed { badges.append("SPEED") }
        if hasVolume { badges.append("AUDIO") }
        if hasMute { badges.append("MUTE") }
        if badges.isEmpty { badges.append("INFO") }
        return Array(badges.prefix(3))
    }
}

#Preview {
    AccessoryRowView(
        accessory: AccessoryVM(
            id: UUID(),
            name: "Living Room Lamp",
            roomName: "Living Room",
            reachable: true,
            servicesSummary: "Light, Battery",
            hasToggle: true,
            hasBrightness: true,
            hasVolume: false,
            hasMute: false,
            hasRotationSpeed: false,
            hasHue: true,
            hasSaturation: true,
            hasColorTemperature: true,
            toggleState: true,
            brightness: 65,
            volume: nil,
            isMuted: nil,
            rotationSpeed: nil,
            hue: 180,
            saturation: 70,
            colorTemperature: 260,
            brightnessRange: 1...100,
            brightnessStep: 5,
            volumeRange: 0...100,
            volumeStep: 5,
            rotationSpeedRange: 0...100,
            rotationSpeedStep: 5,
            hueRange: 0...360,
            hueStep: 5,
            saturationRange: 0...100,
            saturationStep: 5,
            colorTemperatureRange: 140...500,
            colorTemperatureStep: 10,
            lastError: nil,
            lastWriteStatus: "Power On"
        )
    )
    .padding()
}
