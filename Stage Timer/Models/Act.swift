import Foundation

struct Act: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var duration: TimeInterval
    var startTime: Date
    var attachmentImage: Data?
    
    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }
} 