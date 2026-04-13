import Foundation

enum AskRamblerQuickAction: String, CaseIterable, Identifiable, Sendable {
    case summarize
    case keyPoints
    case decisions
    case actionList
    case openQuestions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summarize:
            return "Summarize"
        case .keyPoints:
            return "Key Points"
        case .decisions:
            return "Decisions"
        case .actionList:
            return "Actions"
        case .openQuestions:
            return "Open Questions"
        }
    }

    var systemImage: String {
        switch self {
        case .summarize:
            return "text.alignleft"
        case .keyPoints:
            return "list.bullet"
        case .decisions:
            return "checkmark.seal"
        case .actionList:
            return "checklist"
        case .openQuestions:
            return "questionmark.bubble"
        }
    }

    var defaultPrompt: String {
        switch self {
        case .summarize:
            return "Summarize this conversation in a short paragraph."
        case .keyPoints:
            return "What are the most important key points from this conversation?"
        case .decisions:
            return "What decisions were made in this conversation?"
        case .actionList:
            return "What follow-up actions came out of this conversation?"
        case .openQuestions:
            return "What still seems unresolved in this conversation?"
        }
    }

    var itemType: SummaryItem.ItemType? {
        switch self {
        case .summarize:
            return nil
        case .keyPoints:
            return .overview
        case .decisions:
            return .decision
        case .actionList:
            return .actionItem
        case .openQuestions:
            return .openQuestion
        }
    }

    var suggestedSaveDestination: AskRamblerSaveDestination {
        switch self {
        case .summarize:
            return .summary
        case .keyPoints:
            return .keyPoint
        case .decisions:
            return .decision
        case .actionList:
            return .actionItem
        case .openQuestions:
            return .openQuestion
        }
    }
}

enum AskRamblerSaveDestination: String, CaseIterable, Identifiable, Sendable {
    case summary
    case keyPoint
    case decision
    case actionItem
    case openQuestion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summary:
            return "Replace Summary"
        case .keyPoint:
            return "Save as Key Point"
        case .decision:
            return "Save as Decision"
        case .actionItem:
            return "Add to Actions"
        case .openQuestion:
            return "Save as Question"
        }
    }

    var systemImage: String {
        switch self {
        case .summary:
            return "text.alignleft"
        case .keyPoint:
            return "list.bullet"
        case .decision:
            return "checkmark.seal"
        case .actionItem:
            return "checklist"
        case .openQuestion:
            return "questionmark.bubble"
        }
    }

    var itemType: SummaryItem.ItemType? {
        switch self {
        case .summary:
            return nil
        case .keyPoint:
            return .overview
        case .decision:
            return .decision
        case .actionItem:
            return .actionItem
        case .openQuestion:
            return .openQuestion
        }
    }

    func successMessage(savedCount: Int) -> String {
        switch self {
        case .summary:
            return "Summary updated."
        case .keyPoint:
            return savedCount == 1 ? "Saved as a key point." : "Saved as \(savedCount) key points."
        case .decision:
            return savedCount == 1 ? "Saved as a decision." : "Saved as \(savedCount) decisions."
        case .actionItem:
            return savedCount == 1 ? "Added to actions." : "Added \(savedCount) actions."
        case .openQuestion:
            return savedCount == 1 ? "Saved as an open question." : "Saved as \(savedCount) open questions."
        }
    }

    func duplicateMessage() -> String {
        switch self {
        case .summary:
            return "Summary already matches this answer."
        case .keyPoint:
            return "That key point is already in Review."
        case .decision:
            return "That decision is already in Review."
        case .actionItem:
            return "That action is already in Review."
        case .openQuestion:
            return "That question is already in Review."
        }
    }
}

struct AskRamblerResponse: Equatable, Sendable {
    let title: String
    let prompt: String
    let answer: String
    let sourceSegmentIDs: [UUID]
    let suggestedSaveDestination: AskRamblerSaveDestination?
}

enum AskRamblerState: Equatable, Sendable {
    case idle
    case generating(title: String)
    case failed(message: String)
    case ready(AskRamblerResponse)
}
