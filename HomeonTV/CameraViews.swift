import AVKit
import Combine
import HomeKit
import SwiftUI

final class CameraAccessoryController: NSObject, ObservableObject {
    @Published var isStreaming = false
    @Published var statusText = ""
    @Published var lastError: String?
    @Published var source: HMCameraSource?

    private let streamControl: HMCameraStreamControl
    private let snapshotControl: HMCameraSnapshotControl?

    init(controls: HomeStore.CameraControls) {
        self.streamControl = controls.streamControl
        self.snapshotControl = controls.snapshotControl
        super.init()

        streamControl.delegate = self
        snapshotControl?.delegate = self

        if let snapshot = snapshotControl?.mostRecentSnapshot {
            source = snapshot
        }
        statusText = "Ready"
    }

    func start() {
        lastError = nil
        statusText = "Starting stream"
        streamControl.startStream()
    }

    func stop() {
        lastError = nil
        statusText = "Stopping stream"
        streamControl.stopStream()
    }

    func snapshot() {
        guard let snapshotControl else { return }
        lastError = nil
        statusText = "Taking snapshot"
        snapshotControl.takeSnapshot()
    }
}

extension CameraAccessoryController: HMCameraStreamControlDelegate {
    func cameraStreamControlDidStartStream(_ cameraStreamControl: HMCameraStreamControl) {
        isStreaming = true
        source = cameraStreamControl.cameraStream
        statusText = "Streaming"
    }

    func cameraStreamControl(_ cameraStreamControl: HMCameraStreamControl, didStopStreamWithError error: Error?) {
        isStreaming = false
        if let snapshot = snapshotControl?.mostRecentSnapshot {
            source = snapshot
        } else {
            source = nil
        }

        if let error {
            lastError = error.localizedDescription
            statusText = "Stream stopped"
        } else {
            statusText = "Stopped"
        }
    }
}

extension CameraAccessoryController: HMCameraSnapshotControlDelegate {
    func cameraSnapshotControl(_ cameraSnapshotControl: HMCameraSnapshotControl, didTake snapshot: HMCameraSnapshot?, error: Error?) {
        if let error {
            lastError = error.localizedDescription
            statusText = "Snapshot failed"
            return
        }
        if let snapshot {
            source = snapshot
            statusText = "Snapshot updated"
        }
    }

    func cameraSnapshotControlDidUpdateMostRecentSnapshot(_ cameraSnapshotControl: HMCameraSnapshotControl) {
        if let snapshot = cameraSnapshotControl.mostRecentSnapshot {
            source = snapshot
        }
    }
}

struct CameraHubView: View {
    @EnvironmentObject private var store: HomeStore

    @AppStorage("externalCameraURL.vikCamera") private var vikCameraURL = ""
    @AppStorage("externalCameraURL.livingRoom") private var livingRoomURL = ""
    @AppStorage("externalCameraURL.ring") private var ringURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.cameraAccessoryVMs().isEmpty
                && vikCameraURL.isEmpty
                && livingRoomURL.isEmpty
                && ringURL.isEmpty {
                Text("No cameras configured yet")
                    .font(.headline)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeonTVCard(cornerRadius: 20)
            }

            if !store.cameraAccessoryVMs().isEmpty {
                sectionHeader(
                    title: "HomeKit Cameras",
                    subtitle: "Native live view through HomeKit"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 520), spacing: 14)], spacing: 14) {
                    ForEach(store.cameraAccessoryVMs()) { cameraAccessory in
                        NavigationLink(value: HomeRoute.accessory(cameraAccessory.id)) {
                            AccessoryRowView(accessory: cameraAccessory)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sectionHeader(
                title: "External Camera Streams",
                subtitle: "Enter your own RTSP streams. URLs are stored locally on the device."
            )

            ExternalCameraTile(
                title: "Camera 1",
                icon: "camera.fill",
                subtitle: "RTSP stream",
                streamURL: $vikCameraURL
            )

            ExternalCameraTile(
                title: "Camera 2",
                icon: "camera.metering.spot",
                subtitle: "RTSP stream",
                streamURL: $livingRoomURL
            )

            ExternalCameraTile(
                title: "Doorbell Camera",
                icon: "doorbell.video.fill",
                subtitle: "RTSP stream via your local bridge.",
                streamURL: $ringURL
            )
        }
        .onAppear {
            seedDefaultsIfNeeded()
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func seedDefaultsIfNeeded() {
        vikCameraURL = canonicalizedStreamURL(vikCameraURL)
        livingRoomURL = canonicalizedStreamURL(livingRoomURL)
        ringURL = canonicalizedStreamURL(ringURL)
    }

    private func canonicalizedStreamURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ""
        }

        if var components = URLComponents(string: trimmed) {
            let path = components.path.lowercased()
            let needsFix = path.isEmpty || path == "/" || path == "/stream_path"
            if needsFix {
                components.path = "/stream1"
                return components.url?.absoluteString ?? trimmed
            }
            return trimmed
        }

        if trimmed.lowercased().contains("/stream_path") {
            return trimmed.replacingOccurrences(
                of: "/stream_path",
                with: "/stream1",
                options: [.caseInsensitive]
            )
        }

        return trimmed
    }
}

private struct ExternalCameraTile: View {
    let title: String
    let icon: String
    let subtitle: String

    @Binding var streamURL: String

    @State private var player: AVPlayer?
    @State private var errorText: String?
    @State private var activeURLText: String?
    @State private var statusObservation: NSKeyValueObservation?
    @State private var candidates: [URL] = []
    @State private var currentCandidateIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Stream URL", text: $streamURL)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )

                Button("Play") {
                    startPlayback()
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)

                Button("Stop") {
                    stopPlayback()
                }
                .buttonStyle(.bordered)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.35))

                if let player {
                    VideoPlayer(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "video.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Enter a stream URL and press Play")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 220)

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let activeURLText {
                Text("Source: \(activeURLText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .homeonTVCard(cornerRadius: 22)
        .onDisappear {
            stopPlayback()
        }
    }

    private func startPlayback() {
        stopPlayback()
        guard let parsedURL = parsedStreamURL(from: streamURL) else {
            errorText = "Invalid URL"
            return
        }
        errorText = nil

        let resolvedCandidates = candidateURLs(from: parsedURL)
        guard !resolvedCandidates.isEmpty else {
            errorText = "No valid stream candidates."
            return
        }

        candidates = resolvedCandidates
        currentCandidateIndex = 0
        attemptPlayback(at: 0)
    }

    private func stopPlayback() {
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        activeURLText = nil
        candidates = []
        currentCandidateIndex = 0
    }

    private func attemptPlayback(at index: Int) {
        guard index < candidates.count else {
            errorText = "Stream failed. Try /stream1 or /stream2 for Tapo cameras."
            return
        }

        currentCandidateIndex = index
        let url = candidates[index]
        activeURLText = url.absoluteString

        let item = AVPlayerItem(url: url)
        let candidatePlayer = AVPlayer(playerItem: item)
        candidatePlayer.automaticallyWaitsToMinimizeStalling = false
        player = candidatePlayer
        errorText = index > 0 ? "Trying fallback path \(index + 1)/\(candidates.count)..." : nil

        statusObservation?.invalidate()
        statusObservation = item.observe(\.status, options: [.initial, .new]) { _, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self.errorText = nil
                    candidatePlayer.play()
                case .failed:
                    self.attemptPlayback(at: index + 1)
                case .unknown:
                    break
                @unknown default:
                    self.attemptPlayback(at: index + 1)
                }
            }
        }

        candidatePlayer.play()
    }

    private func candidateURLs(from parsedURL: URL) -> [URL] {
        var resolved: [URL] = [parsedURL]

        guard parsedURL.scheme?.lowercased() == "rtsp",
              var components = URLComponents(url: parsedURL, resolvingAgainstBaseURL: false) else {
            return deduplicatedURLs(resolved)
        }

        if components.port == nil {
            components.port = 554
        }

        let path = components.path.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let needsTapoFallbacks = path.isEmpty || path == "/" || path == "/stream_path" || path == "stream_path"
        if needsTapoFallbacks {
            for candidatePath in ["/stream1", "/stream2", "/h264/ch1/main/av_stream", "/h264/ch1/sub/av_stream"] {
                components.path = candidatePath
                if let url = components.url {
                    resolved.append(url)
                }
            }
        } else if path == "/stream1" {
            components.path = "/stream2"
            if let url = components.url {
                resolved.append(url)
            }
        } else if path == "/stream2" {
            components.path = "/stream1"
            if let url = components.url {
                resolved.append(url)
            }
        }

        return deduplicatedURLs(resolved)
    }

    private func deduplicatedURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var result: [URL] = []
        for url in urls {
            let key = url.absoluteString
            if seen.insert(key).inserted {
                result.append(url)
            }
        }
        return result
    }

    private func parsedStreamURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let direct = URL(string: trimmed), direct.scheme != nil {
            return direct
        }
        return URL(string: "rtsp://\(trimmed)")
    }
}

struct CameraSectionView: View {
    @StateObject private var controller: CameraAccessoryController
    let isEnabled: Bool

    init(controls: HomeStore.CameraControls, isEnabled: Bool) {
        _controller = StateObject(wrappedValue: CameraAccessoryController(controls: controls))
        self.isEnabled = isEnabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Live Camera")
                    .font(.headline)

                Spacer()

                Text(controller.isStreaming ? "Live" : "Idle")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(controller.isStreaming ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                Button("Start") {
                    controller.start()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isEnabled || controller.isStreaming)

                Button("Stop") {
                    controller.stop()
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled || !controller.isStreaming)

                Button("Snapshot") {
                    controller.snapshot()
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled)
            }

            CameraSourceView(source: controller.source)
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            Text(controller.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let err = controller.lastError, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .homeonTVCard(cornerRadius: 22)
        .onDisappear {
            controller.stop()
        }
    }
}

struct CameraSourceView: UIViewRepresentable {
    var source: HMCameraSource?

    func makeUIView(context: Context) -> HMCameraView {
        let view = HMCameraView()
        view.backgroundColor = .black
        view.cameraSource = source
        return view
    }

    func updateUIView(_ uiView: HMCameraView, context: Context) {
        uiView.cameraSource = source
    }
}
