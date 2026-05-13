import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var memoryManager = MemoryManager.shared
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                List {
                    // Role Type Section
                    Section {
                        Picker("角色類型", selection: $settings.roleTypeRaw) {
                            ForEach(Director.RoleType.allCases, id: \.rawValue) { type in
                                Text(type.rawValue).tag(type.rawValue)
                            }
                        }
                        .foregroundColor(AppTheme.textPrimary)
                        .pickerStyle(.segmented)
                    } header: {
                        Text("角色設定")
                            .foregroundColor(AppTheme.textMuted)
                    } footer: {
                        Text("職位型：以職能定義角色。人物型：以真實人物風格定義角色。")
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .listRowBackground(AppTheme.cardBackground)

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
