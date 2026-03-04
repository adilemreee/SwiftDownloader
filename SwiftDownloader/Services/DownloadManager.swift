import Foundation
import Combine

struct ActiveDownloadInfo {
    let task: URLSessionDownloadTask
    let speedTracker: SpeedTracker
    var downloadedBytes: Int64 = 0
    var totalBytes: Int64 = 0
}

@MainActor
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var activeDownloads: [UUID: ActiveDownloadInfo] = [:]
    @Published var speeds: [UUID: Double] = [:]
    @Published var etas: [UUID: TimeInterval] = [:]
    @Published var totalSpeed: Double = 0

    private var session: URLSession!
    private var pendingQueue: [DownloadItem] = []
    private var downloadToItem: [Int: UUID] = [:]
    private var lastUIUpdateTime: [UUID: CFAbsoluteTime] = [:]

    var maxConcurrentDownloads: Int {
        get { UserDefaults.standard.integer(forKey: Constants.Keys.maxConcurrentDownloads).clamped(to: 1...10) }
        set { UserDefaults.standard.set(newValue, forKey: Constants.Keys.maxConcurrentDownloads) }
    }

    var speedLimitBytesPerSecond: Double {
        let mbps = UserDefaults.standard.double(forKey: Constants.Keys.speedLimitMBps)
        return mbps > 0 ? mbps * 1024 * 1024 : 0
    }

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60 * 60 * 24 // 24 hours
        config.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        UserDefaults.standard.register(defaults: [
            Constants.Keys.maxConcurrentDownloads: Constants.defaultMaxConcurrentDownloads
        ])
    }

    // MARK: - Public API

    func startDownload(item: DownloadItem) {
        guard let url = URL(string: item.url) else {
            item.status = .failed
            item.errorMessage = "Invalid URL"
            return
        }

        if activeDownloads.count >= maxConcurrentDownloads {
            item.status = .waiting
            pendingQueue.append(item)
            return
        }

        beginDownload(item: item, url: url)
    }

    func pauseDownload(item: DownloadItem) {
        guard let info = activeDownloads[item.id] else { return }
        info.task.cancel(byProducingResumeData: { [weak self] resumeData in
            Task { @MainActor in
                item.resumeData = resumeData
                item.status = .paused
                self?.activeDownloads.removeValue(forKey: item.id)
                self?.speeds.removeValue(forKey: item.id)
                self?.etas.removeValue(forKey: item.id)
                self?.updateTotalSpeed()
                self?.processQueue()
            }
        })
    }

    func resumeDownload(item: DownloadItem) {
        if activeDownloads.count >= maxConcurrentDownloads {
            item.status = .waiting
            pendingQueue.insert(item, at: 0)
            return
        }

        if let resumeData = item.resumeData {
            let task = session.downloadTask(withResumeData: resumeData)
            let tracker = SpeedTracker()
            activeDownloads[item.id] = ActiveDownloadInfo(task: task, speedTracker: tracker, downloadedBytes: item.downloadedBytes, totalBytes: item.totalBytes)
            downloadToItem[task.taskIdentifier] = item.id
            item.status = .downloading
            item.resumeData = nil
            task.resume()
        } else if let url = URL(string: item.url) {
            beginDownload(item: item, url: url)
        }
    }

    func cancelDownload(item: DownloadItem) {
        if let info = activeDownloads[item.id] {
            info.task.cancel()
            activeDownloads.removeValue(forKey: item.id)
            speeds.removeValue(forKey: item.id)
            etas.removeValue(forKey: item.id)
            updateTotalSpeed()
        }
        pendingQueue.removeAll { $0.id == item.id }
        item.status = .cancelled
        item.resumeData = nil
        processQueue()
    }

    func retryDownload(item: DownloadItem) {
        item.status = .waiting
        item.downloadedBytes = 0
        item.resumeData = nil
        item.errorMessage = nil
        startDownload(item: item)
    }

    func pauseAll() {
        let items = Array(activeDownloads.keys)
        for id in items {
            // Find the item and pause - caller should manage
            if let info = activeDownloads[id] {
                info.task.cancel(byProducingResumeData: { _ in })
                activeDownloads.removeValue(forKey: id)
            }
        }
        speeds.removeAll()
        etas.removeAll()
        updateTotalSpeed()
    }

    func resumeAll(items: [DownloadItem]) {
        for item in items where item.status == .paused {
            resumeDownload(item: item)
        }
    }

    // MARK: - Private

    private func beginDownload(item: DownloadItem, url: URL) {
        var request = URLRequest(url: url)
        request.setValue("SwiftDownloader/1.0", forHTTPHeaderField: "User-Agent")

        let task = session.downloadTask(with: request)
        let tracker = SpeedTracker()

        activeDownloads[item.id] = ActiveDownloadInfo(task: task, speedTracker: tracker)
        downloadToItem[task.taskIdentifier] = item.id
        item.status = .downloading

        task.resume()
    }

    private func processQueue() {
        while activeDownloads.count < maxConcurrentDownloads, let next = pendingQueue.first {
            pendingQueue.removeFirst()
            if let url = URL(string: next.url) {
                beginDownload(item: next, url: url)
            }
        }
    }

    private func updateTotalSpeed() {
        totalSpeed = speeds.values.reduce(0, +)
    }

    // MARK: - Item Lookup

    // Callback-based item resolution. The app sets this closure so the manager can find items.
    var findItem: ((UUID) -> DownloadItem?)? = nil
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskId = downloadTask.taskIdentifier
        let now = CFAbsoluteTimeGetCurrent()

        Task { @MainActor in
            guard let itemId = downloadToItem[taskId],
                  var info = activeDownloads[itemId] else { return }

            info.downloadedBytes = totalBytesWritten
            info.totalBytes = totalBytesExpectedToWrite
            info.speedTracker.addSample(totalBytes: totalBytesWritten)
            activeDownloads[itemId] = info

            // Throttle UI updates to ~2x per second to prevent flickering
            let lastUpdate = lastUIUpdateTime[itemId] ?? 0
            guard now - lastUpdate >= 0.5 else { return }
            lastUIUpdateTime[itemId] = now

            let speed = info.speedTracker.currentSpeed
            speeds[itemId] = speed
            etas[itemId] = info.speedTracker.estimatedTimeRemaining(
                totalBytes: totalBytesExpectedToWrite,
                downloadedBytes: totalBytesWritten
            )
            updateTotalSpeed()

            if let item = findItem?(itemId) {
                item.downloadedBytes = totalBytesWritten
                item.totalBytes = totalBytesExpectedToWrite
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskId = downloadTask.taskIdentifier

        // MUST move file synchronously — URLSession deletes tmp file after this method returns
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        let safeCopy = tempDir.appendingPathComponent(UUID().uuidString + "_" + (location.lastPathComponent))

        var moveResult: Result<URL, Error>
        do {
            try fileManager.moveItem(at: location, to: safeCopy)
            moveResult = .success(safeCopy)
        } catch {
            moveResult = .failure(error)
        }

        Task { @MainActor in
            guard let itemId = self.downloadToItem[taskId],
                  let item = self.findItem?(itemId) else { return }

            switch moveResult {
            case .success(let safePath):
                let organizer = FileOrganizer.shared
                let destination = organizer.destinationURL(for: item.fileName)

                // Ensure parent directory exists
                let parentDir = destination.deletingLastPathComponent()
                try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)

                do {
                    try fileManager.moveItem(at: safePath, to: destination)
                    item.destinationPath = destination.path
                    item.status = .completed
                    item.dateCompleted = Date()
                    item.downloadedBytes = item.totalBytes
                } catch {
                    item.status = .failed
                    item.errorMessage = error.localizedDescription
                    try? fileManager.removeItem(at: safePath)
                }

            case .failure(let error):
                item.status = .failed
                item.errorMessage = error.localizedDescription
            }

            self.activeDownloads.removeValue(forKey: itemId)
            self.downloadToItem.removeValue(forKey: taskId)
            self.speeds.removeValue(forKey: itemId)
            self.etas.removeValue(forKey: itemId)
            self.updateTotalSpeed()

            self.processQueue()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error as? NSError else { return }

        // Ignore cancellation errors (for pause)
        if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled { return }

        let taskId = task.taskIdentifier

        Task { @MainActor in
            guard let itemId = downloadToItem[taskId],
                  let item = findItem?(itemId) else { return }

            item.status = .failed
            item.errorMessage = error.localizedDescription

            activeDownloads.removeValue(forKey: itemId)
            downloadToItem.removeValue(forKey: taskId)
            speeds.removeValue(forKey: itemId)
            etas.removeValue(forKey: itemId)
            updateTotalSpeed()

            processQueue()
        }
    }
}

// MARK: - Int Extension
private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        if self < range.lowerBound {
            return self == 0 ? Constants.defaultMaxConcurrentDownloads : range.lowerBound
        }
        return Swift.min(self, range.upperBound)
    }
}
