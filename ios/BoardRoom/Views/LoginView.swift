import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 72))
                        .foregroundColor(AppTheme.gold)

                    Text("AWAKEN")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("你的 AI 個人董事會")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                }

                // Trial info
                VStack(spacing: 12) {
                    featureRow(icon: "sparkles", text: "三位 AI 董事，全方位建議")
                    featureRow(icon: "calendar", text: "智能行程 & 待辦事項管理")
                    featureRow(icon: "brain", text: "長期記憶，越用越了解你")
                }
                .padding(.horizontal, 40)

                // Trial badge
                Text("🎁 免費試用 3 天・每日 12 次對話")
                    .font(.caption)
                    .foregroundColor(AppTheme.gold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.gold.opacity(0.1))
                    .cornerRadius(20)

                Spacer()

                // Sign in button
                VStack(spacing: 16) {
                    if auth.isLoading {
                        ProgressView()
                            .tint(AppTheme.gold)
                            .frame(height: 50)
                    } else {
                        Button {
                            errorMessage = nil
                            auth.lastError = nil
                            Task {
                                await auth.signInWithApple()
                                if !auth.isSignedIn {
                                    errorMessage = auth.lastError ?? "登入失敗，請再試一次"
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18, weight: .medium))
                                Text("以 Apple 帳號登入")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Text("登入即表示同意我們的服務條款與隱私政策")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.gold)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
        }
    }
}
