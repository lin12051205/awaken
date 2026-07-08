import SwiftUI

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

// MARK: - Subscription Card (Apple Music-style gradient card with plan tab)

private struct SubscriptionCard: View {
    enum Tab { case free, paid }

    let currentPlan: String        // "trial" / "paid"
    let onUpgrade: () -> Void

    @State private var selectedTab: Tab

    init(currentPlan: String, onUpgrade: @escaping () -> Void) {
        self.currentPlan = currentPlan
        self.onUpgrade = onUpgrade
        _selectedTab = State(initialValue: currentPlan == "paid" ? .paid : .free)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Plan switch tab
            Picker("方案", selection: $selectedTab) {
                Text("一般").tag(Tab.free)
                Text("付費").tag(Tab.paid)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)

            // Card content
            Group {
                if selectedTab == .free {
                    freeContent
                } else {
                    paidContent
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: selectedTab == .paid
                    ? [Color(hex: "3C2A0F"), Color(hex: "1A1207")]
                    : [Color(hex: "5A3F14"), Color(hex: "2A1D08")],
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

    // MARK: - Free tab content

    private var freeContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(AppTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("一般會員")
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(currentPlan == "trial" ? "免費使用中" : "目前的方案")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                benefitRow(icon: "sparkles",   text: "解鎖更高每日對話上限")
                benefitRow(icon: "person.3.fill", text: "更多董事人格與能力")
                benefitRow(icon: "brain.head.profile", text: "更長的記憶脈絡")
            }

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
                .padding(.vertical, 12)
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

    // MARK: - Paid tab content

    private var paidContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "crown.fill")
                    .font(.title3)
                    .foregroundColor(AppTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("付費會員")
                        .font(.title3.bold())
                        .foregroundColor(AppTheme.textPrimary)
                    Text(currentPlan == "paid" ? "感謝你的支持" : "尚未升級")
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                benefitRow(icon: "checkmark.circle.fill", text: "更高每日對話上限")
                benefitRow(icon: "checkmark.circle.fill", text: "全部董事人格可用")
                benefitRow(icon: "checkmark.circle.fill", text: "長期記憶脈絡")
            }

            if currentPlan == "paid" {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("管理 / 取消訂閱")
                            .font(.body.weight(.medium))
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .stroke(AppTheme.gold.opacity(0.7), lineWidth: 1)
                    )
                }
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
                    .padding(.vertical, 12)
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
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(AppTheme.gold.opacity(0.85))
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }
}
