import SwiftUI

struct MeetingRoomView: View {
    @StateObject private var viewModel = MeetingViewModel()
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var auth: AuthService
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if viewModel.isInMeeting {
                    meetingInterface
                } else {
                    lobbyView
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
            .navigationTitle("會議室")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        isInputFocused = false
                    }
                    .foregroundColor(AppTheme.gold)
                }
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                PaywallView(reason: viewModel.paywallReason, trialSummary: viewModel.trialSummary)
                    .environmentObject(auth)
            }
        }
    }

    // MARK: - Lobby

    private var lobbyView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "building.columns.fill")
                .font(.system(size: 64))
                .foregroundColor(AppTheme.gold)

            VStack(spacing: 8) {
                Text("BOARD ROOM")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)

                Text("你的 AI 個人董事會")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.textSecondary)
            }

            // Director cards — large image horizontal layout
            HStack(spacing: 12) {
                ForEach(settings.enabledDirectors) { director in
                    directorCard(director)
                }
            }
            .padding(.horizontal, 16)

            Button(action: {
                viewModel.startMeeting()
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("召開會議")
                        .font(.headline)
                }
                .foregroundColor(AppTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.gold)
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Recent meetings
            if !PersistenceController.shared.meetings.isEmpty {
                recentMeetings
            }
        }
    }

    @ViewBuilder
    private func directorCard(_ director: Director) -> some View {
        VStack(spacing: 0) {
            // Avatar image or emoji fallback
            Group {
                if let name = director.imageName, let uiImage = UIImage(named: name) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(director.emoji)
                        .font(.system(size: 36))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.secondaryBackground)
                }
            }
            .frame(height: 110)
            .clipped()

            // Name + title
            VStack(spacing: 3) {
                Text(director.name)
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                Text(director.title)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppTheme.directorColors[director.colorIndex].opacity(0.6), lineWidth: 1)
        )
    }

    private var recentMeetings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("最近會議")
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PersistenceController.shared.meetings.prefix(5)) { meeting in
                        VStack(spacing: 0) {
                            NavigationLink {
                                MeetingDetailView(meeting: meeting, onContinue: {
                                    viewModel.continueMeeting(meeting)
                                })
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meeting.title)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .lineLimit(1)

                                    Text("\(meeting.messages.count) 則訊息")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                .padding(10)
                                .frame(width: 140, alignment: .leading)
                            }

                            Button {
                                viewModel.continueMeeting(meeting)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("繼續")
                                }
                                .font(.caption2)
                                .foregroundColor(AppTheme.gold)
                                .frame(width: 140)
                                .padding(.vertical, 6)
                            }
                        }
                        .background(AppTheme.cardBackground)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom)
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
                .onTapGesture {
                    isInputFocused = false
                }
                .onChange(of: viewModel.currentMeeting?.messages.count) { _, _ in
                    if let lastId = viewModel.currentMeeting?.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Event preview (multi-event)
            if !viewModel.pendingEvents.isEmpty {
                eventPreviewBanner(events: viewModel.pendingEvents)
            }

            // Memory detection banner
            if let pending = viewModel.pendingMemory {
                memoryBanner(content: pending.content, category: pending.category)
            }

            // Director selector + Input
            VStack(spacing: 8) {
                // Director quick-select
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

                // Input bar
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

            // End meeting button
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

// MARK: - Message Bubble

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

    /// Maps director name to asset image name, then falls back to emoji
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
