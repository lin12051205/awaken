import SwiftUI

@main
struct BoardRoomApp: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(settingsManager)
                .preferredColorScheme(.dark)
                .task {
                    // Request Reminders access on launch
                    let calService = CalendarService.shared
                    if calService.reminderAuthStatus != .fullAccess {
                        _ = await calService.requestReminderAccess()
                    }
                }
        }
    }
}
