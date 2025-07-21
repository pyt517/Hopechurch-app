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
                .font(.title2)
                .foregroundColor(.gray)
            
            Divider()
            
            // Column Headers
            HStack {
                Text("Date").fontWeight(.bold)
                Spacer()
                Text("Arrive").fontWeight(.bold)
                Spacer()
                Text("Leave").fontWeight(.bold)
                Spacer()
                Text("Duration").fontWeight(.bold)
            }
            .font(.headline)
            .foregroundColor(.black)

            // Session Rows
            ForEach(sessions) { session in
                HStack {
                    Text(session.arrive_at, formatter: Self.dateFormatter)
                    Spacer()
                    Text(session.arrive_at, formatter: Self.timeFormatter)
                    Spacer()
                    Text(session.leave_at ?? Date(), formatter: Self.timeFormatter)
                    Spacer()
                    Text(formatDuration(session.duration ?? 0))
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