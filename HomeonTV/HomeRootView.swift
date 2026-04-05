import HomeKit
import SwiftUI

enum HomeRoute: Hashable {
    case room(UUID)
    case accessory(UUID)
}

struct HomeRootView: View {
    @EnvironmentObject private var store: HomeStore

    @State private var path = NavigationPath()

    @State private var hasStarted = false
    @State private var showLaunchOverlay = true
    @State private var launchState: HomeLaunchState = .loading
    @State private var launchCompleted = false
    @State private var launchStartDate = Date()

    private let minimumLaunchDuration: TimeInterval = 3.4
    private let successHoldDuration: TimeInterval = 0.45

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                HomeBackdropView()

                ScrollView {
                    VStack(spacing: 22) {
                        headerCard

                        if store.isAuthorized, store.selectedHome != nil {
                            homeDashboard
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }

                if showLaunchOverlay {
                    HomeLaunchOverlayView(state: launchState)
                        .transition(.opacity)
                        .zIndex(10)
                        .allowsHitTesting(false)
                }
            }
            .task {
                guard !hasStarted else { return }
                hasStarted = true
                launchStartDate = Date()
                store.start()
                scheduleLaunchFallback()

                if store.authorizationStatus.contains(.authorized) {
                    handleLaunchAuthorizationSuccess()
                }
            }
            .onChange(of: store.authorizationStatus) { _, newStatus in
                if newStatus.contains(.authorized) {
                    handleLaunchAuthorizationSuccess()
                }
            }
            .onChange(of: store.selectedHomeID) { _, _ in
                path = NavigationPath()
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .room(let roomID):
                    RoomAccessoriesView(roomID: roomID)
                case .accessory(let accessoryID):
                    AccessoryDetailView(accessoryID: accessoryID)
                }
            }
        }
    }

    private var headerCard: some View {
        let totalAccessories = store.selectedHome?.accessories.count ?? 0
        let onlineAccessories = store.selectedHome?.accessories.filter(\.isReachable).count ?? 0

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Home Dashboard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(store.selectedHome?.name ?? "HomeonTV")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                }

                Spacer(minLength: 10)
                statusPill
            }

            HStack(spacing: 12) {
                statCard(title: "Rooms", value: "\(store.roomVMs.count)", icon: "square.grid.2x2.fill", color: .blue)
                statCard(title: "Accessories", value: "\(totalAccessories)", icon: "switch.2", color: .mint)
                statCard(title: "Online", value: "\(onlineAccessories)", icon: "checkmark.seal.fill", color: .green)
            }

            HStack(spacing: 12) {
                if store.homes.count > 1 {
                    homePicker
                }

                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
        }
        .padding(20)
        .homeonTVCard(cornerRadius: 30)
    }

    private var homeDashboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.roomVMs.isEmpty {
                Text("No rooms found")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .homeonTVCard(cornerRadius: 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(store.roomVMs) { room in
                        NavigationLink(value: HomeRoute.room(room.id)) {
                            RoomCard(room: room)
                                .frame(maxWidth: 980, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
    }

    private var statusPill: some View {
        let (label, color) = authorizationStatusLabel
        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.14))
        .clipShape(Capsule())
    }

    private var homePicker: some View {
        Menu {
            ForEach(store.homes, id: \.uniqueIdentifier) { home in
                Button(home.name) {
                    store.selectHome(id: home.uniqueIdentifier)
                }
            }
        } label: {
            Label(store.selectedHome?.name ?? "Select Home", systemImage: "house")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(HomeonTVTheme.heroGradient)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Text(emptyStateTitle)
                .font(.title.weight(.bold))

            Text(emptyStateMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)

            VStack(alignment: .leading, spacing: 10) {
                Text("How to enable")
                    .font(.headline)
                ForEach(enableSteps, id: \.self) { step in
                    Text("• \(step)")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: 900, alignment: .leading)
            .homeonTVCard(cornerRadius: 20)
        }
        .padding(.top, 70)
    }

    private var authorizationStatusLabel: (String, Color) {
        let status = store.authorizationStatus
        if status.contains(.authorized) {
            return (store.isRefreshing ? "Refreshing" : "Connected", .green)
        }
        if status.contains(.restricted) {
            return ("Restricted", .orange)
        }
        if status.contains(.determined) {
            return ("Awaiting Permission", .yellow)
        }
        return ("Unavailable", .gray)
    }

    private var emptyStateTitle: String {
        if !store.isAuthorized { return "HomeKit Access Needed" }
        return "No Home Found"
    }

    private var emptyStateMessage: String {
        if !store.isAuthorized {
            return "HomeonTV needs permission to access your Home data before it can list rooms and accessories."
        }
        return "We couldn't find a configured Home for this Apple TV."
    }

    private var enableSteps: [String] {
        [
            "Sign in to iCloud on Apple TV with the same Apple ID used for Home.",
            "In Settings > Users and Accounts > iCloud, turn on Home.",
            "On iPhone or iPad, open the Home app and make sure a Home is configured.",
            "Launch HomeonTV again and accept the HomeKit prompt."
        ]
    }

    private func scheduleLaunchFallback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumLaunchDuration) {
            if showLaunchOverlay {
                dismissLaunchOverlay()
            }
        }
    }

    private func handleLaunchAuthorizationSuccess() {
        guard !launchCompleted else { return }
        launchCompleted = true
        launchState = .success
        LaunchFeedbackPlayer.playSuccessChime()

        let elapsed = Date().timeIntervalSince(launchStartDate)
        let remaining = max(0, minimumLaunchDuration - elapsed)
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining + successHoldDuration) {
            dismissLaunchOverlay()
        }
    }

    private func dismissLaunchOverlay() {
        guard showLaunchOverlay else { return }
        withAnimation(.easeOut(duration: 0.5)) {
            showLaunchOverlay = false
        }
    }
}

private struct RoomCard: View {
    let room: RoomVM

    private var activeCount: Int {
        room.accessories.filter { $0.toggleState == true }.count
    }

    private var iconName: String {
        let lower = room.name.lowercased()
        if lower.contains("vik's lights") || lower.contains("lights") { return "lightbulb.2.fill" }
        if lower.contains("sony") || lower.contains("bravia") { return "tv.fill" }
        if lower.contains("living") { return "sofa.fill" }
        if lower.contains("vik") || lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("kitchen") { return "fork.knife" }
        if lower.contains("bath") { return "bathtub.fill" }
        if lower.contains("garage") { return "car.fill" }
        if lower.contains("office") { return "desktopcomputer" }
        if lower.contains("all accessories") { return "square.grid.2x2.fill" }
        return "house.lodge.fill"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(HomeonTVTheme.surfaceTint)
                    .frame(width: 52, height: 52)
                Image(systemName: iconName)
                    .font(.title3.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(room.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(HomeonTVTheme.surfaceTint)
                    Text(activeCount == 0 ? "No active accessories right now" : "\(activeCount) active accessories")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text("\(room.accessories.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(HomeonTVTheme.surfaceTint)
                    .clipShape(Capsule())

                Text("Accessories")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .homeonTVCard(cornerRadius: 24)
    }
}

struct HomeBackdropView: View {
    var body: some View {
        ZStack {
            HomeonTVTheme.backgroundGradient
                .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.2))
                .frame(width: 420, height: 420)
                .blur(radius: 84)
                .offset(x: -280, y: -250)

            Circle()
                .fill(Color.orange.opacity(0.12))
                .frame(width: 380, height: 380)
                .blur(radius: 72)
                .offset(x: 290, y: 220)
        }
    }
}

#Preview {
    HomeRootView()
        .environmentObject(HomeStore())
}
