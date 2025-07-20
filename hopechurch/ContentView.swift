import SwiftUI

struct ContentView: View {
    @State private var sessions: [UsageSession] = []
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingManualEntry = false
    
    /// The user can "Enter" if there is no currently active session (no session with a nil `leave_at`).
    private var canEnter: Bool {
        !sessions.contains { $0.leave_at == nil }
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
                    // Header
                    VStack(alignment: .leading) {
                        Text("HopeChurch")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        
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
                            action: handleEnter,
                            disabled: !canEnter
                        )
                        
                        actionButton(
                            title: "离开",
                            icon: "arrow.left.to.line",
                            backgroundColor: Color(red: 88/255, green: 86/255, blue: 214/255),
                            action: handleLeave,
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
                         NavigationLink(destination: ManualEntryView(onSave: {
                            // Refresh data after manual entry
                            loadInitialData()
                         })) {
                            VStack(spacing: 5) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 22))
                                Text("手动补卡")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        NavigationLink(destination: HistoryView(sessions: $sessions)) {
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
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好的")))
            }
            .onAppear(perform: loadInitialData)
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
    
    // --- Data Handlers ---

    private func loadInitialData() {
        Task {
            do {
                sessions = try await SupabaseService.shared.fetchSessions()
            } catch {
                print("Error loading sessions: \(error)")
                // Handle error appropriately
            }
        }
    }
    
    private func handleEnter() {
        Task {
            do {
                let newSession = try await SupabaseService.shared.startNewSession()
                sessions.insert(newSession, at: 0)
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                alertTitle = "记录成功"
                alertMessage = "时间: \(formatter.string(from: newSession.arrive_at))"
                showAlert = true
                
            } catch {
                print("Error starting session: \(error)")
                // Handle error
            }
        }
    }
    
    private func handleLeave() {
        Task {
            do {
                if let updatedSession = try await SupabaseService.shared.endCurrentSession() {
                    // Find and update the session in the local array
                    if let index = sessions.firstIndex(where: { $0.id == updatedSession.id }) {
                        sessions[index] = updatedSession
                    }
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    alertTitle = "再见！"
                    alertMessage = "时间: \(formatter.string(from: updatedSession.leave_at ?? Date()))"
                    showAlert = true
                }
            } catch {
                print("Error ending session: \(error)")
                // Handle error
            }
        }
    }
}

struct ManualEntryView: View {
    var onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var arriveDateComponent = Date()
    @State private var arriveTimeComponent = Date()
    @State private var leaveDateComponent = Date()
    @State private var leaveTimeComponent = Date()
    
    @State private var isAlertPresented = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var alertDismissAction: (() -> Void)? = nil
    
    private var arriveDate: Date {
        combine(date: arriveDateComponent, time: arriveTimeComponent)
    }
    
    private var leaveDate: Date {
        combine(date: leaveDateComponent, time: leaveTimeComponent)
    }
    
    private var isSaveDisabled: Bool {
        leaveDate <= arriveDate
    }

    var body: some View {
        ZStack {
            // Background Layer
            VStack(spacing: 0) {
                Color(red: 28/255, green: 62/255, blue: 51/255)
                    .frame(height: 150)
                Color(red: 242/255, green: 242/255, blue: 247/255)
            }
            .edgesIgnoringSafeArea(.all)
            
            // Content Layer
            VStack(alignment: .leading, spacing: 0) {
                customNavBar()

                ScrollView {
                    VStack(spacing: 20) {
                        // Entry Time Card
                        VStack(alignment: .leading) {
                            Text("进入时间")
                                .font(.headline)
                                .padding([.top, .horizontal])
                            Divider().padding(.horizontal)
                            DatePicker("日期", selection: $arriveDateComponent, displayedComponents: .date)
                                .padding([.horizontal])
                            DatePicker("时间", selection: $arriveTimeComponent, displayedComponents: .hourAndMinute)
                                .padding([.horizontal, .bottom])
                        }
                        .background(Color.white)
                        .cornerRadius(20)

                        // Exit Time Card
                        VStack(alignment: .leading) {
                            Text("离开时间")
                                .font(.headline)
                                .padding([.top, .horizontal])
                            Divider().padding(.horizontal)
                            DatePicker("日期", selection: $leaveDateComponent, displayedComponents: .date)
                                .padding([.horizontal])
                            DatePicker("时间", selection: $leaveTimeComponent, displayedComponents: .hourAndMinute)
                                .padding([.horizontal, .bottom])
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        
                        // Save Button
                        Button(action: saveSession) {
                            Text("保存记录")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Color(red: 28/255, green: 62/255, blue: 51/255))
                        .disabled(isSaveDisabled)
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $isAlertPresented) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("好的"), action: {
                    alertDismissAction?()
                })
            )
        }
        .onAppear(perform: setupDefaultDates)
    }
    
    @ViewBuilder
    private func customNavBar() -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            Spacer()
            Text("手动补卡")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "chevron.left").opacity(0)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    private func setupDefaultDates() {
        let now = Date()
        arriveDateComponent = now
        arriveTimeComponent = now
        leaveDateComponent = now
        leaveTimeComponent = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now
    }
    
    private func combine(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second
        
        return calendar.date(from: combinedComponents) ?? Date()
    }

    private func saveSession() {
        guard !isSaveDisabled else {
            self.alertTitle = "时间错误"
            self.alertMessage = "离开时间必须晚于进入时间。"
            self.alertDismissAction = nil
            self.isAlertPresented = true
            return
        }
        
        Task {
            do {
                try await SupabaseService.shared.addManualSession(arriveAt: arriveDate, leaveAt: leaveDate)
                await MainActor.run {
                    onSave()
                    self.alertTitle = "保存成功"
                    self.alertMessage = "您的补卡记录已成功添加。"
                    self.alertDismissAction = {
                        dismiss()
                    }
                    self.isAlertPresented = true
                }
            } catch {
                await MainActor.run {
                    self.alertTitle = "保存失败"
                    self.alertMessage = "网络请求失败，请稍后重试。"
                    self.alertDismissAction = nil
                    self.isAlertPresented = true
                }
                print("Error saving manual session: \(error)")
            }
        }
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }
} 