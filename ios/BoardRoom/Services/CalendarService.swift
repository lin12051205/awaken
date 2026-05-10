import EventKit
import Foundation

class CalendarService: ObservableObject {
    static let shared = CalendarService()
    let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthStatus: EKAuthorizationStatus = .notDetermined
    @Published var events: [EKEvent] = []

    init() {
        checkAuthorization()
    }

    func checkAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reminderAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    // MARK: - Calendar Events

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            await MainActor.run {
                self.authorizationStatus = granted ? .fullAccess : .denied
            }
            return granted
        } catch {
            return false
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date) -> [EKEvent] {
        guard authorizationStatus == .fullAccess else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        return events.sorted { $0.startDate < $1.startDate }
    }

    func createEvent(title: String, startDate: Date, endDate: Date?) -> EKEvent? {
        guard authorizationStatus == .fullAccess else { return nil }
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600)
        event.calendar = eventStore.defaultCalendarForNewEvents
        do {
            try eventStore.save(event, span: .thisEvent)
            return event
        } catch {
            print("Failed to save event: \(error)")
            return nil
        }
    }

    func deleteEvent(_ event: EKEvent) -> Bool {
        do {
            try eventStore.remove(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Reminders

    func requestReminderAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                self.reminderAuthStatus = granted ? .fullAccess : .denied
            }
            return granted
        } catch {
            return false
        }
    }

    func createReminder(title: String, dueDate: Date?, priority: Int = 0, notes: String? = nil) -> Bool {
        guard reminderAuthStatus == .fullAccess else { return false }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        reminder.notes = notes

        // Priority: EKReminder uses 1=high, 5=medium, 9=low, 0=none
        reminder.priority = priority

        if let dueDate = dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
            // Add an alarm at the due date
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        do {
            try eventStore.save(reminder, commit: true)
            return true
        } catch {
            print("Failed to save reminder: \(error)")
            return false
        }
    }

    func fetchReminders() async -> [EKReminder] {
        guard reminderAuthStatus == .fullAccess else { return [] }
        let predicate = eventStore.predicateForReminders(in: nil)
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
}
