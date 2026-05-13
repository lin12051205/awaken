import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MeetingRoomView()
                .tabItem {
                    Image(systemName: "building.columns.fill")
                    Text("會議室")
                }
                .tag(0)

            CalendarTabView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("行事曆")
                }
                .tag(1)

            TodoListView()
                .tabItem {
                    Image(systemName: "checkmark.circle.fill")
                    Text("待辦事項")
                }
                .tag(2)
        }
        .tint(AppTheme.gold)
    }
}
