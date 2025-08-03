import Foundation

// MARK: - Payment Record Model
struct PaymentRecord: Identifiable, Codable, Equatable, Hashable {
    var payment_id: Int
    var member_id: Int
    var payment_date: Date
    var amount: Double
    var remarks: String?
    var created_at: Date
    var members: Member? // For JOINed data
    
    // Conforming to Identifiable
    var id: Int { payment_id }

    enum CodingKeys: String, CodingKey {
        case payment_id, member_id, payment_date, amount, remarks, created_at, members
    }
    
    // This initializer is for local creation before sending to DB.
    // Supabase will generate payment_id and created_at.
    init(member_id: Int, payment_date: Date, amount: Double, remarks: String?) {
        self.payment_id = 0 // Temporary ID
        self.member_id = member_id
        self.payment_date = payment_date
        self.amount = amount
        self.remarks = remarks
        self.created_at = Date() // Temporary date
    }
}

// In UsageSession.swift
enum ExpenseType: String, Codable {
    case income = "非会员缴费"
    case expense = "花销"
}

struct ExpenseRecord: Identifiable, Codable, Equatable, Hashable {
    var expense_id: Int
    var type: ExpenseType
    var amount: Double
    var expense_date: Date
    var notes: String?
    var created_at: Date
    
    // Conforming to Identifiable
    var id: Int { expense_id }

    enum CodingKeys: String, CodingKey {
        case expense_id, type, amount, expense_date, notes, created_at
    }
}

struct UsageSession: Codable, Identifiable {
    let id: Int
    let arrive_at: Date
    let leave_at: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case arrive_at
        case leave_at
    }
}

extension UsageSession {
    private static let ratePerHour: Double = 10.0

    var duration: TimeInterval? {
        guard let leave = leave_at else { return nil }
        return leave.timeIntervalSince(arrive_at)
    }

    var cost: Double? {
        guard let duration = duration else { return nil }
        let hours = duration / 3600
        return hours * UsageSession.ratePerHour
    }
} 