import Foundation

enum CheckInType: String, Codable {
    case enter = "进入"
    case leave = "离开"
}

struct CheckInEvent: Codable, Identifiable {
    let id: UUID
    let type: CheckInType
    let date: Date
    
    init(type: CheckInType, date: Date = Date()) {
        self.id = UUID()
        self.type = type
        self.date = date
    }
} 