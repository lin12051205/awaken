import SwiftUI
import EventKit

struct CalendarTabView: View {
    @StateObject private var calendarService = CalendarService.shared
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var events: [EKEvent] = []
    @State private var viewMode: ViewMode = .month

    enum ViewMode: String, CaseIterable {
        case month = "月"
        case week = "週"
    }

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                if calendarService.authorizationStatus == .fullAccess {
                    calendarContent
                } else {
                    requestAccessView
                }
            }
            .navigationTitle("行事曆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            }
        }
    }

    private var requestAccessView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.gold)

            Text("需要行事曆存取權限")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            Text("Board Room 需要存取你的行事曆，以便自動整合會議中提到的事件。")
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("授權存取") {
                Task {
                    _ = await calendarService.requestAccess()
                    loadEvents()
                }
            }
            .foregroundColor(AppTheme.background)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(AppTheme.gold)
            .cornerRadius(8)
        }
    }

    private var calendarContent: some View {
        VStack(spacing: 0) {
            if viewMode == .month {
                monthView
            } else {
                weekView
            }

            Divider().background(AppTheme.border)

            // Events list
            eventsList
        }
        .onAppear { loadEvents() }
        .onChange(of: selectedDate) { _, _ in loadEvents() }
    }

    // MARK: - Month View

    private var monthView: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(AppTheme.gold)
                }

                Spacer()

                Text(monthYearString(from: currentMonth))
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.gold)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(AppTheme.textMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Days grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dayCell(date: date)
                    } else {
                        Text("")
                            .frame(height: 36)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    private func dayCell(date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)

        return Button {
            selectedDate = date
        } label: {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isSelected ? AppTheme.background : (isToday ? AppTheme.gold : AppTheme.textPrimary))
                .frame(width: 36, height: 36)
                .background(isSelected ? AppTheme.gold : Color.clear)
                .clipShape(Circle())
        }
    }

    // MARK: - Week View

    private var weekView: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: { changeWeek(by: -1) }) {
                    Image(systemName: "chevron.left").foregroundColor(AppTheme.gold)
                }

                Spacer()

                Text(weekRangeString())
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Button(action: { changeWeek(by: 1) }) {
                    Image(systemName: "chevron.right").foregroundColor(AppTheme.gold)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 4) {
                ForEach(weekDays(), id: \.self) { date in
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)

                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 4) {
                            Text(weekdayShort(date))
                                .font(.caption2)
                                .foregroundColor(AppTheme.textMuted)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                                .foregroundColor(isSelected ? AppTheme.background : AppTheme.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? AppTheme.gold : Color.clear)
                                .clipShape(Circle())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Events List

    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if events.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.title)
                            .foregroundColor(AppTheme.textMuted)
                        Text("這天沒有事件")
                            .font(.caption)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(events, id: \.eventIdentifier) { event in
                        eventRow(event)
                    }
                }
            }
            .padding()
        }
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(cgColor: event.calendar.cgColor))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "")
                    .font(.body)
                    .foregroundColor(AppTheme.textPrimary)

                if let start = event.startDate {
                    let formatter = DateFormatter()
                    let _ = formatter.dateFormat = "HH:mm"
                    Text(formatter.string(from: start))
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .cornerRadius(8)
    }

    // MARK: - Helpers

    private func loadEvents() {
        let start = calendar.startOfDay(for: selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        events = calendarService.fetchEvents(from: start, to: end)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func changeWeek(by value: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }

    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 M 月"
        formatter.locale = Locale(identifier: "zh_Hant")
        return formatter.string(from: date)
    }

    private func weekRangeString() -> String {
        let days = weekDays()
        guard let first = days.first, let last = days.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: first)) — \(formatter.string(from: last))"
    }

    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1

        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func weekDays() -> [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func weekdayShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "zh_Hant")
        return formatter.string(from: date)
    }
}
