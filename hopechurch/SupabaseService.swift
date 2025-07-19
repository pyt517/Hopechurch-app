import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    private let supabase: SupabaseClient

    private init() {
        guard let path = Bundle.main.path(forResource: "Supabase-Keys", ofType: "plist"),
              let keys = NSDictionary(contentsOfFile: path),
              let supabaseURLString = keys["SUPABASE_URL"] as? String,
              let supabaseKey = keys["SUPABASE_KEY"] as? String,
              let supabaseURL = URL(string: supabaseURLString) else {
            fatalError("Supabase-Keys.plist not found or is invalid.")
        }
        
        supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }

    // --- Session Operations ---

    /// Fetches all sessions from the 'time' table, sorted by arrival time.
    func fetchSessions() async throws -> [UsageSession] {
        let response: [UsageSession] = try await supabase.from("time").select().execute().value
        return response.sorted { $0.arrive_at > $1.arrive_at }
    }

    /// Creates a new session by inserting a record with the current arrival time.
    /// Returns the newly created session.
    @discardableResult
    func startNewSession() async throws -> UsageSession {
        let newSession = PartialUsageSession(arrive_at: Date())
        let response: [UsageSession] = try await supabase.from("time").insert(newSession).select().execute().value
        guard let createdSession = response.first else {
            throw NSError(domain: "SupabaseServiceError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to decode new session."])
        }
        return createdSession
    }

    /// Ends the current active session (the one without a leave_at time).
    /// Returns the updated session.
    @discardableResult
    func endCurrentSession() async throws -> UsageSession? {
        // Find the current open session
        let openSessions: [UsageSession] = try await supabase.from("time")
            .select()
            .is("leave_at", value: nil)
            .order("arrive_at", ascending: false)
            .limit(1)
            .execute().value

        guard let currentSession = openSessions.first else {
            // No open session found, which might be a valid state.
            print("No active session to end.")
            return nil
        }
        
        // Update it with the leave time
        let updatedSession = PartialUsageSession(leave_at: Date())
        let response: [UsageSession] = try await supabase.from("time")
            .update(updatedSession)
            .eq("id", value: currentSession.id)
            .select()
            .execute().value
        
        return response.first
    }
    
    /// Creates a complete, manually entered session.
    func addManualSession(arriveAt: Date, leaveAt: Date) async throws {
        let manualSession = PartialUsageSession(arrive_at: arriveAt, leave_at: leaveAt)
        try await supabase.from("time").insert(manualSession).execute()
    }

    /// Deletes a session by its ID.
    func deleteSession(id: Int) async throws {
        try await supabase.from("time").delete().eq("id", value: id).execute()
    }
}

// A helper struct for partial updates/inserts
fileprivate struct PartialUsageSession: Codable {
    var arrive_at: Date? = nil
    var leave_at: Date? = nil
} 