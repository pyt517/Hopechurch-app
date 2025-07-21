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
            VStack(spacing: 0) {
                Color(red: 28/255, green: 62/255, blue: 51/255) // Dark Green Header
                    .frame(height: 150)
                Color(red: 242/255, green: 242/255, blue: 247/255) // Light Gray Body
            }
            .edgesIgnoringSafeArea(.all)

            // Content Layer
            VStack(alignment: .leading, spacing: 0) {
                customNavBar()

                ScrollView {
                    VStack(spacing: 20) {
                        filterView()
                        
                        if let stats = totalStatistics {
                            statisticsCardView(stats: stats)
                        }

                        if filteredSessions.isEmpty && (selectedYear != nil) {
                            Text("当前筛选条件下无记录")
                                .foregroundColor(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(12)
                        } else {
                            ForEach(sortedDays, id: \.self) { day in
                                dailySessionCard(day: day)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
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
    private func customNavBar() -> some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Text("历史记录")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // A placeholder to keep the title centered
            Image(systemName: "chevron.left").opacity(0)
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func filterView() -> some View {
        VStack(alignment: .leading) {
            Text("筛选记录")
                .font(.title3).bold()
                .padding([.horizontal, .top])

            HStack {
                yearPicker()
                monthPicker()
            }
            .padding([.horizontal, .bottom])
        }
        .background(Color.white)
        .cornerRadius(20)
    }

    @ViewBuilder
    private func yearPicker() -> some View {
        Menu {
            Button("所有年份") {
                selectedYear = nil
                selectedMonth = nil
            }
            ForEach(availableYears, id: \.self) { year in
                Button("\(String(year))年") {
                    if selectedYear != year {
                        selectedYear = year
                        selectedMonth = nil
                    }
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("年份").font(.caption).foregroundStyle(.secondary)
                    Text(selectedYear == nil ? "所有" : "\(String(selectedYear!))").font(.headline)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    @ViewBuilder
    private func monthPicker() -> some View {
        Menu {
            Button("所有月份") { selectedMonth = nil }
            ForEach(availableMonths, id: \.self) { month in
                Button(monthName(from: month)) { selectedMonth = month }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("月份").font(.caption).foregroundStyle(.secondary)
                    Text(selectedMonth == nil ? "所有" : monthName(from: selectedMonth!)).font(.headline)
                }
                Spacer()
                Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .disabled(selectedYear == nil)
        .opacity(selectedYear == nil ? 0.6 : 1)
    }

    @ViewBuilder
    private func statisticsCardView(stats: (label: String, duration: String, cost: String)) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("\(stats.label)统计")
                .font(.title2)
                .fontWeight(.bold)

            if selectedMonth != nil && selectedYear != nil && !filteredSessions.isEmpty {
                Button(action: exportToImage) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("导出为图片")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.8))
            }
            
            HStack {
                Image(systemName: "hourglass")
                Text("总用时")
                Spacer()
                Text(stats.duration)
            }
            
            Divider().background(.white.opacity(0.5))

            HStack {
                Image(systemName: "dollarsign.circle")
                Text("总花费")
                Spacer()
                Text(stats.cost)
                    .fontWeight(.bold)
            }
        }
        .foregroundColor(.white)
        .padding()
        .background(Color(red: 91/255, green: 157/255, blue: 50/255))
        .cornerRadius(20)
    }

    @ViewBuilder
    private func dailySessionCard(day: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day, style: .date)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color(red: 28/255, green: 62/255, blue: 51/255))
            
            Divider()
            
            ForEach(sessionsGroupedByDay[day]!) { session in
                sessionRowView(for: session)
                    .onLongPressGesture {
                        sessionToDelete = session
                        showingDeleteAlert = true
                    }
                if session.id != sessionsGroupedByDay[day]!.last?.id {
                    Divider()
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