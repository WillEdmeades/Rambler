import Foundation

struct SummaryItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var content: String
    var type: ItemType
    var sourceSegmentIDs: [UUID]
    var actionStatus: ActionStatus?
    var isUserEdited: Bool

    enum ItemType: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
        case overview = "Overview"
        case decision = "Decision"
        case actionItem = "Action Item"
        case openQuestion = "Open Question"

        var editorTitle: String {
            switch self {
            case .overview:
                return "Key Point"
            case .decision:
                return "Decision"
            case .actionItem:
                return "Action Item"
            case .openQuestion:
                return "Open Question"
            }
        }

        var sectionTitle: String {
            switch self {
            case .overview:
                return "Key Points"
            case .decision:
                return "Decisions"
            case .actionItem:
                return "Actions"
            case .openQuestion:
                return "Open Questions"
            }
        }

        var systemImage: String {
            switch self {
            case .overview:
                return "text.alignleft"
            case .decision:
                return "checkmark.seal"
            case .actionItem:
                return "checklist"
            case .openQuestion:
                return "questionmark.bubble"
            }
        }
    }
    
    enum ActionStatus: String, Codable, Equatable, Hashable, CaseIterable, Sendable {
        case todo = "To Do"
        case inProgress = "In Progress"
        case done = "Done"
    }

    init(id: UUID = UUID(), content: String, type: ItemType = .overview, sourceSegmentIDs: [UUID] = [], actionStatus: ActionStatus? = nil, isUserEdited: Bool = false) {
        self.id = id
        self.content = content
        self.type = type
        self.sourceSegmentIDs = sourceSegmentIDs
        self.actionStatus = type == .actionItem ? (actionStatus ?? .todo) : nil
        self.isUserEdited = isUserEdited
    }
}
