import SwiftUI

struct HistoryView: View {
    @Binding var sessions: [UsageSession]
    
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedYear: Int? = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int? = Calendar.current.component(.month, from: Date())
    @State private var sessionToDelete: UsageSession?
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var reportImage: UIImage?
    @State private var longPressedSessionId: Int? = nil
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false


    // --- COMPUTED PROPERTIES: DATA ---

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 4)...currentYear).sorted(by: >)
    }

    private var availableMonths: [Int] {
        return Array(1...12)
    }

    private var filteredSessions: [UsageSession] {
        guard let year = selectedYear else { return sessions }
        let calendar = Calendar.current
        
        let yearFiltered = sessions.filter {
            calendar.component(.year, from: $0.arrive_at) == year
        }
        
        guard let month = selectedMonth else { return yearFiltered }
        
        return yearFiltered.filter {
            calendar.component(.month, from: $0.arrive_at) == month
        }
    }
    
    private var sessionsGroupedByDay: [Date: [UsageSession]] {
        Dictionary(grouping: filteredSessions) {
            Calendar.current.startOfDay(for: $0.arrive_at)
        }
    }
    
    private var sortedDays: [Date] {
        sessionsGroupedByDay.keys.sorted(by: >)
    }

    private var totalStatistics: (label: String, duration: String, cost: String)? {
        let totalDurationSeconds = filteredSessions.reduce(0) { $0 + ($1.duration ?? 0) }
        guard totalDurationSeconds > 0 else { return nil }
        
        // --- Corrected Billing Logic ---
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
            } else { // remainingMinutes is > 45 and < 60
                roundedRemainderMinutes = 60
            }
        }
        
        let billableMinutes = (fullHours * 60) + roundedRemainderMinutes
        let billableDurationSeconds = billableMinutes * 60
        let billableHours = billableMinutes / 60
        let totalCost = billableHours * 10.0 // Assuming rate is $10/hr
        // --- End of Corrected Logic ---
        
        let formattedDuration = formatDuration(billableDurationSeconds)
        let formattedCost = formatCurrency(totalCost)
        
        let label: String
        if selectedMonth != nil {
            label = "月度"
        } else if selectedYear != nil {
            label = "本年"
        } else {
            label = "全部"
        }
        
        return (label: label, duration: formattedDuration, cost: formattedCost)
    }

    private var totalDurationInSeconds: TimeInterval {
        let totalDurationSeconds = filteredSessions.reduce(0) { $0 + ($1.duration ?? 0) }
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
        return billableMinutes * 60
    }
    
    // --- BODY ---
    
    var body: some View {
        ZStack {
            // Background Layer
            Color(red: 229/255, green: 243/255, blue: 247/255) // Light Gray Background
                .ignoresSafeArea()

            // Content Layer
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    // Title on the left
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                        Text("历史记录")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                    }
                    
                    Spacer()
                    
                    // Close button on the right
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 20) {
                        filterView()
                        
                        if let stats = totalStatistics {
                            statisticsCardView(stats: stats)
                        }
                        
                        // Tip Card
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundColor(Color.blue.opacity(0.7))
                            
                            Text("长按日期即可删除记录")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)

                        if filteredSessions.isEmpty && (selectedYear != nil) {
                            VStack(spacing: 16) {
                                Image(systemName: "target")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                
                                Text("该月份暂无对打记录")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        } else {
                            allSessionsCard()
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("确认删除", isPresented: $showingDeleteAlert, presenting: sessionToDelete) { session in
            Button("删除", role: .destructive) {
                delete(session: session)
            }
            Button("取消", role: .cancel) { }
        } message: { _ in
            Text("您确定要删除这条使用记录吗？")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let image = reportImage {
                ShareSheet(activityItems: [image])
            }
        }
        .onChange(of: reportImage) { newImage in
             if newImage != nil {
                 showingShareSheet = true
             }
         }
    }

    // --- VIEW BUILDERS ---

    @ViewBuilder
    private func filterView() -> some View {
        VStack(alignment: .leading) {
            Text("筛选记录")
                .font(.headline).bold()
                .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255).opacity(1))
                .padding([.horizontal, .top])

            HStack {
                yearPicker()
                monthPicker()
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color.white)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func yearPicker() -> some View {
        Button(action: {
            showingYearPicker = true
        }) {
            HStack {
                Text(selectedYear == nil ? "所有年份" : "\(String(selectedYear!))年")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 240/255, green: 249/255, blue: 255/255).opacity(1), lineWidth: 3)
            )
        }
        .sheet(isPresented: $showingYearPicker) {
            VStack {
                HStack {
                    Text("选择年份")
                        .font(.headline)
                        .padding()
                    Spacer()
                    Button("完成") {
                        showingYearPicker = false
                    }
                    .padding()
                }
                
                Picker("年份", selection: $selectedYear) {
                    Text("所有年份").tag(nil as Int?)
                    ForEach(availableYears, id: \.self) { year in
                        Text("\(String(year))年").tag(year as Int?)
                    }
                }
                .pickerStyle(.wheel)
                .presentationDetents([.height(300)])
            }
        }
    }
    
    @ViewBuilder
    private func monthPicker() -> some View {
        Button(action: {
            showingMonthPicker = true
        }) {
            HStack {
                Text(selectedMonth == nil ? "所有月份" : monthName(from: selectedMonth!))
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(red: 240/255, green: 249/255, blue: 255/255).opacity(1), lineWidth: 3)
            )
        }
        .disabled(selectedYear == nil)
        .opacity(selectedYear == nil ? 0.6 : 1)
        .sheet(isPresented: $showingMonthPicker) {
            VStack {
                HStack {
                    Text("选择月份")
                        .font(.headline)
                        .padding()
                    Spacer()
                    Button("完成") {
                        showingMonthPicker = false
                    }
                    .padding()
                }
                
                Picker("月份", selection: $selectedMonth) {
                    Text("所有月份").tag(nil as Int?)
                    ForEach(availableMonths, id: \.self) { month in
                        Text(monthName(from: month)).tag(month as Int?)
                    }
                }
                .pickerStyle(.wheel)
                .presentationDetents([.height(300)])
            }
        }
    }

    @ViewBuilder
    private func statisticsCardView(stats: (label: String, duration: String, cost: String)) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: "bolt")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                Text("月度使用统计")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stats.duration)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("使用时长")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(stats.cost)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    Text("总费用")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Export Button
            if selectedMonth != nil && selectedYear != nil && !filteredSessions.isEmpty {
                Button(action: exportToImage) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出为图片")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                }
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(Color(red: 0/255, green: 150/255, blue: 136/255))
        .cornerRadius(20)
    }

    @ViewBuilder
    private func allSessionsCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(sortedDays, id: \.self) { day in
                VStack(alignment: .leading, spacing: 10) {
                    Text(day, style: .date)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(longPressedSessionId == sessionsGroupedByDay[day]!.first?.id ? Color(red: 173/255, green: 216/255, blue: 230/255) : Color(red: 28/255, green: 62/255, blue: 51/255))
                        .onLongPressGesture(minimumDuration: 1.0, pressing: { isPressing in
                            if isPressing {
                                longPressedSessionId = sessionsGroupedByDay[day]!.first?.id
                            } else {
                                longPressedSessionId = nil
                            }
                        }) {
                            sessionToDelete = sessionsGroupedByDay[day]!.first
                            showingDeleteAlert = true
                        }
                    
                    ForEach(sessionsGroupedByDay[day]!) { session in
                        sessionRowView(for: session)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                }
                
                if day != sortedDays.last {
                    Divider()
                        .padding(.vertical, 10)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
    }

    @ViewBuilder
    private func sessionRowView(for session: UsageSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("进入: \(timeString(from: session.arrive_at))")
                if let leaveDate = session.leave_at {
                    Text("离开: \(timeString(from: leaveDate))")
                } else {
                    Text("离开: 进行中...")
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if let duration = session.duration {
                    Text(formatDuration(duration))
                        .fontWeight(.bold)
                }
                if let cost = session.cost {
                    Text(formatCurrency(cost))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // --- HELPERS ---
    
    @MainActor
    private func exportToImage() {
        guard let year = selectedYear, let month = selectedMonth, let stats = totalStatistics else { return }
        
        let reportView = ReportView(
            month: month,
            year: year,
            sessions: filteredSessions,
            totalDuration: totalDurationInSeconds,
            totalCost: stats.cost
        )
        
        let renderer = ImageRenderer(content: reportView)
        renderer.scale = 2.0
        
        // Asynchronous rendering
        Task {
            if let image = await renderer.uiImage {
                self.reportImage = image
            }
        }
    }
    
    private func delete(session: UsageSession) {
        // Optimistically remove from local state
        sessions.removeAll { $0.id == session.id }
        
        // Call Supabase to delete from the backend
        Task {
            do {
                try await SupabaseService.shared.deleteSession(id: session.id)
            } catch {
                print("Error deleting session: \(error)")
                // Handle error (e.g., re-fetch data or show an alert)
            }
        }
    }
    
    private func monthName(from month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.monthSymbols[month - 1]
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration >= 60 else { return "少于一分钟" }
        
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if hours > 0 {
            return "\(hours)小时"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_CA")
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {}
} 