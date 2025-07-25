import SwiftUI

struct ReportView: View {
    let month: Int
    let year: Int
    let sessions: [UsageSession]
    let totalDuration: TimeInterval
    let totalCost: String
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "en_US")
        let date = Calendar.current.date(from: DateComponents(month: month))!
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Hopechurch Pingpang Use Record")
                .font(.largeTitle.bold())
                .foregroundColor(.black)
            Text("\(monthName) \(String(year))")
                .font(.title2.bold())
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Divider()
            
            // Column Headers
            HStack(spacing: 0) {
                Text("Date").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                Text("Arrive").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                Text("Leave").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
                Text("Duration").fontWeight(.bold).frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.headline)
            .foregroundColor(.black)

            // Session Rows
            ForEach(sessions) { session in
                HStack(spacing: 0) {
                    Text(session.arrive_at, formatter: Self.dateFormatter)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(session.arrive_at, formatter: Self.timeFormatter)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(session.leave_at ?? Date(), formatter: Self.timeFormatter)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(formatDuration(session.duration ?? 0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.body)
                .foregroundColor(.black)
                Divider()
            }
            
            Spacer()
            
            // Totals
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Total Time:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(formatDuration(totalDuration))
                        .fontWeight(.bold)
                }
                HStack {
                    Text("Total Cost:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(totalCost)
                        .fontWeight(.bold)
                }
            }
            .font(.title3)
            .foregroundColor(.black)
        }
        .padding(30)
        .background(Color.white)
        .frame(width: 600) // Fixed width for consistent rendering
    }
    
    // --- Formatters and Helpers for English Output ---
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration >= 60 else { return "<1 min" }
        
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
} 
