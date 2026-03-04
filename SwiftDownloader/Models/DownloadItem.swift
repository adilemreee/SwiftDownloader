import Foundation
import SwiftData

enum DownloadStatus: String, Codable {
    case waiting = "Waiting"
    case downloading = "Downloading"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case scheduled = "Scheduled"

    var iconName: String {
        switch self {
        case .waiting: return "clock"
        case .downloading: return "arrow.down.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .scheduled: return "calendar.circle"
        }
    }

    var isActive: Bool {
        self == .downloading || self == .waiting
    }
}

@Model
final class DownloadItem {
    @Attribute(.unique) var id: UUID
    var url: String
    var fileName: String
    var destinationPath: String
    var totalBytes: Int64
    var downloadedBytes: Int64
    var status: DownloadStatus
    var category: FileCategory
    var dateAdded: Date
    var dateCompleted: Date?
    var scheduledDate: Date?
    var resumeData: Data?
    var errorMessage: String?
    var mimeType: String?

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(downloadedBytes) / Double(totalBytes)
    }

    var progressPercentage: String {
        String(format: "%.1f%%", progress * 100)
    }

    init(
        url: String,
        fileName: String,
        destinationPath: String,
        category: FileCategory = .other,
        scheduledDate: Date? = nil
    ) {
        self.id = UUID()
        self.url = url
        self.fileName = fileName
        self.destinationPath = destinationPath
        self.totalBytes = 0
        self.downloadedBytes = 0
        self.status = scheduledDate != nil ? .scheduled : .waiting
        self.category = category
        self.dateAdded = Date()
        self.scheduledDate = scheduledDate
    }
}
