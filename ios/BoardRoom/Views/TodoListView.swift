import SwiftUI

struct TodoListView: View {
    @ObservedObject private var persistence = PersistenceController.shared
    @State private var showAddSheet = false
    @State private var newTodoTitle = ""
    @State private var newTodoPriority: TodoItem.Priority = .medium
    @State private var newTodoDueDate: Date?
    @State private var hasDueDate = false
    @State private var filterPriority: TodoItem.Priority?

    var filteredTodos: [TodoItem] {
        var items = persistence.todos
        if let filter = filterPriority {
            items = items.filter { $0.priority == filter }
        }
        return items.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            if a.priority != b.priority { return a.priority < b.priority }
            return a.createdAt > b.createdAt
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if persistence.todos.isEmpty {
                    emptyState
                } else {
                    todoList
                }
            }
            .navigationTitle("待辦事項")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(AppTheme.gold)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("全部") { filterPriority = nil }
                        ForEach(TodoItem.Priority.allCases, id: \.self) { p in
                            Button(p.label) { filterPriority = p }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(filterPriority != nil ? AppTheme.gold : AppTheme.textMuted)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addTodoSheet
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.textMuted)

            Text("暫無待辦事項")
                .font(.headline)
                .foregroundColor(AppTheme.textSecondary)

            Text("在會議中產生的待辦會自動出現在這裡")
                .font(.caption)
                .foregroundColor(AppTheme.textMuted)

            Button("新增待辦") { showAddSheet = true }
                .foregroundColor(AppTheme.gold)
                .padding(.top, 8)
        }
    }

    private var todoList: some View {
        List {
            ForEach(filteredTodos) { todo in
                todoRow(todo)
                    .listRowBackground(AppTheme.cardBackground)
                    .listRowSeparatorTint(AppTheme.border)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    persistence.deleteTodo(filteredTodos[index])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func todoRow(_ todo: TodoItem) -> some View {
        HStack(spacing: 12) {
            Button {
                persistence.toggleTodo(todo)
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? AppTheme.success : AppTheme.textMuted)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(todo.title)
                    .font(.body)
                    .foregroundColor(todo.isCompleted ? AppTheme.textMuted : AppTheme.textPrimary)
                    .strikethrough(todo.isCompleted)

                HStack(spacing: 8) {
                    priorityBadge(todo.priority)

                    if let dueDate = todo.dueDate {
                        let formatter = DateFormatter()
                        let _ = formatter.dateFormat = "MM/dd"
                        Label(formatter.string(from: dueDate), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(
                                dueDate < Date() && !todo.isCompleted
                                ? AppTheme.destructive
                                : AppTheme.textMuted
                            )
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func priorityBadge(_ priority: TodoItem.Priority) -> some View {
        Text(priority.label)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: priority.color))
            .cornerRadius(4)
    }

    private var addTodoSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                Form {
                    Section {
                        TextField("待辦事項", text: $newTodoTitle)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .listRowBackground(AppTheme.cardBackground)

                    Section {
                        Picker("優先級", selection: $newTodoPriority) {
                            ForEach(TodoItem.Priority.allCases, id: \.self) { p in
                                Text(p.label).tag(p)
                            }
                        }
                        .foregroundColor(AppTheme.textPrimary)

                        Toggle("設定截止日", isOn: $hasDueDate)
                            .foregroundColor(AppTheme.textPrimary)
                            .tint(AppTheme.gold)

                        if hasDueDate {
                            DatePicker("截止日", selection: Binding(
                                get: { newTodoDueDate ?? Date() },
                                set: { newTodoDueDate = $0 }
                            ), displayedComponents: [.date])
                            .foregroundColor(AppTheme.textPrimary)
                        }
                    }
                    .listRowBackground(AppTheme.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("新增待辦")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showAddSheet = false
                        resetForm()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        let todo = TodoItem(
                            title: newTodoTitle,
                            priority: newTodoPriority,
                            dueDate: hasDueDate ? newTodoDueDate : nil
                        )
                        persistence.saveTodo(todo)
                        showAddSheet = false
                        resetForm()
                    }
                    .foregroundColor(AppTheme.gold)
                    .disabled(newTodoTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func resetForm() {
        newTodoTitle = ""
        newTodoPriority = .medium
        newTodoDueDate = nil
        hasDueDate = false
    }
}
