import EventKit

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var hasCalendarAccess = false
    @Published var isEnabled = true
    private var updateSchedule: (([Act]) -> Void)?
    
    init() {
        Task { @MainActor in
            await requestAccess()
        }
    }
    
    func startMonitoring(updateSchedule: @escaping ([Act]) -> Void) {
        self.updateSchedule = updateSchedule
        
        Task { @MainActor in
            await requestAccess()
            if hasCalendarAccess && isEnabled {
                await updateScheduleFromEvents(updateSchedule)
            }
        }
        
        // Monitor calendar changes
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.updateScheduleFromEvents(updateSchedule)
            }
        }
    }
    
    private func updateScheduleFromEvents(_ updateSchedule: @escaping ([Act]) -> Void) async {
        if isEnabled {
            let events = await fetchEvents(for: Date())
            let acts = convertToActs(from: events)
            updateSchedule(acts)
        }
    }
    
    func requestAccess() async {
        if #available(iOS 17.0, macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    hasCalendarAccess = granted
                }
            } catch {
                print("Failed to request calendar access: \(error)")
            }
        } else {
            await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    Task { @MainActor in
                        self?.hasCalendarAccess = granted
                        continuation.resume()
                    }
                }
            }
        }
    }
    
    func fetchEvents(for date: Date) async -> [EKEvent] {
        guard hasCalendarAccess else { return [] }
        
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate).filter { !$0.isAllDay }
    }
    
    func convertToActs(from events: [EKEvent]) -> [Act] {
        return events.map { event in
            // Create the Act without attachment for now
            // EKEvent doesn't directly support attachments in the way we were trying to use
            return Act(
                name: event.title,
                duration: event.endDate.timeIntervalSince(event.startDate),
                startTime: event.startDate,
                attachmentImage: nil
            )
        }
    }
    
    func toggleSync(enabled: Bool, updateSchedule: @escaping ([Act]) -> Void) {
        isEnabled = enabled
        if enabled {
            Task {
                // Request access first when enabling sync
                await requestAccess()
                if hasCalendarAccess {
                    let events = await fetchEvents(for: Date())
                    let acts = convertToActs(from: events)
                    await MainActor.run {
                        updateSchedule(acts)
                    }
                }
            }
        } else {
            updateSchedule([]) // Clear schedule when disabled
        }
    }
} 