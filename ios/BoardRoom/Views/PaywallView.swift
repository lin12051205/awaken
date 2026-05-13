import SwiftUI

struct PaywallView: View {
    let reason: PaywallReason
    let trialSummary: String?
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    enum PaywallReason {
        case trialExpired
        case dailyLimitReached
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: reason == .trialExpired ? "clock.badge.checkmark" : "chart.bar.fill")
                    .font(.system(size: 56))
                    .foregroundColor(AppTheme.gold)

                // Title
                VStack(spacing: 8) {
                    Text(reason == .trialExpired ? "試用期結束了" : "今日對話已達上限")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(reason == .trialExpired
                         ? "你的 3 天免費試用已結束"
                         : "明天額度自動重置")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Trial summary (only shown when trial expires)
                if reason == .trialExpired, let summary = trialSummary {
                    VStack(spacing: 8) {
                        Text("你的試用期回顧")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)

                        Text(summary)
                            .font(.body)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(16)
                            .background(AppTheme.cardBackground)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                }

                // Plan comparison
                VStack(spacing: 12) {
                    planRow(title: "免費試用", detail: "每日 12 次對話", active: false)
                    planRow(title: "月訂閱 NT$300", detail: "每日 24 次對話", active: true)
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA buttons
                VStack(spacing: 12) {
                    Button(action: subscribeTapped) {
                        Text("立即訂閱 NT$300 / 月")
                            .font(.headline)
                            .foregroundColor(AppTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppTheme.gold)
                            .cornerRadius(14)
                    }

                    if reason == .dailyLimitReached {
                        Button("明天再來") { dismiss() }
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func planRow(title: String, detail: String, active: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(active ? AppTheme.gold : AppTheme.textMuted)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
            if active {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.gold)
            }
        }
        .padding(14)
        .background(active ? AppTheme.gold.opacity(0.08) : AppTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(active ? AppTheme.gold.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private func subscribeTapped() {
        // TODO: StoreKit 2 purchase flow
        // For now, just notify server after purchase
        Task {
            guard let url = URL(string: "https://awaken-gamma.vercel.app/user/upgrade"),
                  let token = BackendAPIService.shared.accessToken else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
            await auth.refreshStatus()
            dismiss()
        }
    }
}
