import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @EnvironmentObject private var auth: AuthService
    @StateObject private var memoryManager = MemoryManager.shared
    @State private var showResetAlert = false
    @State private var showSignOutAlert = false
    @State private var showUpgradeSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    // Subscription — Apple Music-style gradient card
                    Section {
                        SubscriptionCard(
                            currentPlan: auth.plan,
                            onUpgrade: { showUpgradeSheet = true }
                        )
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }

                    // Directors Section
                    Section {
                        ForEach(settings.directors.indices, id: \.self) { index in
                            directorRow(index: index)
                        }
                    } header: {
                        HStack {
                            Text("董事會成員")
                                .foregroundColor(AppTheme.textMuted)
                            Spacer()
                            Button("重置") { showResetAlert = true }
                                .font(.caption)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Integrations Section
                    Section {
                        Toggle(isOn: $settings.syncTodosToReminders) {
                            HStack(spacing: 10) {
                                Image(systemName: "checklist")
                                    .foregroundColor(AppTheme.gold)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("同步到提醒事項")
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("AI 偵測到待辦時自動加入蘋果提醒事項")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                        }
                        .tint(AppTheme.gold)
                    } header: {
                        Text("整合")
                            .foregroundColor(AppTheme.textMuted)
                    } footer: {
                        Text("行事曆事件需要在對話中按「全部加入」才會建立，不受此開關影響。")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Memory Section
                    Section {
                        if memoryManager.memories.isEmpty {
                            HStack {
                                Image(systemName: "brain")
                                    .foregroundColor(AppTheme.textMuted)
                                Text("尚無記憶。在對話中提到你的習慣或行程，AI 會提議記住。")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textMuted)
                            }
                        } else {
                            ForEach(memoryManager.memories) { memory in
                                HStack(spacing: 10) {
                                    Text(memory.category.emoji)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(memory.content)
                                            .font(.body)
                                            .foregroundColor(AppTheme.textPrimary)
                                        Text(memory.category.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.textMuted)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .onDelete { offsets in
                                memoryManager.deleteMemory(at: offsets)
                            }
                        }
                    } header: {
                        HStack {
                            Text("記憶")
                                .foregroundColor(AppTheme.textMuted)
                            Spacer()
                            Text("\(memoryManager.memories.count) 則")
                                .font(.caption)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    } footer: {
                        Text("AI 會記住你的習慣、偏好和固定行程，讓回答更個人化。左滑可刪除。")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // Account Section
                    Section {
                        Button(role: .destructive) {
                            showSignOutAlert = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                Text("登出")
                                Spacer()
                            }
                            .foregroundColor(AppTheme.destructive)
                        }
                    } header: {
                        Text("帳號")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    // About Section
                    Section {
                        HStack {
                            Text("版本")
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("1.1.0")
                                .foregroundColor(AppTheme.textMuted)
                        }
                    } header: {
                        Text("關於")
                            .foregroundColor(AppTheme.textMuted)
                    } footer: {
                        VStack(spacing: 8) {
                            Text("⚠️ AI 回覆僅供參考，不構成專業建議。AI 無法進行即時網路搜尋或存取外部資料，重大決策前請諮詢專業人士。")
                                .font(.caption2)
                                .foregroundColor(AppTheme.textMuted)

                            Text("Build in silence, let results make the noise.")
                                .foregroundColor(AppTheme.textMuted)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .alert("重置董事會", isPresented: $showResetAlert) {
                Button("重置", role: .destructive) { settings.resetDirectors() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("確定要重置所有董事會成員為預設值嗎？")
            }
            .alert("登出", isPresented: $showSignOutAlert) {
                Button("登出", role: .destructive) { auth.signOut() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("登出後需要重新以 Apple 帳號登入才能繼續使用。")
            }
            .sheet(isPresented: $showUpgradeSheet) {
                PaywallView(reason: .dailyLimitReached, trialSummary: nil)
                    .environmentObject(auth)
            }
        }
    }

    private func directorRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Text(settings.directors[index].emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.directors[index].name)
                    .font(.body)
                    .foregroundColor(AppTheme.textPrimary)
                Text(settings.directors[index].title)
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $settings.directors[index].isEnabled)
                .tint(AppTheme.gold)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Subscription Card (single-view, no confusing tab)

private struct SubscriptionCard: View {
    let currentPlan: String        // "trial" / "paid"
    let onUpgrade: () -> Void

    @State private var isShowingManage = false
    private var isPaid: Bool { currentPlan == "paid" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "F4E29A"), AppTheme.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: isPaid ? "crown.fill" : "person.fill")
                        .font(.title3)
                        .foregroundColor(AppTheme.background)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isPaid ? "付費會員" : "一般會員")
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(isPaid ? "感謝你的支持" : "免費試用中")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                benefitRow(icon: "checkmark.circle.fill", text: "更高每日對話上限", enabled: isPaid)
                benefitRow(icon: "checkmark.circle.fill", text: "全部董事人格可用", enabled: isPaid)
                benefitRow(icon: "checkmark.circle.fill", text: "長期記憶脈絡",   enabled: isPaid)
            }

            if isPaid {
                Button {
                    isShowingManage = true
                } label: {
                    Text("管理訂閱")
                        .font(.body.weight(.semibold))
                        .foregroundColor(AppTheme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().stroke(AppTheme.gold.opacity(0.7), lineWidth: 1)
                        )
                }
                .manageSubscriptionsSheet(isPresented: $isShowingManage)
            } else {
                Button {
                    onUpgrade()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("升級付費會員")
                            .font(.body.weight(.semibold))
                    }
                    .foregroundColor(AppTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "F4E29A"), AppTheme.gold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(hex: "3F2C10"), Color(hex: "1B1207")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppTheme.gold.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func benefitRow(icon: String, text: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: enabled ? icon : "circle")
                .font(.caption)
                .foregroundColor(enabled ? AppTheme.gold : AppTheme.textMuted.opacity(0.6))
                .frame(width: 16)
            Text(text)
                .font(.subheadline)
                .foregroundColor(enabled ? AppTheme.textPrimary : AppTheme.textSecondary)
            Spacer()
        }
    }
}
