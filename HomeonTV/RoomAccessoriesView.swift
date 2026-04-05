import SwiftUI

struct RoomAccessoriesView: View {
    @EnvironmentObject private var store: HomeStore
    let roomID: UUID

    private var roomName: String {
        store.roomVMs.first(where: { $0.id == roomID })?.name ?? "Room"
    }

    var body: some View {
        let accessories = store.accessories(for: roomID)

        ZStack {
            HomeBackdropView()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(accessories: accessories)

                    if accessories.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(accessories) { accessory in
                                accessoryActionBlock(accessory)
                            }
                        }
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .task {
            store.refresh()
        }
    }

    @ViewBuilder
    private func accessoryActionBlock(_ accessory: AccessoryVM) -> some View {
        if accessory.hasToggle {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    store.setToggle(accessoryID: accessory.id, value: !(accessory.toggleState ?? false))
                } label: {
                    AccessoryRowView(accessory: accessory)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                NavigationLink(value: HomeRoute.accessory(accessory.id)) {
                    Label("Open Controls", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        } else {
            NavigationLink(value: HomeRoute.accessory(accessory.id)) {
                AccessoryRowView(accessory: accessory)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private func header(accessories: [AccessoryVM]) -> some View {
        let onlineCount = accessories.filter(\.reachable).count
        let activeCount = accessories.filter { $0.toggleState == true }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text(roomName)
                .font(.largeTitle.weight(.bold))

            HStack(spacing: 10) {
                statPill(text: "\(accessories.count) Accessories", color: .blue)
                statPill(text: "\(onlineCount) Online", color: .green)
                statPill(text: "\(activeCount) Active", color: .yellow)

                Spacer(minLength: 16)

                Button {
                    store.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
        }
        .padding(18)
        .homeonTVCard(cornerRadius: 24)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No accessories in this room")
                .font(.title3.weight(.semibold))
            Text("Add devices in Apple's Home app and they will appear here.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeonTVCard(cornerRadius: 24)
    }

    private func statPill(text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        RoomAccessoriesView(roomID: UUID())
            .environmentObject(HomeStore())
    }
}

