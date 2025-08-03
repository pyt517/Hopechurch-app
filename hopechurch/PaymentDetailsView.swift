import SwiftUI

struct PaymentDetailsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var paymentRecords: [PaymentRecord] = []
    @State private var expenseRecords: [ExpenseRecord] = []
    @State private var showingAddPaymentForm = false
    @State private var showingAddExpenseForm = false
    
    // Filter States
    @State private var selectedYear: Int? = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int? = Calendar.current.component(.month, from: Date())
    @State private var showingYearPicker = false
    @State private var showingMonthPicker = false
    
    // 1. Add new state for the filter toggle
    @State private var showOnlyNonMemberPayments = false
    
    // MARK: - Computed Properties
    
    // Use a consistent, local calendar for all date operations.
    private var calendar: Calendar {
        Calendar.current
    }
    
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    private var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    // Use a UTC calendar for filtering to match how Supabase stores and returns dates.
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let utcTimeZone = TimeZone(identifier: "UTC") else {
            // This should never fail.
            fatalError("UTC time zone not available")
        }
        calendar.timeZone = utcTimeZone
        return calendar
    }
    
    // Corrected currentMonthIncome to use a mix of local and UTC calendars
    private var currentMonthIncome: Double {
        let localCalendar = Calendar.current
        let currentYear = localCalendar.component(.year, from: Date())
        let currentMonth = localCalendar.component(.month, from: Date())
        
        let currentMonthRecords = paymentRecords.filter { record in
            let comps = utcCalendar.dateComponents([.year, .month], from: record.payment_date)
            return comps.year == currentYear && comps.month == currentMonth
        }
        return currentMonthRecords.reduce(0) { $0 + $1.amount }
    }
    
    private var currentMonthExpenses: Double {
        let currentMonthRecords = expenseRecords.filter { record in
            let recordMonth = Calendar.current.component(.month, from: record.expense_date) // Fix: use expense_date
            let recordYear = Calendar.current.component(.year, from: record.expense_date)   // Fix: use expense_date
            return recordMonth == currentMonth && recordYear == currentYear
        }
        return currentMonthRecords.reduce(0) { $0 + $1.amount }
    }
    
    private var currentMonthNet: Double {
        return currentMonthIncome - currentMonthExpenses
    }
    
    // MARK: - Filter Computed Properties
    
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 4)...currentYear).sorted(by: >)
    }

    private var availableMonths: [Int] {
        return Array(1...12)
    }
    
    // Fix date filtering logic to be timezone-agnostic
    private func isDateInFilter(_ date: Date) -> Bool {
        guard let year = selectedYear else { return true }
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC")!

        let dateComponents = utcCalendar.dateComponents([.year, .month], from: date)
        
        guard dateComponents.year == year else { return false }
        
        if let month = selectedMonth {
            return dateComponents.month == month
        }
        
        return true
    }

    // Corrected filteredPaymentRecords to be timezone-proof
    private var filteredPaymentRecords: [PaymentRecord] {
        if showOnlyNonMemberPayments {
            return []
        }
        guard let year = selectedYear else { return paymentRecords }

        return paymentRecords.filter { record in
            let dateComponents = utcCalendar.dateComponents([.year, .month], from: record.payment_date)
            
            let yearMatches = dateComponents.year == year
            
            if let month = selectedMonth {
                return yearMatches && dateComponents.month == month
            }
            
            return yearMatches
        }
    }
    
    // Fix: Use expense_date instead of date
    private var filteredExpenseRecords: [ExpenseRecord] {
        if showOnlyNonMemberPayments {
            return expenseRecords.filter { $0.type == .income }
        }
        guard let year = selectedYear, let month = selectedMonth else {
            return []
        }
        
        let utcCalendar = Calendar(identifier: .gregorian)
        
        // Using a for-loop to avoid any trailing closure ambiguity for the compiler.
        var filteredRecords: [ExpenseRecord] = []
        for record in expenseRecords {
            let recordYear = utcCalendar.component(.year, from: record.expense_date)
            let recordMonth = utcCalendar.component(.month, from: record.expense_date)
            
            if recordYear == year && recordMonth == month {
                filteredRecords.append(record)
            }
        }
        return filteredRecords
    }
    
    private var sortedExpenseRecords: [ExpenseRecord] {
        filteredExpenseRecords.sorted { $0.expense_date > $1.expense_date }
    }
    
    private var filteredMonthIncome: Double {
        return filteredPaymentRecords.reduce(0) { $0 + $1.amount }
    }
    
    // Update filteredMonthExpenses to handle new logic
    private var filteredMonthExpenses: Double {
        return filteredExpenseRecords.reduce(0) { $0 + $1.amount }
    }
    
    private var filteredMonthNet: Double {
        return filteredMonthIncome - filteredMonthExpenses
    }
    
    // Add Payment Form States
    @State private var selectedMember: Member?
    @State private var paymentAmount: Double = 0.0
    @State private var paymentDate = Date()
    @State private var paymentNotes = ""
    
    // Add Expense Form States
    @State private var expenseAmount: Double = 0.0
    @State private var expenseDate = Date()
    @State private var expenseNotes = "" // Added for remarks
    
    var activeMembers: [Member] {
        members.filter { $0.is_active }
    }
    
    // Supabase
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 240/255, green: 249/255, blue: 255/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        Text("缴费详情")
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
                        // Member Count Module
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                Text("活跃会员")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            Text("\(members.filter { $0.is_active }.count)人")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(red: 204/255, green: 227/255, blue: 234/255))
                        .cornerRadius(12)
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            // Add Payment Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingAddPaymentForm.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("会员缴费")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(showingAddPaymentForm)
                            .opacity(showingAddPaymentForm ? 0.5 : 1)
                            
                            // Additional Expense Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingAddExpenseForm.toggle()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("额外收支")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .foregroundColor(.orange)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange, lineWidth: 1)
                                )
                            }
                            .disabled(showingAddExpenseForm)
                            .opacity(showingAddExpenseForm ? 0.5 : 1)
                        }
                        
                        // Filter Module (moved below action buttons)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("筛选记录")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255).opacity(1))
                                .padding(.top, 6)
                                .padding(.horizontal, 16)
                                .lineLimit(1)

                            HStack(spacing: 12) {
                                yearPicker()
                                monthPicker()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                            .disabled(showOnlyNonMemberPayments) // Disable when toggle is on
                            .opacity(showOnlyNonMemberPayments ? 0.5 : 1)

                            Divider().padding(.horizontal)

                            Toggle(isOn: $showOnlyNonMemberPayments.animation()) {
                                Text("仅显示非会员缴费")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .tint(Color(red: 0/255, green: 150/255, blue: 136/255))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 6)
                        }
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        // Add Payment Form
                        if showingAddPaymentForm {
                            AddPaymentFormView(
                                members: activeMembers, // 只传递活跃会员
                                selectedMember: $selectedMember,
                                paymentAmount: $paymentAmount,
                                paymentDate: $paymentDate,
                                paymentNotes: $paymentNotes,
                                isVisible: $showingAddPaymentForm,
                                onSave: { memberId in
                                    // Adjust the date to noon in the current timezone before saving
                                    let localCalendar = Calendar.current
                                    var dateComponents = localCalendar.dateComponents([.year, .month, .day], from: paymentDate)
                                    dateComponents.hour = 12
                                    dateComponents.minute = 0
                                    dateComponents.second = 0
                                    let adjustedDate = localCalendar.date(from: dateComponents) ?? paymentDate

                                    if let memberId = memberId {
                                        await savePaymentRecord(memberId: memberId, date: adjustedDate, amount: paymentAmount, remarks: paymentNotes)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                        
                        // Add Expense Form
                        if showingAddExpenseForm {
                            AddExpenseFormView(
                                isPresented: $showingAddExpenseForm,
                                onSave: { type, amount, date, notes in
                                    Task {
                                        await saveExpenseRecord(type: type, amount: amount, date: date, notes: notes)
                                        
                                        await MainActor.run {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showingAddExpenseForm = false
                                            }
                                        }
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            ))
                        }
                        

                        
                        // Payment and Expense Records List
                        if !filteredPaymentRecords.isEmpty || !filteredExpenseRecords.isEmpty {
                            LazyVStack(spacing: 12) {
                                // Payment Records
                                ForEach(filteredPaymentRecords.sorted(by: { $0.payment_date > $1.payment_date })) { record in
                                    PaymentRecordCard(record: record, members: members, onDelete: {
                                        Task {
                                            await deletePaymentRecord(record)
                                        }
                                    })
                                }
                                
                                // Expense Records
                                ForEach(sortedExpenseRecords) { record in
                                    ExpenseRecordCard(record: record, onDelete: {
                                        Task {
                                            await deleteExpenseRecord(record)
                                        }
                                    })
                                }
                            }
                        } else if showOnlyNonMemberPayments {
                            VStack(spacing: 16) {
                                Image(systemName: "person.crop.circle.badge.questionmark")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text("没有找到非会员缴费记录")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        } else if !paymentRecords.isEmpty || !expenseRecords.isEmpty {
                            // Show empty state when filtered results are empty
                            VStack(spacing: 16) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                
                                Text("该月份暂无记录")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await loadData()
            }
        }
    }
    
    // MARK: - Filter View Builders
    
    @ViewBuilder
    private func yearPicker() -> some View {
        Button(action: {
            showingYearPicker = true
        }) {
            HStack {
                Text(selectedYear == nil ? "所有年份" : "\(String(selectedYear!))年")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 240/255, green: 249/255, blue: 255/255).opacity(1), lineWidth: 2)
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
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 240/255, green: 249/255, blue: 255/255).opacity(1), lineWidth: 2)
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
    
    private func monthName(from month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.monthSymbols[month - 1]
    }
    
    // Data Loading from Supabase
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let membersTask = SupabaseService.shared.fetchMembers()
            async let paymentsTask = SupabaseService.shared.fetchAllPaymentRecords()
            async let expensesTask = SupabaseService.shared.fetchAllExpenseRecords()
            
            self.members = try await membersTask
            self.paymentRecords = try await paymentsTask
            self.expenseRecords = try await expensesTask
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    // Fix savePaymentRecord to correctly update UI with member name
    private func savePaymentRecord(memberId: Int, date: Date, amount: Double, remarks: String?) async {
        do {
            // 1. Fetch the record and store it in a mutable variable.
            var recordToUpdate = try await SupabaseService.shared.addPaymentRecord(memberId: memberId, date: date, amount: amount, remarks: remarks)
            
            // 2. If it's a member, attach the member info.
            if memberId != -1, let selected = selectedMember {
                let memberInfo = Member(
                    member_id: selected.member_id, 
                    name: selected.name, 
                    remarks: selected.remarks, 
                    is_active: selected.is_active, 
                    created_at: selected.created_at, 
                    updated_at: selected.updated_at
                )
                recordToUpdate.members = memberInfo
            }

            // 3. Create a final, immutable constant to be captured by the closure.
            let finalRecord = recordToUpdate

            // 4. Pass the immutable constant to the main actor closure for UI updates.
            await MainActor.run {
                paymentRecords.insert(finalRecord, at: 0)
                
                // Reset form fields
            selectedMember = nil
            paymentAmount = 0.0
            paymentDate = Date()
            paymentNotes = ""
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save payment: \(error.localizedDescription)"
            }
        }
    }
    
    // Expense Operations
    private func saveExpenseRecord(type: ExpenseType, amount: Double, date: Date, notes: String?) async {
        let finalAmount = type == .income ? abs(amount) : -abs(amount)
        do {
            let newRecord = try await SupabaseService.shared.addExpenseRecord(type: type, amount: finalAmount, date: date, notes: notes)
            await MainActor.run {
                expenseRecords.insert(newRecord, at: 0)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save expense: \(error.localizedDescription)"
            }
        }
    }

    private func deleteExpenseRecord(_ record: ExpenseRecord) async {
        do {
            try await SupabaseService.shared.deleteExpenseRecord(expenseId: record.id)
            await MainActor.run {
                expenseRecords.removeAll { $0.id == record.id }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete expense: \(error.localizedDescription)"
            }
        }
    }

    private func deletePaymentRecord(_ record: PaymentRecord) async {
        do {
            try await SupabaseService.shared.deletePaymentRecord(paymentId: record.id)
            paymentRecords.removeAll { $0.id == record.id }
        } catch {
            errorMessage = "Failed to delete payment: \(error.localizedDescription)"
        }
    }
}

// MARK: - Add Payment Form View
struct AddPaymentFormView: View {
    let members: [Member]
    @Binding var selectedMember: Member?
    @Binding var paymentAmount: Double
    @Binding var paymentDate: Date
    @Binding var paymentNotes: String
    @Binding var isVisible: Bool
    let onSave: (_ memberId: Int?) async -> Void // Make onSave async
    
    @State private var showingMemberPicker = false
    @State private var showingDatePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                Text("添加缴费记录")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            VStack(spacing: 16) {
                // Member Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("会员选择")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    Button(action: {
                        showingMemberPicker = true
                    }) {
                        HStack {
                            Text(selectedMember?.name ?? "选择会员")
                                .foregroundColor(selectedMember == nil ? .gray : .black)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(selectedMember == nil ? Color.gray.opacity(0.1) : Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .sheet(isPresented: $showingMemberPicker) {
                        VStack {
                            HStack {
                                Text("选择会员")
                                    .font(.headline)
                                    .padding()
                                Spacer()
                                Button("完成") {
                                    showingMemberPicker = false
                                }
                                .padding()
                            }
                            
                            Picker("会员", selection: $selectedMember) {
                                Text("选择会员").tag(nil as Member?)
                                ForEach(members) { member in
                                    Text(member.name).tag(member as Member?)
                                }
                            }
                            .onChange(of: selectedMember) { oldValue, newValue in
                                if newValue != nil {
                                    // isNonMember = false // This line is removed
                                }
                            }
                            .pickerStyle(.wheel)
                            .presentationDetents([.height(300)])
                        }
                    }
                }
                
                // Date and Amount
                HStack(spacing: 12) {
                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("日期")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        
                        Button(action: {
                            showingDatePicker = true
                        }) {
                            HStack {
                                Text(dateFormatter.string(from: paymentDate))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .sheet(isPresented: $showingDatePicker) {
                            VStack {
                                HStack {
                                    Text("选择日期")
                                        .font(.headline)
                                        .padding()
                                    Spacer()
                                    Button("完成") {
                                        showingDatePicker = false
                                    }
                                    .padding()
                                }
                                
                                DatePicker("日期", selection: $paymentDate, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .presentationDetents([.height(300)])
                            }
                        }
                    }
                    
                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("金额")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        
                        TextField("输入金额", value: $paymentAmount, format: .currency(code: "CAD"))
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("备注")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    
                    TextField("输入备注信息", text: $paymentNotes)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        // Reset form
                        selectedMember = nil
                        paymentAmount = 0.0
                        paymentDate = Date()
                        paymentNotes = ""
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isVisible = false
                        }
                    }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {
                        Task {
                            await onSave(selectedMember?.id)
                            
                            // Close the form on the main thread
                            await MainActor.run {
                                isVisible = false
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                            Text("保存")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(paymentAmount <= 0)
                    .opacity(paymentAmount <= 0 ? 0.5 : 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }
}

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// MARK: - Add Expense Form View
struct AddExpenseFormView: View {
    @Binding var isPresented: Bool
    var onSave: (ExpenseType, Double, Date, String?) -> Void

    @State private var expenseType: ExpenseType = .income
    @State private var expenseAmount: Double = 0.0
    @State private var expenseDate: Date = Date()
    @State private var expenseNotes: String = ""
    @State private var showingDatePicker = false // Re-add the missing state variable
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Row 1: Header
            HStack(spacing: 8) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                Text("额外收支")
                    .font(.system(size: 18, weight: .bold))
            }
            
            // Row 2: "收支项目" Label
            Text("收支项目")
                .font(.system(size: 16, weight: .bold))
            
            // Row 3: Type Picker
            // Replace the Picker with a custom button group
            HStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { expenseType = .income }
                }) {
                    Text("非会员缴费")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(expenseType == .income ? .white : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(expenseType == .income ? Color.orange : Color.clear)
                }
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { expenseType = .expense }
                }) {
                    Text("额外开销")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(expenseType == .expense ? .white : .orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(expenseType == .expense ? Color.orange : Color.clear)
                }
            }
            .background(Color.orange.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange, lineWidth: 1)
            )
            
            
            
            // Row 5: Date Picker and Amount Field
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("日期")
                            .font(.system(size: 16, weight: .bold))
                        Button(action: {
                            showingDatePicker = true
                        }) {
                            HStack {
                                Text(dateFormatter.string(from: expenseDate))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    .frame(maxWidth: .infinity) // Make date picker take up available space
                        .sheet(isPresented: $showingDatePicker) {
                            VStack {
                                HStack {
                                    Text("选择日期")
                                        .font(.headline)
                                        .padding()
                                    Spacer()
                                    Button("完成") {
                                        showingDatePicker = false
                                    }
                                    .padding()
                                }
                                
                                DatePicker("日期", selection: $expenseDate, displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .presentationDetents([.height(300)])
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                    Text("金额")
                            .font(.system(size: 16, weight: .bold))
                    TextField("输入金额", value: $expenseAmount, format: .currency(code: "CAD"))
                        .keyboardType(.decimalPad)
                        .frame(maxWidth: .infinity) // Make amount field take up available space
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                }
                    }
                    
            // Row 6: "备注" Label
            Text("备注")
                            .font(.system(size: 16, weight: .bold))
                        
            // Row 7: Remarks TextField
            TextField("输入备注信息", text: $expenseNotes)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                
            // Row 8: Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        // Reset form
                        expenseAmount = 0.0
                        expenseDate = Date()
                    expenseNotes = "" // Reset remarks
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                        }
                    }) {
                        Text("取消")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .foregroundColor(.orange)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                    }
                    
                Button(action: {
                    onSave(expenseType, expenseAmount, expenseDate, expenseNotes.isEmpty ? nil : expenseNotes)
                    
                    // Close the form with animation
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                            Text("保存")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                .disabled(expenseAmount <= 0)
                .opacity(expenseAmount <= 0 ? 0.5 : 1)
                }
            }
        .padding(20)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 2)
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter
    }
}

// MARK: - Expense Record Card
struct ExpenseRecordCard: View {
    let record: ExpenseRecord
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
        HStack(spacing: 12) {
            // Avatar and Icon
            ZStack(alignment: .topTrailing) {
                // Avatar Circle
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    )
                
                // Small Icon
                Circle()
                    .fill(Color.orange)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "minus")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                    )
                    .offset(x: 2, y: -2)
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("额外支出")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                            .lineLimit(1)
                    Text("·")
                        .foregroundColor(.gray)
                    Text(record.type.rawValue) // Use type.rawValue instead of expenseItem
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                            .lineLimit(1)
                            .truncationMode(.tail)
                }
                
                HStack {
                    Text(record.expense_date, style: .date) // Fix: use expense_date
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                            .lineLimit(1)
                    Text("·")
                        .foregroundColor(.gray)
                    Text("支出记录")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                            .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Amount
            Text("\(record.amount > 0 ? "+" : "") $\(record.amount, specifier: "%.2f")")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(record.amount > 0 ? .green : .orange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Delete Button
            Button(action: {
                showingDeleteAlert = true
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .offset(x: -8, y: 8)
        }
        .alert("确定要删除支出记录？", isPresented: $showingDeleteAlert) {
            Button("确定", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) { }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
}

// MARK: - Payment Record Card
struct PaymentRecordCard: View {
    let record: PaymentRecord
    let members: [Member] // Add members array
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
            ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String((record.members?.name ?? "非").prefix(1)))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    )
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                    Text(record.members?.name ?? "非会员")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let remarks = record.remarks, !remarks.isEmpty {
                        Text(remarks)
                            .font(.system(size: 12))
                        .foregroundColor(.gray)
                            .lineLimit(2)
                            .truncationMode(.tail)
                }
                
                    Text(dateFormatter.string(from: record.payment_date))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
            }
            
            Spacer()
            
            // Amount
            Text("+$\(record.amount, specifier: "%.2f")")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Delete Button
            Button(action: {
                showingDeleteAlert = true
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .offset(x: -8, y: 8)
        }
        .alert("确定要删除缴费记录？", isPresented: $showingDeleteAlert) {
            Button("确定", role: .destructive) {
                onDelete()
            }
            Button("取消", role: .cancel) { }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }
} 