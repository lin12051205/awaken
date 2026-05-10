import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    var onContinue: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meeting.title)
                            .font(.title3.bold())
                            .foregroundColor(AppTheme.textPrimary)

                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "yyyy/MM/dd HH:mm"
                        Text(formatter.string(from: meeting.createdAt))
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)

                        Text("\(meeting.messages.count) 則訊息")
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

                    // Summary
                    if let summary = meeting.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("會議摘要", systemImage: "doc.text")
                                .font(.headline)
                                .foregroundColor(AppTheme.gold)

                            MarkdownTextView(content: summary)
                                .textSelection(.enabled)
                        }
                        .padding()
                        .background(AppTheme.cardBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Messages
                    VStack(alignment: .leading, spacing: 8) {
                        Label("對話記錄", systemImage: "bubble.left.and.bubble.right")
                            .font(.headline)
                            .foregroundColor(AppTheme.gold)
                            .padding(.horizontal)

                        ForEach(meeting.messages) { message in
                            MessageBubbleView(message: message)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("會議記錄")
        .navigationBarTitleDisplayMode(.inline)
    }
}
