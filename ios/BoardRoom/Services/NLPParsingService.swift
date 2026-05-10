import Foundation

struct ParsedIntent {
    enum IntentType {
        case calendarEvent(title: String, date: Date, endDate: Date?)
        case todoItem(title: String, priority: TodoItem.Priority, dueDate: Date?)
        case none
    }

    let type: IntentType
    let rawText: String
}

class NLPParsingService {
    static let shared = NLPParsingService()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant")
        return f
    }()

    func parseIntent(from text: String) -> ParsedIntent {
        let lower = text.lowercased()

        // Calendar event patterns
        if let eventIntent = parseCalendarEvent(from: lower, original: text) {
            return eventIntent
        }

        // Todo patterns
        if let todoIntent = parseTodoItem(from: lower, original: text) {
            return todoIntent
        }

        return ParsedIntent(type: .none, rawText: text)
    }

    private func parseCalendarEvent(from text: String, original: String) -> ParsedIntent? {
        let timePatterns: [(String, (Calendar, Date) -> Date?)] = [
            ("今天", { cal, now in now }),
            ("明天", { cal, now in cal.date(byAdding: .day, value: 1, to: now) }),
            ("後天", { cal, now in cal.date(byAdding: .day, value: 2, to: now) }),
            ("下週", { cal, now in cal.date(byAdding: .weekOfYear, value: 1, to: now) }),
        ]

        let hourPattern = try? NSRegularExpression(pattern: "(上午|下午|早上|晚上)?(\\d{1,2})[點:時](\\d{1,2})?[分]?")
        let now = Date()

        var targetDate: Date?
        var title = original

        for (keyword, resolver) in timePatterns {
            if text.contains(keyword) {
                targetDate = resolver(calendar, now)
                title = title.replacingOccurrences(of: keyword, with: "").trimmingCharacters(in: .whitespaces)
                break
            }
        }

        if let match = hourPattern?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let period = match.range(at: 1).location != NSNotFound
                ? String(text[Range(match.range(at: 1), in: text)!]) : nil
            let hourStr = String(text[Range(match.range(at: 2), in: text)!])
            var hour = Int(hourStr) ?? 0
            let minute = match.range(at: 3).location != NSNotFound
                ? Int(String(text[Range(match.range(at: 3), in: text)!])) ?? 0 : 0

            if let period = period, (period == "下午" || period == "晚上") && hour < 12 {
                hour += 12
            }

            let base = targetDate ?? now
            targetDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base)

            // Clean time from title
            if let range = Range(match.range, in: text) {
                title = title.replacingOccurrences(of: String(text[range]), with: "")
            }
        }

        guard targetDate != nil else { return nil }

        // Clean common verbs
        let cleanWords = ["去", "要", "需要", "記得", "幫我", "提醒我"]
        for word in cleanWords {
            title = title.replacingOccurrences(of: word, with: "")
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return nil }

        return ParsedIntent(
            type: .calendarEvent(title: title, date: targetDate!, endDate: targetDate?.addingTimeInterval(3600)),
            rawText: original
        )
    }

    private func parseTodoItem(from text: String, original: String) -> ParsedIntent? {
        let todoKeywords = ["待辦", "要做", "任務", "記下", "要交", "需要完成"]
        guard todoKeywords.contains(where: { text.contains($0) }) else { return nil }

        var priority: TodoItem.Priority = .medium
        if text.contains("緊急") || text.contains("重要") || text.contains("趕快") {
            priority = .high
        } else if text.contains("有空") || text.contains("之後") {
            priority = .low
        }

        var title = original
        let cleanWords = ["待辦", "要做", "任務", "記下", "要交", "需要完成", "幫我", "提醒我"]
        for word in cleanWords {
            title = title.replacingOccurrences(of: word, with: "")
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else { return nil }

        // Parse due date
        var dueDate: Date?
        let now = Date()
        if text.contains("明天") {
            dueDate = calendar.date(byAdding: .day, value: 1, to: now)
        } else if text.contains("後天") {
            dueDate = calendar.date(byAdding: .day, value: 2, to: now)
        } else if text.contains("下週") {
            dueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        }

        return ParsedIntent(
            type: .todoItem(title: title, priority: priority, dueDate: dueDate),
            rawText: original
        )
    }
}
