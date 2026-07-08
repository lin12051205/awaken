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

    enum Plan: String, CaseIterable, Identifiable {
        case monthly, yearly
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .monthly: return "月訂閱"
            case .yearly:  return "年訂閱"
            }
        }
        var priceLine: String {
            switch self {
            case .monthly: return "NT$300 / 月"
            case .yearly:  return "NT$3,000 / 年"
            }
        }
        var subtitle: String {
            switch self {
            case .monthly: return "每日 24 次對話・可隨時取消"
            case .yearly:  return "省 17%・一次付清最划算"
            }
        }
    }

    @State private var selectedPlan: Plan = .monthly
    @State private var isSubscribing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)

                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "F4E29A"), AppTheme.gold],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .shadow(color: AppTheme.gold.opacity(0.4), radius: 16, y: 4)
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 46))
                            .foregroundColor(AppTheme.background)
                    }

                    // Title
                    VStack(spacing: 8) {
                        Text("選擇方案")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("所有方案皆享 3 天免費試用。")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 24)

                    // Trial summary (only when trial expires)
                    if reason == .trialExpired, let summary = trialSummary {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("試用期回顧")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(AppTheme.gold)
                            Text(summary)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppTheme.cardBackground)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                    }

                    // Plan options (Apple Music-style selectable cards)
                    VStack(spacing: 12) {
                        ForEach(Plan.allCases) { plan in
                            planCard(plan)
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 20)

                    // Subscribe CTA
                    VStack(spacing: 10) {
                        Button(action: subscribeTapped) {
                            HStack {
                                if isSubscribing {
                                    ProgressView().tint(AppTheme.background)
                                } else {
                                    Text("開始免費試用")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(AppTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "F4E29A"), AppTheme.gold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(14)
                        }
                        .disabled(isSubscribing)

                        Text("方案每 \(selectedPlan == .monthly ? "月" : "年") 自動續訂，可隨時在 App Store 取消。")
                            .font(.caption2)
                            .foregroundColor(AppTheme.textMuted)
                            .multilineTextAlignment(.center)

                        if reason == .dailyLimitReached {
                            Button("明天再來") { dismiss() }
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }

            // Close button (top-right)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(10)
                    .background(Circle().fill(AppTheme.cardBackground))
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Plan card

    @ViewBuilder
    private func planCard(_ plan: Plan) -> some View {
        let selected = plan == selectedPlan
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPlan = plan
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(selected ? AppTheme.gold : AppTheme.textMuted.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(AppTheme.gold)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.displayName)
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(plan.priceLine)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selected ? AppTheme.gold : AppTheme.textSecondary)
                    }
                    Text(plan.subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppTheme.gold : Color.clear, lineWidth: 2)
            )
        }
    }

    private func subscribeTapped() {
        isSubscribing = true
        Task {
            defer { isSubscribing = false }
            // TODO: swap this stub for a real StoreKit 2 purchase flow tied to
            // App Store product IDs (com.awaken.monthly / com.awaken.yearly).
            // For now we tell the backend to flip the plan and dismiss.
            if let url = URL(string: "https://awaken-gamma.vercel.app/user/upgrade"),
               let token = BackendAPIService.shared.accessToken {
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: req)
            }
            await auth.refreshStatus()
            dismiss()
        }
    }
}
