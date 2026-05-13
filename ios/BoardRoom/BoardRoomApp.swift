import SwiftUI
import FirebaseCore

@main
struct BoardRoomApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var auth = AuthService.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isSignedIn {
                    ContentView()
                        .environmentObject(settingsManager)
                        .environmentObject(auth)
                } else {
                    LoginView()
                        .environmentObject(auth)
                }
            }
            .preferredColorScheme(.dark)
            .task {
                // Refresh user status on launch
                if auth.isSignedIn {
                    await auth.refreshStatus()
                }
                // Request Reminders access
                let calService = CalendarService.shared
                if calService.reminderAuthStatus != .fullAccess {
                    _ = await calService.requestReminderAccess()
                }
            }
        }
    }
}
