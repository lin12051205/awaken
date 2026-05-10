import Foundation

struct Meeting: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [MeetingMessage]
    var summary: String?
    var createdAt: Date
    var endedAt: Date?

    init(id: UUID = UUID(), title: String = "", messages: [MeetingMessage] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
    }
}

struct MeetingMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let directorId: UUID?
    let directorName: String?
    let directorEmoji: String?
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, director: Director? = nil, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.directorId = director?.id
        self.directorName = director?.name
        self.directorEmoji = director?.emoji
        self.timestamp = timestamp
    }

    enum MessageRole: String, Codable {
        case user
        case director
        case system
    }
}
