import Foundation
import SwiftUI

@MainActor
class MeetingViewModel: ObservableObject {
    @Published var currentMeeting: Meeting?
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isInMeeting: Bool = false
    @Published var selectedDirector: Director?
    @Published var pendingEvents: [PendingEvent] = []
    @Published var pendingMemory: PendingMemory?

    struct PendingMemory {
        let content: String
        let category: Memory.MemoryCategory
    }

    struct PendingEvent: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let endDate: Date?
    }

    private let apiService = BackendAPIService.shared
    private let nlpService = NLPParsingService.shared
    private let persistence = PersistenceController.shared
    private let settings = SettingsManager.shared
    private let memoryManager = MemoryManager.shared
    private let auth = AuthService.shared

    // Paywall state
    @Published var showPaywall: Bool = false
    @Published var paywallReason: PaywallView.PaywallReason = .dailyLimitReached
    @Published var trialSummary: String? = nil

    // MARK: - Meeting Lifecycle

    func startMeeting() {
        currentMeeting = Meeting(title: dateTitle())
        isInMeeting = true

        let welcomeMsg = MeetingMessage(
            role: .system,
            content: "會議開始。你的 AI 董事會已就位，請提出你想討論的議題。\n\n💡 提醒：AI 董事會是你的思考夥伴，但有其限制 — 無法進行即時網路搜尋或存取外部系統，重大決策仍需以個人判斷為準。"
        )
        currentMeeting?.messages.append(welcomeMsg)
    }

    /// Continue a previously saved meeting
    func continueMeeting(_ meeting: Meeting) {
        var resumed = meeting
        resumed.endedAt = nil
        currentMeeting = resumed
        isInMeeting = true

        let sysMsg = MeetingMessage(
            role: .system,
            content: "會議繼續。歡迎回來，請繼續你的議題。"
        )
        currentMeeting?.messages.append(sysMsg)
    }

    func endMeeting() {
        guard var meeting = currentMeeting else { return }
        meeting.endedAt = Date()

        Task {
            if let summary = await generateSummary(for: meeting) {
                meeting.summary = summary
            }
            persistence.saveMeeting(meeting)
        }

        isInMeeting = false
        currentMeeting = nil
        inputText = ""
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        let userMessage = MeetingMessage(role: .user, content: text)
        currentMeeting?.messages.append(userMessage)
        inputText = ""

        Task {
            await processMessage(text)
        }
    }

    /// Core message processing pipeline: Analyze → Create items → Query ALL directors → Detect Memory
    private func processMessage(_ userMessage: String) async {
        isLoading = true
        errorMessage = nil

        // Step 1: Analyze message (todo + calendar + routing + memory in ONE API call using Haiku)
        let analysis = await analyzeMessage(userMessage)

        // Step 2: Create todos if detected — save locally, optionally sync to Apple Reminders
        if !analysis.todos.isEmpty {
            let shouldSyncReminders = settings.syncTodosToReminders
            let calService = CalendarService.shared

            // Only request Reminders permission if user wants the sync
            if shouldSyncReminders && calService.reminderAuthStatus != .fullAccess {
                _ = await calService.requestReminderAccess()
            }

            for todo in analysis.todos {
                let item = TodoItem(title: todo.title, priority: todo.priority, meetingId: currentMeeting?.id)
                persistence.saveTodo(item)

                if shouldSyncReminders {
                    // Map our priority → EKReminder priority (1=high, 5=medium, 9=low)
                    let ekPriority: Int
                    switch todo.priority {
                    case .high:   ekPriority = 1
                    case .medium: ekPriority = 5
                    case .low:    ekPriority = 9
                    }
                    _ = calService.createReminder(
                        title: todo.title,
                        dueDate: nil,
                        priority: ekPriority,
                        notes: "由 AWAKEN 董事會建立"
                    )
                }
            }
            let todoNames = analysis.todos.map { "• \($0.title)" }.joined(separator: "\n")
            let suffix = shouldSyncReminders ? "（已同步至提醒事項）" : ""
            let sysMsg = MeetingMessage(role: .system, content: "✅ 已加入 \(analysis.todos.count) 個待辦事項\(suffix)：\n\(todoNames)")
            currentMeeting?.messages.append(sysMsg)
        }

        // Step 3: Show calendar event previews if detected
        if !analysis.events.isEmpty {
            pendingEvents = analysis.events.map { event in
                PendingEvent(title: event.title, date: event.date, endDate: event.endDate)
            }
        }

        // Step 4: Query directors — route to relevant directors based on analysis
        let directors: [Director]
        if let specific = selectedDirector {
            directors = [specific]
            selectedDirector = nil
        } else if !analysis.targetDirectors.isEmpty {
            let routed = settings.enabledDirectors.filter { analysis.targetDirectors.contains($0.directorKey) }
            directors = routed.isEmpty ? settings.enabledDirectors : routed
        } else {
            directors = settings.enabledDirectors
        }

        let contextBlock = buildContextBlock()
        let timeContext = currentTimeContext()

        for director in directors {
            do {
                let history = buildConversationHistory(for: director)
                let fullSystemPrompt = "\(timeContext)\n\n\(contextBlock.isEmpty ? "" : "\(contextBlock)\n\n")\(director.systemPrompt)"

                let response = try await apiService.sendMessage(
                    userMessage: userMessage,
                    conversationHistory: history,
                    systemPrompt: fullSystemPrompt
                )

                let directorMsg = MeetingMessage(
                    role: .director,
                    content: response,
                    director: director
                )
                currentMeeting?.messages.append(directorMsg)
            } catch let error as BackendAPIService.BackendError {
                switch error {
                case .trialExpired:
                    paywallReason = .trialExpired
                    await fetchTrialSummary()
                    showPaywall = true
                case .dailyLimitReached:
                    paywallReason = .dailyLimitReached
                    showPaywall = true
                default:
                    errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false

        // Auto-save
        if let meeting = currentMeeting {
            persistence.saveMeeting(meeting)
        }

        // Step 5: Handle memory from analysis (no separate API call needed)
        if let mem = analysis.memory {
            let categoryStr = mem.category
            let category: Memory.MemoryCategory
            switch categoryStr {
            case "routine": category = .routine
            case "preference": category = .preference
            case "schedule": category = .schedule
            default: category = .context
            }
            let isDuplicate = memoryManager.memories.contains { $0.content == mem.content }
            if !isDuplicate {
                pendingMemory = PendingMemory(content: mem.content, category: category)
            }
        }
    }

    // MARK: - Message Analysis (Todo + Calendar Extraction)

    struct AnalysisResult {
        let todos: [(title: String, priority: TodoItem.Priority)]
        let events: [(title: String, date: Date, endDate: Date?)]
        let targetDirectors: [String] // directorKey values: "ceo", "finance", "devil"
        let memory: (content: String, category: String)? // merged memory detection
    }

    private func analyzeMessage(_ message: String) async -> AnalysisResult {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_Hant")
        let nowStr = formatter.string(from: now)

        let calFormatter = DateFormatter()
        calFormatter.dateFormat = "EEEE"
        calFormatter.locale = Locale(identifier: "zh_Hant")
        let weekday = calFormatter.string(from: now)

        let directorList = settings.enabledDirectors.map { "\($0.directorKey)（\($0.name)：\($0.title)）" }.joined(separator: "\n- ")

        let systemPrompt = """
        你是一個訊息分析器。現在時間是 \(nowStr)（\(weekday)）。
        分析使用者的訊息，完成四項任務：

        任務一：判斷訊息是否包含待辦事項或任務。
        - 如果包含多個任務（例如「讀電子學、弄資料庫、打報告」），要拆分成多個項目
        - 只有明確的「要做的事」才算待辦，閒聊不算
        - 如果有明確時間（例如「下午三點去洗衣服」），不要放在 todos，放在 events

        任務二：判斷訊息是否包含行事曆事件（有明確時間的事情）。
        - 例如「下午三點去洗衣服」→ 一個 event
        - 例如「明天兩點開會、四點看牙醫」→ 兩個 events
        - 支援拆分：如果一句話有多個有時間的事件，拆成多個
        - date 格式必須是 ISO 8601：yyyy-MM-dd'T'HH:mm:ss
        - 根據「今天」「明天」「後天」「下週一」等詞彙推算正確日期
        - 「上午」「早上」= AM，「下午」「晚上」= PM

        任務三：判斷哪些董事最適合回應這個訊息。
        可用的董事：
        - \(directorList)

        路由規則：
        - 投資、理財、預算、花費相關 → 只選 finance
        - 挑戰假設、質疑、反面思考、找盲點 → 只選 devil
        - 執行卡點、拖延、假忙碌、優先級混亂、想做太多、拆任務、推進進度、降低完美主義 → 只選 coo
        - 用戶在描述「我又在做 X 而不是 Y」「我一直在重構/查資料/換 UI」「我做不完」等情況 → 只選 coo
        - 願景、策略、人生方向、品牌、長期規劃、時間整體分配 → 只選 ceo
        - 一般日常問題 → 只選 ceo
        - 涉及多個領域的複雜問題 → 選多個相關的董事
        - 如果不確定，選 ceo

        任務四：判斷訊息是否透露了值得長期記住的習慣、偏好或固定行程。
        - 「我每天九點上班」→ schedule
        - 「我早上都會去晨跑」→ routine
        - 「我不喜歡開會」→ preference
        - 「我是設計師」→ context
        - 一般閒聊或提問不算

        回傳格式（只回傳 JSON，不要其他文字）：
        {
          "todos": [],
          "events": [],
          "directors": ["ceo"],
          "memory": null
        }

        memory 格式（如果偵測到）：{"content": "簡潔描述", "category": "routine"}
        memory 為 null 表示沒有偵測到
        category 可選值：routine, preference, context, schedule
        priority 可選值：high, medium, low
        directors 至少要有一個
        """

        do {
            let response = try await apiService.sendAnalysisMessage(
                userMessage: message,
                systemPrompt: systemPrompt,
                maxTokens: 512
            )

            let jsonString = extractJSON(from: response)

            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // Parse todos
                var todos: [(String, TodoItem.Priority)] = []
                if let todoArray = json["todos"] as? [[String: String]] {
                    for item in todoArray {
                        if let title = item["title"], !title.isEmpty {
                            let priority: TodoItem.Priority
                            switch item["priority"] {
                            case "high": priority = .high
                            case "low": priority = .low
                            default: priority = .medium
                            }
                            todos.append((title, priority))
                        }
                    }
                }

                // Parse events
                var events: [(String, Date, Date?)] = []
                if let eventArray = json["events"] as? [[String: Any]] {
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                    let simpleFormatter = DateFormatter()
                    simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    simpleFormatter.locale = Locale(identifier: "en_US_POSIX")

                    for item in eventArray {
                        if let title = item["title"] as? String,
                           let dateStr = item["date"] as? String {
                            if let date = simpleFormatter.date(from: dateStr) ?? isoFormatter.date(from: dateStr) {
                                let duration = item["duration_minutes"] as? Int ?? 60
                                let endDate = date.addingTimeInterval(TimeInterval(duration * 60))
                                events.append((title, date, endDate))
                            }
                        }
                    }
                }

                // Parse directors
                let targetDirectors = json["directors"] as? [String] ?? ["ceo"]

                // Parse memory
                var memory: (String, String)? = nil
                if let memDict = json["memory"] as? [String: String],
                   let content = memDict["content"],
                   let category = memDict["category"] {
                    memory = (content, category)
                }

                return AnalysisResult(todos: todos, events: events, targetDirectors: targetDirectors, memory: memory)
            }
        } catch {
            // Silently fall back
        }

        return AnalysisResult(todos: [], events: [], targetDirectors: ["ceo"], memory: nil)
    }

    // MARK: - Calendar Events

    func confirmAllEvents() {
        let calService = CalendarService.shared
        Task {
            if calService.authorizationStatus != .fullAccess {
                _ = await calService.requestAccess()
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd HH:mm"

            for event in pendingEvents {
                if let _ = calService.createEvent(title: event.title, startDate: event.date, endDate: event.endDate) {
                    let sysMsg = MeetingMessage(role: .system, content: "📅 已建立：\(event.title)（\(formatter.string(from: event.date))）")
                    currentMeeting?.messages.append(sysMsg)
                }
            }
            pendingEvents = []
        }
    }

    func dismissAllEvents() {
        pendingEvents = []
    }

    func sendToSpecificDirector(_ director: Director) {
        selectedDirector = director
        sendMessage()
    }

    // MARK: - Memory Detection

    private func detectMemory(from message: String) async {
        let systemPrompt = """
        分析使用者的訊息，判斷是否透露了值得長期記住的習慣、偏好或固定行程。

        例如：
        - 「我每天九點上班」→ 固定行程
        - 「我早上都會去晨跑」→ 日常習慣
        - 「我不喜歡開會」→ 偏好
        - 「我是設計師」→ 背景資訊

        如果偵測到，回傳：
        {"detected": true, "content": "簡潔描述這個記憶", "category": "routine"}

        category 可選值：routine（日常習慣）, preference（偏好）, context（背景資訊）, schedule（固定行程）

        如果沒有值得記住的內容，回傳：
        {"detected": false}

        只回傳 JSON，不要其他文字。
        """

        do {
            let response = try await apiService.sendAnalysisMessage(
                userMessage: message,
                systemPrompt: systemPrompt,
                maxTokens: 128
            )

            let jsonString = extractJSON(from: response)

            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detected = json["detected"] as? Bool, detected,
               let content = json["content"] as? String {

                let categoryStr = json["category"] as? String ?? "context"
                let category: Memory.MemoryCategory
                switch categoryStr {
                case "routine": category = .routine
                case "preference": category = .preference
                case "schedule": category = .schedule
                default: category = .context
                }

                let isDuplicate = memoryManager.memories.contains { $0.content == content }
                if !isDuplicate {
                    pendingMemory = PendingMemory(content: content, category: category)
                }
            }
        } catch {
            // Silently ignore
        }
    }

    func confirmMemorySave() {
        guard let pending = pendingMemory else { return }
        let memory = Memory(content: pending.content, category: pending.category)
        memoryManager.saveMemory(memory)

        let sysMsg = MeetingMessage(role: .system, content: "🧠 已記住：\(pending.content)")
        currentMeeting?.messages.append(sysMsg)
        pendingMemory = nil
    }

    func dismissMemory() {
        pendingMemory = nil
    }

    // MARK: - Context Building

    private func buildContextBlock() -> String {
        var blocks: [String] = []

        let memoriesContext = memoryManager.formattedForSystemPrompt()
        if !memoriesContext.isEmpty {
            blocks.append(memoriesContext)
        }

        let scheduleContext = buildScheduleContext()
        if !scheduleContext.isEmpty {
            blocks.append(scheduleContext)
        }

        return blocks.joined(separator: "\n\n")
    }

    private func buildScheduleContext() -> String {
        let calService = CalendarService.shared
        guard calService.authorizationStatus == .fullAccess else { return "" }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return "" }
        let events = calService.fetchEvents(from: today, to: tomorrow)

        guard !events.isEmpty else { return "## 今日行程\n今天行事曆目前沒有事件。" }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        let lines = events.map { event in
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            return "- \(start)~\(end)：\(event.title ?? "無標題")"
        }

        return "## 今日行程\n\(lines.joined(separator: "\n"))\n\n請根據用戶的現有行程，在建議排程時避開已有事件的時段。"
    }

    // MARK: - Conversation History

    /// Build conversation history for a specific director.
    /// Only includes that director's own responses as "assistant" — other directors' messages are
    /// included as user context to avoid the AI mimicking another director's identity.
    /// Limited to the last 10 user messages (+ associated responses) to control token costs.
    private func buildConversationHistory(for director: Director? = nil) -> [BackendAPIService.ChatMessage] {
        guard let meeting = currentMeeting else { return [] }

        // The last message in currentMeeting is the user message currently being processed.
        // BackendAPIService.sendMessage appends it separately, so we must exclude it here —
        // otherwise the Anthropic API rejects the request (consecutive user messages).
        var allMessages = meeting.messages
        if allMessages.last?.role == .user {
            allMessages.removeLast()
        }

        // Find the last 10 user message indices to limit context window
        let userIndices = allMessages.enumerated().compactMap { (i, msg) in
            msg.role == .user ? i : nil
        }
        let cutoffIndex: Int
        if userIndices.count > 10 {
            cutoffIndex = userIndices[userIndices.count - 10]
        } else {
            cutoffIndex = 0
        }

        var result: [BackendAPIService.ChatMessage] = []

        for (i, msg) in allMessages.enumerated() {
            guard i >= cutoffIndex else { continue }
            switch msg.role {
            case .user:
                result.append(BackendAPIService.ChatMessage(role: "user", content: msg.content))
            case .director:
                if let director = director, msg.directorName == director.name {
                    result.append(BackendAPIService.ChatMessage(role: "assistant", content: msg.content))
                } else if let name = msg.directorName {
                    result.append(BackendAPIService.ChatMessage(role: "user", content: "[其他董事 \(name) 的觀點]：\(msg.content)"))
                }
            case .system:
                break
            }
        }

        return result
    }

    // MARK: - Summary Generation

    private func fetchTrialSummary() async {
        guard let token = BackendAPIService.shared.accessToken,
              let url = URL(string: "https://awaken-gamma.vercel.app/user/trial-summary") else { return }

        let messages = currentMeeting?.messages.compactMap { msg -> [String: String]? in
            switch msg.role {
            case .user: return ["role": "user", "content": msg.content]
            case .director: return ["role": "assistant", "content": msg.content]
            case .system: return nil
            }
        } ?? []

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["conversations": messages])

        if let (data, _) = try? await URLSession.shared.data(for: req),
           let json = try? JSONDecoder().decode([String: String].self, from: data) {
            trialSummary = json["summary"]
        }
    }

    private func generateSummary(for meeting: Meeting) async -> String? {

        let transcript = meeting.messages.map { msg -> String in
            switch msg.role {
            case .user: return "用戶：\(msg.content)"
            case .director: return "\(msg.directorName ?? "AI")：\(msg.content)"
            case .system: return ""
            }
        }.joined(separator: "\n")

        let summaryPrompt = """
        請根據以下會議記錄，生成三項輸出（繁體中文）：
        1. 每日摘要：3-5 個重點洞察
        2. 待辦清單：列出可行動項目，附優先級（高/中/低）
        3. 建議日程：時間表建議

        會議記錄：
        \(transcript)
        """

        do {
            return try await apiService.sendAnalysisMessage(
                userMessage: summaryPrompt,
                systemPrompt: "你是一位會議記錄秘書，擅長從對話中提取重點和行動項目。回答請用繁體中文，使用 Markdown 格式。",
                maxTokens: 1024
            )
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func currentTimeContext() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日 EEEE HH:mm"
        formatter.locale = Locale(identifier: "zh_Hant")
        let timeStr = formatter.string(from: now)

        return """
        ## 現在時間
        \(timeStr)

        請根據現在的時間來給出合適的建議。例如深夜時提醒用戶休息、早晨鼓勵開始一天的計畫、用餐時間注意飲食等。自然地融入對話，不要每次都刻意提到時間。
        """
    }

    private func dateTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        formatter.locale = Locale(identifier: "zh_Hant")
        return "董事會議 \(formatter.string(from: Date()))"
    }

    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let startRange = trimmed.range(of: "```json"),
           let endRange = trimmed.range(of: "```", range: startRange.upperBound..<trimmed.endIndex) {
            return String(trimmed[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let startRange = trimmed.range(of: "```"),
           let endRange = trimmed.range(of: "```", range: startRange.upperBound..<trimmed.endIndex) {
            return String(trimmed[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        return trimmed
    }
}
