import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    var onContinue: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var freshSummary: String?
    @State private var isSummarizing = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(smartTitle)
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "yyyy/MM/dd HH:mm"
                        Text(formatter.string(from: meeting.createdAt))
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)

                        Text("\(displayableMessages.count) 則訊息")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding()

                    // Continue meeting button
                    if let onContinue = onContinue {
                        Button(action: {
                            onContinue()
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("繼續這場會議")
                                    .font(.headline)
                            }
                            .foregroundColor(AppTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.gold)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }

                    // Messages — with a fresh AI-generated summary at the top
                    // replacing the boilerplate '會議開始…' welcome bubble.
                    VStack(alignment: .leading, spacing: 8) {
                        Label("對話記錄", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .foregroundColor(AppTheme.gold)
                            .padding(.horizontal)

                        summaryCard
                            .padding(.horizontal)

                        ForEach(displayableMessages) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("會議記錄")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFreshSummary()
        }
    }

    // MARK: - Summary card

    @ViewBuilder
    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundColor(AppTheme.gold)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text("對話重點")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(AppTheme.gold)

                if isSummarizing {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("整理對話重點中…")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                } else if let summary = freshSummary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .textSelection(.enabled)
                } else {
                    Text("本次對話尚無足夠內容可摘要。")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.secondaryBackground.opacity(0.55))
        .cornerRadius(12)
    }

    private func loadFreshSummary() async {
        // Skip if this meeting has literally nothing to summarize.
        let nonSystem = meeting.messages.filter { $0.role != .system }
        guard !nonSystem.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        freshSummary = await MeetingViewModel.summaryHelper.generateFreshSummary(for: meeting)
    }

    /// Messages minus the boilerplate '會議開始…' welcome system message,
    /// so the fresh summary card takes its place at the top of the record.
    private var displayableMessages: [MeetingMessage] {
        meeting.messages.filter { msg in
            if msg.role == .system && msg.content.hasPrefix("會議開始") {
                return false
            }
            return true
        }
    }

    /// Same smart-title logic as the sidebar drawer so both views agree.
    private var smartTitle: String {
        let isDefaultDateTitle = meeting.title.hasPrefix("董事會議 ") &&
            meeting.title.range(of: #"\d{4}/\d{2}/\d{2}"#, options: .regularExpression) != nil
        if !meeting.title.isEmpty && !isDefaultDateTitle {
            return meeting.title
        }
        if let summary = meeting.summary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            let line = summary
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first(where: { !$0.isEmpty && !$0.allSatisfy({ "-=#".contains($0) }) })
                ?? summary
            let cleaned = line
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "**", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: " -•*"))
            if !cleaned.isEmpty { return String(cleaned.prefix(40)) }
        }
        if let firstUser = meeting.messages.first(where: { $0.role == .user }) {
            let content = firstUser.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                return String(content.prefix(40)) + (content.count > 40 ? "…" : "")
            }
        }
        return meeting.title
    }
}
