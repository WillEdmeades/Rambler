import Foundation

@MainActor
final class IntentState {
    static let shared = IntentState()
    
    var pendingSummaryTargetID: UUID?
    var pendingSelectedTab: String?
    
    private init() {}
}
