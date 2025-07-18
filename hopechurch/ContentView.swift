import SwiftUI

struct ContentView: View {
    @State private var events: [CheckInEvent] = CheckInEventStorage.load()
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingManualEntry = false
    
    private var canEnter: Bool {
        if let lastEvent = events.first {
            return lastEvent.type == .leave
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background Layer
                VStack(spacing: 0) {
                    Color(red: 28/255, green: 62/255, blue: 51/255) // Dark Green Header
                        .frame(height: UIScreen.main.bounds.height * 0.35)
                    Color(red: 242/255, green: 242/255, blue: 247/255) // Light Gray Body
                }
                .edgesIgnoringSafeArea(.all)
                
                // Content Layer
                VStack(spacing: 0) {
                    // Title
                    Text("HopeChurch Record")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
                    
                    // Header
                    VStack(alignment: .leading) {
                        Text("随时记录您的到来")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)

                    Spacer()

                    // Floating Card
                    VStack(spacing: 20) {
                        actionButton(
                            title: "进入",
                            icon: "arrow.right.to.line",
                            backgroundColor: Color(red: 252/255, green: 122/255, blue: 87/255),
                            action: { addEvent(type: .enter) },
                            disabled: !canEnter
                        )
                        
                        actionButton(
                            title: "离开",
                            icon: "arrow.left.to.line",
                            backgroundColor: Color(red: 88/255, green: 86/255, blue: 214/255),
                            action: { addEvent(type: .leave) },
                            disabled: canEnter
                        )
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 5)
                    )
                    .padding(.horizontal, 20)
                    .offset(y: -UIScreen.main.bounds.height * 0.05)

                    // Spacer to push bottom navigation down
                    Spacer()
                    Spacer()

                    // Bottom Navigation
                    HStack(spacing: 70) {
                         Button(action: { showingManualEntry = true }) {
                            VStack(spacing: 5) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 22))
                                Text("手动补卡")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        NavigationLink(destination: HistoryView(events: $events)) {
                           VStack(spacing: 5) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 22))
                                Text("查看历史")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                    .foregroundColor(Color(red: 28/255, green: 62/255, blue: 51/255))
                    .padding(.bottom, 20)
                }
                .padding(.top, 40)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(events: $events)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好的")))
            }
        }
        .navigationViewStyle(.stack)
    }
    
    // Custom Action Button
    @ViewBuilder
    private func actionButton(title: String, icon: String, backgroundColor: Color, action: @escaping () -> Void, disabled: Bool) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(20)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .animation(.easeInOut, value: disabled)
    }
    
    func addEvent(type: CheckInType) {
        let event = CheckInEvent(type: type)
        events.insert(event, at: 0)
        CheckInEventStorage.save(events)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dateString = formatter.string(from: event.date)
        
        if type == .enter {
            alertTitle = "记录成功"
            alertMessage = "时间: \(dateString)"
        } else {
            alertTitle = "再见！"
            alertMessage = "时间: \(dateString)"
        }
        showAlert = true
    }
}

struct CheckInEventStorage {
    static let key = "CheckInEvents"
    static func load() -> [CheckInEvent] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CheckInEvent].self, from: data)) ?? []
    }
    static func save(_ events: [CheckInEvent]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct ManualEntryView: View {
    @Binding var events: [CheckInEvent]
    @Environment(\.presentationMode) var presentationMode
    
    @State private var enterDate = Date()
    @State private var leaveDate = Date()
    @State private var showingAlert = false
    
    private var isSaveDisabled: Bool {
        leaveDate <= enterDate
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("输入时间")) {
                    DatePicker("进入时间", selection: $enterDate)
                    DatePicker("离开时间", selection: $leaveDate)
                }
                
                Section {
                    Button("保存") {
                        saveEvents()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .navigationBarTitle("手动补卡", displayMode: .inline)
            .navigationBarItems(leading: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("时间错误"),
                    message: Text("离开时间必须晚于进入时间。"),
                    dismissButton: .default(Text("好的"))
                )
            }
            .onAppear {
                // Set a sensible default for leave date
                leaveDate = Calendar.current.date(byAdding: .hour, value: 1, to: enterDate) ?? Date()
            }
        }
    }
    
    private func saveEvents() {
        guard !isSaveDisabled else {
            showingAlert = true
            return
        }
        
        let enterEvent = CheckInEvent(type: .enter, date: enterDate)
        let leaveEvent = CheckInEvent(type: .leave, date: leaveDate)
        
        // Add new events and sort the entire list to maintain chronological order
        events.append(enterEvent)
        events.append(leaveEvent)
        events.sort { $0.date > $1.date }
        
        CheckInEventStorage.save(events)
        presentationMode.wrappedValue.dismiss()
    }
} 