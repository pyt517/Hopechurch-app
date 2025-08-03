import SwiftUI

struct Member: Identifiable, Codable, Equatable, Hashable {
    var member_id: Int
    var name: String
    var remarks: String?
    var is_active: Bool
    var created_at: Date
    var updated_at: Date
    
    var id: Int { member_id }

    enum CodingKeys: String, CodingKey {
        case member_id, name, remarks, is_active, created_at, updated_at
    }
}

struct MemberManagementView: View {
    @Environment(\.dismiss) var dismiss
    @State private var members: [Member] = []
    @State private var showingAddMemberForm = false
    @State private var memberToDelete: Member?
    @State private var showingDeleteAlert = false
    @State private var showingPaymentSheet = false
    @State private var selectedMember: Member? = nil
    @State private var paymentRecords: [PaymentRecord] = []
    
    // Supabase
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Load data from Supabase
    private func loadData() async {
        isLoading = true
        do {
            members = try await SupabaseService.shared.fetchMembers()
            // Payment records are loaded only when needed.
        } catch {
            errorMessage = "Failed to load members: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func addMember(name: String, remarks: String?) async {
        do {
            let newMember = try await SupabaseService.shared.addMember(name: name, remarks: remarks)
            members.insert(newMember, at: 0)
        } catch {
            errorMessage = "Failed to add member: \(error.localizedDescription)"
        }
    }

    private func deleteMember(_ member: Member) async {
        do {
            try await SupabaseService.shared.deleteMember(memberId: member.id)
            members.removeAll { $0.id == member.id }
        } catch {
            errorMessage = "Failed to delete member: \(error.localizedDescription)"
        }
    }

    private func updateStatus(for member: Member, isActive: Bool) async {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        
        do {
            try await SupabaseService.shared.updateMemberStatus(memberId: member.id, isActive: isActive)
            members[index].is_active = isActive
        } catch {
            errorMessage = "Failed to update status: \(error.localizedDescription)"
        }
    }
    
    private func loadPaymentRecords() {
        if let data = UserDefaults.standard.data(forKey: "PaymentRecords"),
           let decodedRecords = try? JSONDecoder().decode([PaymentRecord].self, from: data) {
            paymentRecords = decodedRecords
        }
    }
    
    private func groupedPayments(for member: Member) -> [(String, [PaymentRecord])] {
        let calendar = Calendar.current
        let memberRecords = paymentRecords.filter { $0.member_id == member.id }
        let grouped = Dictionary(grouping: memberRecords) { (record) -> String in
            let comps = calendar.dateComponents([.year, .month], from: record.payment_date)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 240/255, green: 249/255, blue: 255/255)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    // Title on the left
                    HStack(spacing: 8) {
                        Image(systemName: "person.2")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                        Text("会员管理")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
                    }
                    
                    Spacer()
                    
                    // Close button on the right
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
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Member Count Card
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 18))
                                    .foregroundColor(.blue)
                                Text("会员总数")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                            Text("\(members.count)人")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text("活跃: \(members.filter { $0.is_active }.count)人")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(red: 204/255, green: 227/255, blue: 234/255))
                        .cornerRadius(12)
                        
                        // Add Member Button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAddMemberForm = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("添加新会员")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(showingAddMemberForm)
                        .opacity(showingAddMemberForm ? 0.5 : 1)
                        
                        // Add Member Form (Conditional)
                        if showingAddMemberForm {
                            AddMemberFormView(isVisible: $showingAddMemberForm) { name, remarks in
                                Task {
                                    await addMember(name: name, remarks: remarks)
                                }
                            }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                        }
                        
                        // Tip Card
                        HStack {
                            Image(systemName: "eye")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text("点击会员头像可查看详细缴费记录")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Member List
                        LazyVStack(spacing: 12) {
                            ForEach($members) { $member in
                                MemberCard(
                                    member: $member,
                                    onDelete: {
                                    memberToDelete = member
                                    showingDeleteAlert = true
                                    },
                                    onStatusChanged: { isActive in
                                        Task {
                                            await updateStatus(for: member, isActive: isActive)
                                        }
                                    },
                                    onShowPaymentDetail: {
                                        selectedMember = member
                                        showingPaymentSheet = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("确定要删除会员？", isPresented: $showingDeleteAlert) {
            Button("确定", role: .destructive) {
                if let member = memberToDelete {
                    Task {
                        await deleteMember(member)
                    }
                }
            }
            Button("取消", role: .cancel) {}
        }
        .onAppear {
            Task {
                await loadData()
            }
            loadPaymentRecords()
        }
        .onChange(of: members) { _ in
            saveMembers()
        }
        // 新增：弹窗展示该会员的缴费记录
        .sheet(isPresented: $showingPaymentSheet) {
            if let member = selectedMember {
                PaymentHistorySheet(member: member)
            }
        }
    }
    
    // Save members to UserDefaults
    private func saveMembers() {
        if let encoded = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(encoded, forKey: "members") // Changed key to "members"
        }
    }
}

struct MemberCard: View {
    @Binding var member: Member
    let onDelete: () -> Void
    let onStatusChanged: (Bool) -> Void
    let onShowPaymentDetail: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(member.is_active ? Color(red: 0/255, green: 150/255, blue: 136/255) : Color.gray)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.name.prefix(1)))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .onTapGesture {
                        onShowPaymentDetail()
                    }
                
                // Member Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(member.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(member.is_active ? .black : .gray)
                        
                        // 状态标签
                        Text(member.is_active ? "活跃" : "不活跃")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(member.is_active ? .white : .gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(member.is_active ? Color(red: 0/255, green: 150/255, blue: 136/255) : Color.gray.opacity(0.3))
                            .cornerRadius(8)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    
                    if let remarks = member.remarks {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text(remarks)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    // 状态选择器
                    Picker("状态", selection: $member.is_active) {
                        Text("活跃").tag(true)
                        Text("不活跃").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 120)
                    .tint(member.is_active ? Color(red: 0/255, green: 150/255, blue: 136/255) : .gray)
                    .onChange(of: member.is_active) { oldValue, newValue in
                        onStatusChanged(newValue)
                    }
                }
                
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            // Delete Button
            Button(action: onDelete) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .offset(x: -8, y: 8)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}



struct AddMemberFormView: View {
    @Binding var isVisible: Bool
    
    @State private var name = ""
    @State private var remarks = ""
    
    var onAddMember: (String, String?) async -> Void
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Name Row
            HStack(spacing: 16) {
                Text("姓名 *")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 70, alignment: .leading)
                
                TextField("输入会员姓名", text: $name)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 240/255, green: 249/255, blue: 255/255), lineWidth: 2)
                    )
            }
            
            // Contact Row
            HStack(spacing: 16) {
                Text("备注")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(width: 70, alignment: .leading)
                
                TextField("备注信息（可选）", text: $remarks)
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 240/255, green: 249/255, blue: 255/255), lineWidth: 2)
                    )
            }
            
            // Divider
            Divider()
                .padding(.vertical, 8)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isVisible = false
                        resetForm()
                    }
                }) {
                    Text("取消")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    Task {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedRemarks = remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : remarks.trimmingCharacters(in: .whitespacesAndNewlines)
                        await onAddMember(trimmedName, trimmedRemarks)
                        
                        // Ensure UI updates on the main thread
                        await MainActor.run {
                            isVisible = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 16))
                        Text("保存")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0/255, green: 150/255, blue: 136/255))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1 : 0.5)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func resetForm() {
        name = ""
        remarks = ""
    }
} 

// MARK: - Payment History Sheet
struct PaymentHistorySheet: View {
    let member: Member
    @State private var payments: [PaymentRecord] = []
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss

    private var groupedPayments: [(String, [PaymentRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: payments) { (record) -> String in
            let comps = calendar.dateComponents([.year, .month], from: record.payment_date)
            return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        ZStack {
            Color(red: 240/255, green: 249/255, blue: 255/255).ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Text("\(member.name) 的缴费记录")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(8)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding()

                // Content
                if isLoading {
                    Spacer()
                    ProgressView("正在加载...")
                    Spacer()
                } else if payments.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.8))
                        Text("暂无缴费记录")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 15) {
                            ForEach(groupedPayments, id: \.0) { month, records in
                                Text(formatMonthHeader(month))
                                    .font(.system(size: 18, weight: .bold))
                                    .padding(.top)

                                ForEach(records) { record in
                                    paymentRecordRow(record)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            Task {
                isLoading = true
                do {
                    payments = try await SupabaseService.shared.fetchPaymentRecords(for: member.id)
                } catch {
                    // Handle error silently for now
                    print("Failed to fetch payment records: \(error)")
                }
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private func paymentRecordRow(_ record: PaymentRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title2)
                .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))

            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(record.payment_date))
                    .font(.system(size: 16))

                if let remarks = record.remarks, !remarks.isEmpty {
                    Text(remarks)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("+ ￥\(record.amount, specifier: "%.2f")")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0/255, green: 150/255, blue: 136/255))
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    private func formatMonthHeader(_ monthString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        guard let date = formatter.date(from: monthString) else {
            return monthString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy年 MMMM"
        displayFormatter.locale = Locale(identifier: "zh_CN")
        return displayFormatter.string(from: date)
    }
} 