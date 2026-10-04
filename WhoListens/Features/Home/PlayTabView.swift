import SwiftUI

struct FriendsTabView: View {
    var showNavigationBar = false
    private enum Section: String, CaseIterable {
        case suggestions = "Suggestions"
        case friends = "Friends"
        case requests = "Requests"
    }

    @AppStorage("lastRoomCode") private var lastRoomCode = ""
    @State private var selectedSection: Section = .suggestions
    @State private var showJoinGame = false
    @State private var activeRoom: GameRoom?
    @State private var isCreatingRoom = false
    @State private var isResumingRoom = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var searchResults: [FriendUser] = []
    @State private var connections: [FriendConnection] = []
    @State private var isLoadingFriends = true
    @State private var isSearching = false
    @State private var busyUserID: UUID?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Friends")
                    .font(AppTypography.display)
                    .padding(.bottom, 7)

                Text("Music is better together.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.bottom, 26)

                inviteCard
                    .padding(.bottom, 29)

                HStack(spacing: 11) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white.opacity(0.55))
                    TextField("Search friends by name", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 16))
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 15))
                .padding(.bottom, 28)

                HStack(spacing: 0) {
                    ForEach(Section.allCases, id: \.self) { section in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedSection = section }
                        } label: {
                            VStack(spacing: 12) {
                                Text(section.rawValue)
                                    .font(.system(size: 15, weight: selectedSection == section ? .bold : .medium))
                                    .foregroundStyle(selectedSection == section ? .white : .white.opacity(0.48))
                                Rectangle()
                                    .fill(selectedSection == section ? .white : .white.opacity(0.13))
                                    .frame(height: 2)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 30)

                if selectedSection == .suggestions {
                    if isSearching { ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 42) }
                    else if !searchResults.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(searchResults) { user in friendRow(user) }
                        }
                    } else { emptyState }
                } else if selectedSection == .friends {
                    let accepted = connections.filter { $0.status == .accepted }
                    if isLoadingFriends { ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 42) }
                    else if accepted.isEmpty { emptyState }
                    else {
                        LazyVStack(spacing: 0) {
                            ForEach(accepted) { connection in connectionRow(connection) }
                        }
                    }
                } else {
                    let pending = connections.filter { $0.status == .pending }
                    if isLoadingFriends { ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 42) }
                    else if pending.isEmpty { emptyState }
                    else {
                        LazyVStack(spacing: 0) {
                            ForEach(pending) { connection in connectionRow(connection) }
                        }
                    }
                }

                if !lastRoomCode.isEmpty {
                    Button { Task { await resumeRoom() } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 21))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Your last party")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("PIN \(lastRoomCode)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.56))
                            }
                            Spacer()
                            if isResumingRoom { ProgressView().tint(.white) }
                            else { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)) }
                        }
                        .foregroundStyle(.white)
                        .padding(17)
                        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)
                    .disabled(isResumingRoom)
                    .padding(.top, 25)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.55))
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(.white)
        .toolbar(showNavigationBar ? .visible : .hidden, for: .navigationBar)
        .task { await loadConnections() }
        .task(id: searchText) { await searchFriends() }
        .refreshable { await loadConnections() }
        .navigationDestination(isPresented: $showJoinGame) { JoinGameView() }
        .navigationDestination(item: $activeRoom) { room in
            RoomSessionView(room: room)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 50, height: 50)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text("Bring your people in")
                        .font(.system(size: 20, weight: .bold))
                    Text("Start a music party, then share the PIN with your friends.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.67))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button { Task { await createRoom() } } label: {
                    Group {
                        if isCreatingRoom { ProgressView().tint(.black) }
                        else { Text("Create party") }
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))
                }
                .disabled(isCreatingRoom)

                Button { showJoinGame = true } label: {
                    Text("Join with PIN")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(19)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 21))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: emptySymbol)
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.77))
                .frame(width: 86, height: 86)
                .background(Color(white: 0.14), in: Circle())
                .padding(.bottom, 6)

            Text(emptyTitle)
                .font(.system(size: 20, weight: .bold))
                .multilineTextAlignment(.center)
            Text(emptyDetail)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 42)
    }

    private var emptySymbol: String {
        switch selectedSection {
        case .suggestions: "person.crop.circle.badge.plus"
        case .friends: "person.2"
        case .requests: "envelope.open"
        }
    }

    private var emptyTitle: String {
        switch selectedSection {
        case .suggestions: searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 ? "No people found" : "Find your people"
        case .friends: "No friends here yet"
        case .requests: "No requests yet"
        }
    }

    private var emptyDetail: String {
        switch selectedSection {
        case .suggestions: searchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 ? "Try a different name." : "Search for someone by name to send a friend request."
        case .friends: "Find someone above and send them a request to connect."
        case .requests: "Sent and received friend requests will appear here."
        }
    }

    private func avatar(_ user: FriendUser) -> some View {
        Text(String(user.displayName.prefix(1)).uppercased())
            .font(.system(size: 19, weight: .bold, design: .rounded))
            .frame(width: 49, height: 49)
            .background(Color(white: 0.20), in: Circle())
    }

    private func friendRow(_ user: FriendUser) -> some View {
        let existing = connections.first { $0.user.id == user.id }
        return HStack(spacing: 13) {
            avatar(user)
            Text(user.displayName)
                .font(.system(size: 16, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            if busyUserID == user.id {
                ProgressView().tint(.white)
            } else if let existing {
                Text(existing.status == .accepted ? "Friends" :
                        existing.direction == .incoming ? "Respond in Requests" : "Requested")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
            } else {
                Button("Add") { Task { await sendRequest(to: user) } }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(.white, in: Capsule())
            }
        }
        .padding(.vertical, 10)
    }

    private func connectionRow(_ connection: FriendConnection) -> some View {
        HStack(spacing: 13) {
            avatar(connection.user)
            VStack(alignment: .leading, spacing: 3) {
                Text(connection.user.displayName)
                    .font(.system(size: 16, weight: .semibold))
                if connection.status == .pending {
                    Text(connection.direction == .incoming ? "Wants to be friends" : "Request sent")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.52))
                }
            }
            Spacer(minLength: 6)
            if busyUserID == connection.user.id {
                ProgressView().tint(.white)
            } else if connection.status == .pending && connection.direction == .incoming {
                Button("Accept") { Task { await change("accept", connection) } }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(.white, in: Capsule())
                Button { Task { await change("decline", connection) } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("Decline request")
            } else {
                Button(connection.status == .accepted ? "Remove" : "Cancel") {
                    Task { await change(connection.status == .accepted ? "remove" : "cancel", connection) }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.vertical, 10)
    }

    @MainActor
    private func loadConnections() async {
        isLoadingFriends = connections.isEmpty
        defer { isLoadingFriends = false }
        do {
            connections = try await FriendsService.connections()
            errorMessage = nil
        } catch {
            errorMessage = "Could not load friends. Pull down to retry."
        }
    }

    @MainActor
    private func searchFriends() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        do {
            try await Task.sleep(for: .milliseconds(300))
            let results = try await FriendsService.search(query)
            guard !Task.isCancelled, searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
            searchResults = results
            selectedSection = .suggestions
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            errorMessage = "Could not search friends right now."
        }
        isSearching = false
    }

    @MainActor
    private func sendRequest(to user: FriendUser) async {
        busyUserID = user.id
        defer { busyUserID = nil }
        do {
            try await FriendsService.send(to: user.id)
            await loadConnections()
            AppToastCenter.shared.show("Friend request sent.", style: .success)
        } catch {
            AppToastCenter.shared.show(error.localizedDescription, style: .error)
        }
    }

    @MainActor
    private func change(_ action: String, _ connection: FriendConnection) async {
        busyUserID = connection.user.id
        defer { busyUserID = nil }
        do {
            try await FriendsService.change(action, connectionID: connection.id)
            await loadConnections()
            let message = action == "accept" ? "Friend request accepted." :
                action == "remove" ? "Friend removed." : "Friend request removed."
            AppToastCenter.shared.show(message, style: .success)
        } catch {
            AppToastCenter.shared.show(error.localizedDescription, style: .error)
        }
    }

    @MainActor
    private func createRoom() async {
        guard !isCreatingRoom else { return }
        isCreatingRoom = true
        defer { isCreatingRoom = false }
        do {
            let room = try await GameBackend.create()
            lastRoomCode = room.code
            activeRoom = room
            errorMessage = nil
            AppToastCenter.shared.show("Party created. Share your PIN!", style: .success)
        } catch {
            errorMessage = "Could not create a party. Please try again."
            AppToastCenter.shared.show("Could not create a party. Please try again.", style: .error)
        }
    }

    @MainActor
    private func resumeRoom() async {
        guard !isResumingRoom else { return }
        isResumingRoom = true
        defer { isResumingRoom = false }
        do {
            activeRoom = try await GameBackend.join(code: lastRoomCode)
            errorMessage = nil
        } catch {
            lastRoomCode = ""
            errorMessage = "That party is no longer available."
            AppToastCenter.shared.show("That party is no longer available.", style: .error)
        }
    }
}
