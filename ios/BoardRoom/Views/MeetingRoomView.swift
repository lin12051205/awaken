import SwiftUI

struct MeetingRoomView: View {
    @StateObject private var viewModel = MeetingViewModel()
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var auth: AuthService
    @StateObject private var persistence = PersistenceController.shared
    @FocusState private var isInputFocused: Bool

    @State private var showHistory = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                AppTheme.background.ignoresSafeArea()

                // Main content
                Group {
                    if viewModel.isInMeeting {
                        meetingInterface
                    } else {
                        lobbyView
                    }
                }
                .blur(radius: showHistory ? 3 : 0)
                .allowsHitTesting(!showHistory)

                // History drawer overlay
                if showHistory {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { closeHistory() }

                    HistoryDrawerView(
                        meetings: persistence.meetings,
                        onClose: closeHistory,
                        onSelect: { meeting in
                            viewModel.continueMeeting(meeting)
                            closeHistory()
                        }
                    )
                    .frame(width: UIScreen.main.bounds.width * 0.78)
                    .transition(.move(edge: .leading))
                }
            }
            .navigationTitle("會議室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { openHistory() } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(AppTheme.gold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(AppTheme.gold)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { isInputFocused = false }
                        .foregroundColor(AppTheme.gold)
                }
            }
            .alert("提示", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settings)
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView(reason: viewModel.paywallReason, trialSummary: viewModel.trialSummary)
                    .environmentObject(auth)
            }
        }
    }

    private func openHistory() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showHistory = true
        }
    }

    private func closeHistory() {
        withAnimation(.easeOut(duration: 0.22)) {
            showHistory = false
        }
    }

    // MARK: - Lobby

    private var lobbyView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            // Temple low-poly logo
            Image("meeting_temple")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)

            VStack(spacing: 8) {
                Text("BOARD ROOM")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .tracking(3)
                    .foregroundColor(AppTheme.textPrimary)

                Text("你的 AI 個人董事會")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Director avatars — circular, scrollable when many directors enabled
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(settings.enabledDirectors) { director in
                        directorAvatar(director)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 4)

            Spacer()

            // Faceted gold button
            Button(action: { viewModel.startMeeting() }) {
                FacetedGoldButton(label: "召開會議")
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 20)
        }
    }

    @ViewBuilder
    private func directorAvatar(_ director: Director) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.secondaryBackground)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.directorColors[director.colorIndex].opacity(0.55), lineWidth: 1)
                    )

                if let name = director.imageName, let uiImage = UIImage(named: name) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 66, height: 66)
                        .clipShape(Circle())
                } else {
                    Text(director.emoji)
                        .font(.system(size: 34))
                }
            }

            VStack(spacing: 2) {
                Text(director.name)
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(director.title)
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Meeting Interface

    private var meetingInterface: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.currentMeeting?.messages ?? []) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(AppTheme.gold)
                                Text("董事們正在思考...")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .onTapGesture { isInputFocused = false }
                .onChange(of: viewModel.currentMeeting?.messages.count) { _, _ in
                    if let lastId = viewModel.currentMeeting?.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }

            // Event preview
            if !viewModel.pendingEvents.isEmpty {
                eventPreviewBanner(events: viewModel.pendingEvents)
            }

            // Memory banner
            if let pending = viewModel.pendingMemory {
                memoryBanner(content: pending.content, category: pending.category)
            }

            // Director selector + Input
            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(settings.enabledDirectors) { director in
                            Button {
                                viewModel.selectedDirector = viewModel.selectedDirector?.id == director.id ? nil : director
                            } label: {
                                HStack(spacing: 4) {
                                    Text(director.emoji)
                                    Text(director.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    viewModel.selectedDirector?.id == director.id
                                    ? AppTheme.directorColors[director.colorIndex].opacity(0.3)
                                    : AppTheme.secondaryBackground
                                )
                                .foregroundColor(
                                    viewModel.selectedDirector?.id == director.id
                                    ? AppTheme.directorColors[director.colorIndex]
                                    : AppTheme.textSecondary
                                )
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            viewModel.selectedDirector?.id == director.id
                                            ? AppTheme.directorColors[director.colorIndex]
                                            : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                HStack(spacing: 8) {
                    TextField("輸入你的想法...", text: $viewModel.inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.secondaryBackground)
                        .cornerRadius(20)
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1...5)
                        .focused($isInputFocused)

                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.inputText.isEmpty ? AppTheme.textMuted : AppTheme.gold)
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(AppTheme.cardBackground)

            Button(action: viewModel.endMeeting) {
                Text("結束會議")
                    .font(.caption)
                    .foregroundColor(AppTheme.destructive)
                    .padding(.vertical, 8)
            }
            .background(AppTheme.cardBackground)
        }
    }

    // MARK: - Banners

    private func eventPreviewBanner(events: [MeetingViewModel.PendingEvent]) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"

        return VStack(alignment: .leading, spacing: 6) {
            Text("📅 偵測到 \(events.count) 個行事曆事件")
                .font(.caption)
                .foregroundColor(AppTheme.gold)

            ForEach(events) { event in
                Text("• \(event.title) — \(formatter.string(from: event.date))")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }

            HStack {
                Spacer()
                Button("全部加入") { viewModel.confirmAllEvents() }
                    .font(.caption)
                    .foregroundColor(AppTheme.background)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.gold)
                    .cornerRadius(8)
                Button("忽略") { viewModel.dismissAllEvents() }
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(AppTheme.secondaryBackground)
    }

    private func memoryBanner(content: String, category: Memory.MemoryCategory) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🧠 要記住這件事嗎？")
                    .font(.caption)
                    .foregroundColor(AppTheme.gold)
                Text("\(category.emoji) \(content)")
                    .font(.caption)
                    .foregroundColor(AppTheme.textPrimary)
            }
            Spacer()
            Button("記住") { viewModel.confirmMemorySave() }
                .font(.caption)
                .foregroundColor(AppTheme.background)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.gold)
                .cornerRadius(8)
            Button("忽略") { viewModel.dismissMemory() }
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(hex: "1A2A1A"))
    }
}

// MARK: - Faceted Low-Poly Gold Button

private struct FacetedGoldButton: View {
    let label: String

    var body: some View {
        ZStack {
            FacetedButtonShape()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "7A5C1E"), location: 0.0),
                            .init(color: Color(hex: "D4AF37"), location: 0.18),
                            .init(color: Color(hex: "F4E29A"), location: 0.48),
                            .init(color: Color(hex: "D4AF37"), location: 0.78),
                            .init(color: Color(hex: "8B6B26"), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    FacetedButtonShape()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "F4E29A"), Color(hex: "8B6B26")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .overlay(facetLines)
                .shadow(color: AppTheme.gold.opacity(0.45), radius: 12, y: 0)

            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .tracking(3)
            }
            .foregroundColor(Color(hex: "1B1407"))
        }
        .frame(height: 68)
    }

    /// Subtle diagonal facet lines to suggest the low-poly look
    private var facetLines: some View {
        GeometryReader { geo in
            Path { p in
                let h = geo.size.height
                let w = geo.size.width
                // top-edge facets
                p.move(to: CGPoint(x: 40, y: 0))
                p.addLine(to: CGPoint(x: 60, y: h * 0.45))
                p.move(to: CGPoint(x: w - 40, y: 0))
                p.addLine(to: CGPoint(x: w - 60, y: h * 0.45))
                // bottom-edge facets
                p.move(to: CGPoint(x: 40, y: h))
                p.addLine(to: CGPoint(x: 60, y: h * 0.55))
                p.move(to: CGPoint(x: w - 40, y: h))
                p.addLine(to: CGPoint(x: w - 60, y: h * 0.55))
            }
            .stroke(Color.black.opacity(0.18), lineWidth: 0.6)
        }
    }
}

private struct FacetedButtonShape: Shape {
    var cut: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cut, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: cut, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

// MARK: - History Drawer

private struct HistoryDrawerView: View {
    let meetings: [Meeting]
    let onClose: () -> Void
    let onSelect: (Meeting) -> Void

    @State private var detailMeeting: Meeting?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("會議紀錄")
                    .font(.title3.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Button { onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().background(AppTheme.textMuted.opacity(0.3))

            if meetings.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.textMuted)
                    Text("尚無會議紀錄")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(meetings) { meeting in
                            historyRow(meeting)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(AppTheme.cardBackground)
        .sheet(item: $detailMeeting) { meeting in
            NavigationStack {
                MeetingDetailView(meeting: meeting, onContinue: {
                    onSelect(meeting)
                })
            }
        }
    }

    @ViewBuilder
    private func historyRow(_ meeting: Meeting) -> some View {
        let title = displayTitle(for: meeting)

        Button {
            detailMeeting = meeting
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(dateText(meeting.createdAt))
                        .font(.caption2)
                        .foregroundColor(AppTheme.textMuted)
                    Text("·")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textMuted)
                    Text("\(meeting.messages.count) 則訊息")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(AppTheme.secondaryBackground)
            .cornerRadius(10)
        }
    }

    /// Show the summary's first line as title if available; otherwise meeting.title.
    private func displayTitle(for meeting: Meeting) -> String {
        if let summary = meeting.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            // Strip markdown headers/bullets, take first non-empty line
            let line = summary
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { !$0.isEmpty && !$0.allSatisfy({ "-=#".contains($0) }) })
                ?? summary
            // Strip leading markdown chars
            return line
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " -•*"))
        }
        return meeting.title
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Message Bubble (unchanged)

struct MessageBubbleView: View {
    let message: MeetingMessage

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .director:
            directorBubble
        case .system:
            systemBubble
        }
    }

    @ViewBuilder
    private func directorAvatarView(name: String?, emoji: String?) -> some View {
        let imageName = Self.imageNameForDirector(name)
        if let imgName = imageName, let uiImage = UIImage(named: imgName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            Text(emoji ?? "🤖")
                .font(.title2)
                .frame(width: 36, height: 36)
                .background(AppTheme.secondaryBackground)
        }
    }

    private static func imageNameForDirector(_ name: String?) -> String? {
        switch name {
        case "CEO": return "ceo_avatar"
        case "財政顧問": return "finance_avatar"
        case "魔鬼代言人": return "devil_avatar"
        case "COO": return "coo_avatar"
        case "Persona": return "persona_avatar"
        default: return nil
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(AppTheme.gold.opacity(0.8))
                    .cornerRadius(16, corners: [.topLeft, .topRight, .bottomLeft])
                    .frame(maxWidth: 280, alignment: .trailing)

                Text(messageTimeString)
                    .font(.caption2)
                    .foregroundColor(AppTheme.textMuted)
            }
        }
    }

    private var messageTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: message.timestamp)
    }

    private var directorBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            directorAvatarView(name: message.directorName, emoji: message.directorEmoji)
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(message.directorName ?? "AI")
                    .font(.caption)
                    .foregroundColor(AppTheme.gold)

                MarkdownTextView(content: message.content)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(AppTheme.cardBackground)
                    .cornerRadius(16, corners: [.topRight, .bottomLeft, .bottomRight])
            }
            .frame(maxWidth: 300, alignment: .leading)

            Spacer()
        }
    }

    private var systemBubble: some View {
        Text(message.content)
            .font(.caption)
            .foregroundColor(AppTheme.textMuted)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(AppTheme.secondaryBackground.opacity(0.5))
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
