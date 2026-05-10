import Foundation

struct Memory: Identifiable, Codable {
    let id: UUID
    var content: String
    var category: MemoryCategory
    var createdAt: Date

    init(id: UUID = UUID(), content: String, category: MemoryCategory, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.category = category
        self.createdAt = createdAt
    }

    enum MemoryCategory: String, Codable, CaseIterable {
        case routine = "日常習慣"
        case preference = "偏好"
        case context = "背景資訊"
        case schedule = "固定行程"

        var emoji: String {
            switch self {
            case .routine: return "🔄"
            case .preference: return "💡"
            case .context: return "📌"
            case .schedule: return "📅"
            }
        }
    }
}
