import Foundation

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