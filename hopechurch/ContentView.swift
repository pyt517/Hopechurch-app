import SwiftUI

struct ContentView: View {
    @State private var sessions: [UsageSession] = []
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingManualEntry = false
    @State private var refreshTrigger = false // 用于触发重新计算
    
    // Add state for notice content and editor presentation
    @State private var noticeContent: String = ""
    @State private var showingNoticeEditor = false
    private let noticeKey = "userNoticeContent"
    
    /// The user can "Enter" if there is no currently active session (no session with a nil `leave_at`).
    private var canEnter: Bool {
        !sessions.contains { $0.leave_at == nil }
    }
    
    // MARK: - Financial Calculations
    
    /// 账户总计：所有缴纳的费用 - 额外花销的费用
    private var accountTotal: Double {
        // 使用refreshTrigger来触发重新计算
        _ = refreshTrigger
        
        // 从UserDefaults读取缴费记录
        var totalPayments: Double = 0.0
        if let data = UserDefaults.standard.data(forKey: "PaymentRecords"),
           let paymentRecords = try? JSONDecoder().decode([PaymentRecord].self, from: data) {
            totalPayments = paymentRecords.reduce(0) { $0 + $1.amount }
        }
        
        // 从UserDefaults读取支出记录
        var totalExpenses: Double = 0.0
        if let data = UserDefaults.standard.data(forKey: "ExpenseRecords"),
           let expenseRecords = try? JSONDecoder().decode([ExpenseRecord].self, from: data) {
            totalExpenses = expenseRecords.reduce(0) { $0 + $1.amount }
        }
        
        return totalPayments - totalExpenses
    }
    
    /// 当月应付：月度使用统计算出的总费用
    private var currentMonthPayable: Double {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        let monthSessions = sessions.filter { session in
            let sessionMonth = Calendar.current.component(.month, from: session.arrive_at)
            let sessionYear = Calendar.current.component(.year, from: session.arrive_at)
            return sessionMonth == currentMonth && sessionYear == currentYear
        }
        
        let totalDurationSeconds = monthSessions.reduce(0) { $0 + ($1.duration ?? 0) }
        let totalMinutes = totalDurationSeconds / 60
        let fullHours = floor(totalMinutes / 60)
        let remainingMinutes = totalMinutes.truncatingRemainder(dividingBy: 60)
        
        var roundedRemainderMinutes: Double = 0
        if remainingMinutes > 0 {
            if remainingMinutes <= 15 {
                roundedRemainderMinutes = 15
            } else if remainingMinutes <= 30 {
                roundedRemainderMinutes = 30
            } else if remainingMinutes <= 45 {
                roundedRemainderMinutes = 45
            } else {
                roundedRemainderMinutes = 60
            }
        }
        
        let billableMinutes = (fullHours * 60) + roundedRemainderMinutes
        let billableHours = billableMinutes / 60
        return billableHours * 10.0 // 假设每小时10加元
    }
    
    /// 当月余额：账户总计 - 当月应付
    private var currentMonthBalance: Double {
        return accountTotal - currentMonthPayable
    }

    // Add a new computed property for current month's usage count
    private var currentMonthUsageCount: Int {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return sessions.filter { session in
            let sessionMonth = Calendar.current.component(.month, from: session.arrive_at)
            let sessionYear = Calendar.current.component(.year, from: session.arrive_at)
            return sessionMonth == currentMonth && sessionYear == currentYear
        }.count
    }

    private var currentMonthDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Layer
                Color(red: 229/255, green: 243/255, blue: 247/255) // Light Gray Background
                    .ignoresSafeArea()
                
                // Content Layer
                VStack(spacing: 0) {
                    // Top Header
                    HStack {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(red: 0/255, green: 150/255, blue: 136/255))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                )
                            Text("教堂乒乓球")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            NavigationLink(destination: MemberManagementView()) {
                                HStack(spacing: 4) {
                                    Text("会员管理")
                                        .font(.system(size: 20,weight: .semibold))
                                        .foregroundColor(.black)
                                    Image(systemName: "person.circle")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)

                    // Central Action Card
                    VStack(spacing: 20) {
                        // Main icon
                        Circle()
                            .fill(Color(red: 0/255, green: 150/255, blue: 136/255))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                            )
                        
                        // Title and subtitle
                        VStack(spacing: 8) {
                            Text("准备开始对打")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                            
                            Text("选择进入或离开球台")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        
                        // Action buttons
                        VStack(spacing: 12) {
                            Button(action: handleEnter) {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("进入球台")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!canEnter)
                            .opacity(canEnter ? 1 : 0.5)
                            
                            Button(action: handleLeave) {
                                HStack {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("离开球台")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .foregroundColor(.red)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                            }
                            .disabled(canEnter)
                            .opacity(canEnter ? 0.5 : 1)
                        }
                    }
                    .padding(40)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    Spacer()
                    
                    // Financial Summary Section
                    VStack(spacing: 16) {
                        // Section Header: "My Information"
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "person") // Changed icon
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue) // Changed color to blue to match "Notice"
                                Text("我的信息") // Changed title
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            NavigationLink(destination: PaymentDetailsView()) {
                                Text("缴费详情 →")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // Temporary Notice Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                Text("临时通知")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            Text(noticeContent)
                                .font(.system(size: 15))
                                .lineLimit(2)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(12)
                        .onTapGesture {
                            withAnimation(.easeInOut) {
                                showingNoticeEditor.toggle()
                            }
                        }

                        // Inline Notice Editor
                        if showingNoticeEditor {
                            NoticeEditorView(
                                initialContent: noticeContent,
                                onSave: { newContent in
                                    saveNotice(content: newContent)
                                    withAnimation(.easeInOut) {
                                        showingNoticeEditor = false
                                    }
                                },
                                onCancel: {
                                    withAnimation(.easeInOut) {
                                        showingNoticeEditor = false
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9, anchor: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.9, anchor: .top).combined(with: .opacity)
                            ))
                        }

                        // Monthly Payable Card (existing orange card)
                        VStack(spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                    Text(currentMonthDateString)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black.opacity(0.8))
                                }
                                Spacer()
                                Text("\(currentMonthUsageCount) 次使用")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            VStack(spacing: 4) {
                                Text("¥\(currentMonthPayable, specifier: "%.0f")")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("当月应付费用")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .padding()
                        .background(Color.orange.opacity(0.08)) // Set the fill color
                        .cornerRadius(20) // Round the corners of the view and its background
                        .overlay(
                            // Add the border on top
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
                        )

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
                    .padding(.horizontal, 20)
                    
                    // Overlay for the Notice Editor
                    // The `if showingNoticeEditor { ... }` overlay logic that was here is removed.
                    
                    Spacer()

                    // Bottom Navigation
                    HStack {
                         NavigationLink(destination: ManualEntryView(onSave: {
                            loadInitialData()
                         })) {
                            VStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 20))
                                Text("手动补录")
                                    .font(.system(size: 12))
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        NavigationLink(destination: HistoryView(sessions: $sessions)) {
                            VStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 20))
                                Text("使用历史记录")
                                    .font(.system(size: 12))
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("好的")))
            }
            .onAppear(perform: loadInitialData)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // 当应用回到前台时，触发重新计算
                refreshTrigger.toggle()
            }
        }
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
        loadNotice() // Make sure to load the notice on app start
    }
    
    private func loadNotice() {
        noticeContent = UserDefaults.standard.string(forKey: noticeKey) ?? "本周六下午2点有乒乓球比赛，欢迎大家报名参加！"
    }

    private func saveNotice(content: String) {
        UserDefaults.standard.set(content, forKey: noticeKey)
        self.noticeContent = content
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
    
    @State private var showingArriveDatePicker = false
    @State private var showingArriveTimePicker = false
    @State private var showingLeaveDatePicker = false
    @State private var showingLeaveTimePicker = false
    
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
            // Background
            Color(red: 240/255, green: 249/255, blue: 255/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                        Text("手动补录使用时间")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)

                ScrollView {
                    VStack(spacing: 20) {
                        // Enter Table Time Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("进入时间")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                // Date and Time Columns
                                HStack(spacing: 12) {
                                    // Date Column
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("日期")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.black)
                                        
                                        Button(action: {
                                            showingArriveDatePicker = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                                                Text(dateFormatter.string(from: arriveDateComponent))
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(width: 130)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            )
                                        }
                                        .sheet(isPresented: $showingArriveDatePicker) {
                                            DatePicker("选择日期", selection: $arriveDateComponent, displayedComponents: .date)
                                                .datePickerStyle(.wheel)
                                                .presentationDetents([.height(300)])
                                        }
                                    }
                                    
                                    // Time Column
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("时间")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.black)
                                        
                                        Button(action: {
                                            showingArriveTimePicker = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                                                Text(timeFormatter.string(from: arriveTimeComponent))
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(width: 130)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            )
                                        }
                                        .sheet(isPresented: $showingArriveTimePicker) {
                                            DatePicker("选择时间", selection: $arriveTimeComponent, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.wheel)
                                                .presentationDetents([.height(300)])
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 4)
                                .cornerRadius(2),
                            alignment: .leading
                        )

                        // Leave Table Time Card
                        VStack(alignment: .leading, spacing: 16) {
                            Text("离开时间")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                // Date and Time Columns
                                HStack(spacing: 12) {
                                    // Date Column
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("日期")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.black)
                                        
                                        Button(action: {
                                            showingLeaveDatePicker = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.red)
                                                Text(dateFormatter.string(from: leaveDateComponent))
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(width: 130)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            )
                                        }
                                        .sheet(isPresented: $showingLeaveDatePicker) {
                                            DatePicker("选择日期", selection: $leaveDateComponent, displayedComponents: .date)
                                                .datePickerStyle(.wheel)
                                                .presentationDetents([.height(300)])
                                        }
                                    }
                                    
                                    // Time Column
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            Text("时间")
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.black)
                                            
                                            Spacer()
                                            
                                            Text("Preview")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                        
                                        Button(action: {
                                            showingLeaveTimePicker = true
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.red)
                                                Text(timeFormatter.string(from: leaveTimeComponent))
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(width: 130)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white)
                                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                                            )
                                        }
                                        .sheet(isPresented: $showingLeaveTimePicker) {
                                            DatePicker("选择时间", selection: $leaveTimeComponent, displayedComponents: .hourAndMinute)
                                                .datePickerStyle(.wheel)
                                                .presentationDetents([.height(300)])
                                        }
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 4)
                                .cornerRadius(2),
                            alignment: .leading
                        )
                        
                        // Save Button
                        Button(action: saveSession) {
                            Text("保存记录")
                                .font(.system(size: 18, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(isSaveDisabled)
                        .opacity(isSaveDisabled ? 0.5 : 1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }
} 

// Add the new NoticeEditorView struct
struct NoticeEditorView: View {
    @State private var content: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    let maxChars = 200

    init(initialContent: String, onSave: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        // If the initial content is the default placeholder, start with an empty editor.
        if initialContent == "本周六下午2点有乒乓球比赛，欢迎大家报名参加！" {
            _content = State(initialValue: "")
        } else {
            _content = State(initialValue: initialContent)
        }
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        // The ZStack wrapper and background dimming are removed.
        // The root is now the VStack.
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                Text("编辑临时通知")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding()

            // Content Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("通知内容")
                    .font(.system(size: 16, weight: .semibold))
                
                ZStack(alignment: .bottomTrailing) {
                    TextEditor(text: $content)
                        .font(.system(size: 16))
                        .frame(height: 150)
                        .onChange(of: content) { _, newValue in
                            if newValue.count > maxChars {
                                content = String(newValue.prefix(maxChars))
                            }
                        }
                    
                    // Placeholder
                    if content.isEmpty {
                        Text("输入临时通知内容...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .allowsHitTesting(false)
                    }

                    // Character count
                    Text("\(content.count)/\(maxChars)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(8)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0/255, green: 150/255, blue: 136/255).opacity(0.5), lineWidth: 2)
                )
            }
            .padding(.horizontal)

            // Info Box
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.blue)
                Text("通知将显示在首页信息模块中")
                    .font(.system(size: 14))
                    .foregroundColor(.blue.opacity(0.8))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .padding()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    HStack {
                        Image(systemName: "xmark")
                        Text("取消")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundColor(.gray)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                
                Button(action: { onSave(content) }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("保存")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(red: 245/255, green: 249/255, blue: 252/255))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 4)
    }
} 