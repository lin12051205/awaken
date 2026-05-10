import Foundation

struct TodoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var createdAt: Date
    var meetingId: UUID?
    var reminderIdentifier: String?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, priority: Priority = .medium, dueDate: Date? = nil, createdAt: Date = Date(), meetingId: UUID? = nil, reminderIdentifier: String? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.meetingId = meetingId
        self.reminderIdentifier = reminderIdentifier
    }

    /// EKReminder priority value (1=high, 5=medium, 9=low)
    var ekPriority: Int {
        switch priority {
        case .high: return 1
        case .medium: return 5
        case .low: return 9
        }
    }

    enum Priority: Int, Codable, CaseIterable, Comparable {
        case high = 0
        case medium = 1
        case low = 2

        var label: String {
            switch self {
            case .high: return "高"
            case .medium: return "中"
            case .low: return "低"
            }
        }

        var color: String {
            switch self {
            case .high: return "E74C3C"
            case .medium: return "F39C12"
            case .low: return "2ECC71"
            }
        }

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
