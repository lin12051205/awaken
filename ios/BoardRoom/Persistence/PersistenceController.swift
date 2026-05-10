import CoreData
import EventKit
import SwiftUI

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    // In-memory store for meetings (using Codable + JSON file)
    @Published var meetings: [Meeting] = []
    @Published var todos: [TodoItem] = []

    private let meetingsFile: URL
    private let todosFile: URL

    init() {
        container = NSPersistentContainer(name: "BoardRoom")

        let storeURL = PersistenceController.storeDirectory.appendingPathComponent("BoardRoom.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                print("CoreData error: \(error)")
            }
        }

        let dir = PersistenceController.storeDirectory
        meetingsFile = dir.appendingPathComponent("meetings.json")
        todosFile = dir.appendingPathComponent("todos.json")

        loadMeetings()
        loadTodos()
    }

    private static var storeDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BoardRoom")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Meetings

    func saveMeeting(_ meeting: Meeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        } else {
            meetings.insert(meeting, at: 0)
        }
        persistMeetings()
    }

    func deleteMeeting(_ meeting: Meeting) {
        meetings.removeAll { $0.id == meeting.id }
        persistMeetings()
    }

    private func loadMeetings() {
        guard let data = try? Data(contentsOf: meetingsFile),
              let loaded = try? JSONDecoder().decode([Meeting].self, from: data) else { return }
        meetings = loaded
    }

    private func persistMeetings() {
        if let data = try? JSONEncoder().encode(meetings) {
            try? data.write(to: meetingsFile)
        }
    }

    func searchMeetings(keyword: String) -> [Meeting] {
        guard !keyword.isEmpty else { return meetings }
        return meetings.filter { meeting in
            meeting.title.localizedCaseInsensitiveContains(keyword) ||
            meeting.messages.contains { $0.content.localizedCaseInsensitiveContains(keyword) } ||
            (meeting.summary?.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    // MARK: - Todos

    func saveTodo(_ todo: TodoItem) {
        var item = todo
        // Sync to native Reminders
        if item.reminderIdentifier == nil {
            syncToReminder(&item)
        }
        if let index = todos.firstIndex(where: { $0.id == item.id }) {
            todos[index] = item
        } else {
            todos.append(item)
        }
        persistTodos()
    }

    func deleteTodo(_ todo: TodoItem) {
        // Remove from native Reminders
        if let identifier = todo.reminderIdentifier {
            removeReminder(identifier: identifier)
        }
        todos.removeAll { $0.id == todo.id }
        persistTodos()
    }

    func toggleTodo(_ todo: TodoItem) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].isCompleted.toggle()
            // Update completion status in native Reminders
            if let identifier = todos[index].reminderIdentifier {
                updateReminderCompletion(identifier: identifier, completed: todos[index].isCompleted)
            }
            persistTodos()
        }
    }

    // MARK: - Reminders Sync

    private func syncToReminder(_ todo: inout TodoItem) {
        let calService = CalendarService.shared
        guard calService.reminderAuthStatus == .fullAccess else { return }

        let reminder = EKReminder(eventStore: calService.eventStore)
        reminder.title = todo.title
        reminder.calendar = calService.eventStore.defaultCalendarForNewReminders()
        reminder.priority = todo.ekPriority

        if let dueDate = todo.dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        do {
            try calService.eventStore.save(reminder, commit: true)
            todo.reminderIdentifier = reminder.calendarItemIdentifier
        } catch {
            print("Failed to sync reminder: \(error)")
        }
    }

    private func removeReminder(identifier: String) {
        let calService = CalendarService.shared
        guard let item = calService.eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        do {
            try calService.eventStore.remove(item, commit: true)
        } catch {
            print("Failed to remove reminder: \(error)")
        }
    }

    private func updateReminderCompletion(identifier: String, completed: Bool) {
        let calService = CalendarService.shared
        guard let reminder = calService.eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else { return }
        reminder.isCompleted = completed
        do {
            try calService.eventStore.save(reminder, commit: true)
        } catch {
            print("Failed to update reminder: \(error)")
        }
    }

    private func loadTodos() {
        guard let data = try? Data(contentsOf: todosFile),
              let loaded = try? JSONDecoder().decode([TodoItem].self, from: data) else { return }
        todos = loaded
    }

    private func persistTodos() {
        if let data = try? JSONEncoder().encode(todos) {
            try? data.write(to: todosFile)
        }
    }
}
