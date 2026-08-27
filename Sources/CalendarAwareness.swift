import EventKit
import Foundation

final class CalendarAwareness {
    private let eventStore = EKEventStore()

    func requestFullAccess() {
        eventStore.requestFullAccessToEvents { _, _ in }
    }

    func isMeetingInProgress(at date: Date = Date()) -> Bool {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            return false
        }

        let predicate = eventStore.predicateForEvents(
            withStart: date.addingTimeInterval(-1),
            end: date.addingTimeInterval(1),
            calendars: nil
        )

        return eventStore.events(matching: predicate).contains { event in
            guard
                !event.isAllDay,
                event.status != .canceled,
                let startDate = event.startDate,
                let endDate = event.endDate,
                startDate <= date,
                endDate > date
            else {
                return false
            }

            let currentUserStatus = event.attendees?
                .first(where: { $0.isCurrentUser })?
                .participantStatus
            return currentUserStatus != .declined
        }
    }
}
