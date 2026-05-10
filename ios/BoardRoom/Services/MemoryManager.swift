import Foundation

class MemoryManager: ObservableObject {
    static let shared = MemoryManager()

    @Published var memories: [Memory] = []

    private let memoriesFile: URL

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BoardRoom")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        memoriesFile = dir.appendingPathComponent("memories.json")
        loadMemories()
    }

    func saveMemory(_ memory: Memory) {
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            memories[index] = memory
        } else {
            memories.append(memory)
        }
        persistMemories()
    }

    func deleteMemory(_ memory: Memory) {
        memories.removeAll { $0.id == memory.id }
        persistMemories()
    }

    func deleteMemory(at offsets: IndexSet) {
        memories.remove(atOffsets: offsets)
        persistMemories()
    }

    func formattedForSystemPrompt() -> String {
        guard !memories.isEmpty else { return "" }

        let lines = memories.map { memory in
            "- [\(memory.category.rawValue)] \(memory.content)"
        }

        return """
        ## 關於這位用戶（已記住的資訊）
        \(lines.joined(separator: "\n"))

        請根據這些記憶來個性化你的回答，主動運用這些資訊來幫助用戶。
        """
    }

    private func loadMemories() {
        guard let data = try? Data(contentsOf: memoriesFile),
              let loaded = try? JSONDecoder().decode([Memory].self, from: data) else { return }
        memories = loaded
    }

    private func persistMemories() {
        if let data = try? JSONEncoder().encode(memories) {
            try? data.write(to: memoriesFile)
        }
    }
}
