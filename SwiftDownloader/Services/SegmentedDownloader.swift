import Foundation
import AppKit

/// Downloads a single file using multiple concurrent HTTP Range requests (segments).
/// Falls back to single-connection if the server doesn't support Range.
actor SegmentedDownloader {
    private let url: URL
    private let destinationURL: URL
    private let segmentCount: Int
    private var totalBytes: Int64 = 0
    private var downloadedBytes: [Int: Int64] = [:]
    private var segmentTasks: [Int: URLSessionDataTask] = [:]
    private var segmentData: [Int: Data] = [:]
    private var completedSegments: Set<Int> = []
    private var isCancelled = false

    let onProgress: @Sendable (Int64, Int64, Double) -> Void // downloaded, total, speed

    init(url: URL, destinationURL: URL, segmentCount: Int = 4,
         onProgress: @escaping @Sendable (Int64, Int64, Double) -> Void) {
        self.url = url
        self.destinationURL = destinationURL
        self.segmentCount = segmentCount
        self.onProgress = onProgress
    }

    /// Check if server supports Range requests and get file size
    func getFileInfo() async -> (supportsRange: Bool, contentLength: Int64) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("SwiftDownloader/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, 0)
            }

            let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0
            let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased()
            let supportsRange = acceptRanges == "bytes" && contentLength > 0

            return (supportsRange, contentLength)
        } catch {
            return (false, 0)
        }
    }

    /// Start segmented download
    func download() async throws -> URL {
        let info = await getFileInfo()
        totalBytes = info.contentLength

        // Only use segmented download for files > 5MB that support Range
        let minSegmentSize: Int64 = 5 * 1024 * 1024
        guard info.supportsRange && totalBytes > minSegmentSize else {
            return try await singleConnectionDownload()
        }

        let segmentSize = totalBytes / Int64(segmentCount)
        var segments: [(start: Int64, end: Int64)] = []

        for i in 0..<segmentCount {
            let start = Int64(i) * segmentSize
            let end = (i == segmentCount - 1) ? (totalBytes - 1) : (start + segmentSize - 1)
            segments.append((start, end))
        }

        // Initialize segment data
        for i in 0..<segmentCount {
            segmentData[i] = Data()
            downloadedBytes[i] = 0
        }

        // Download all segments concurrently
        try await withThrowingTaskGroup(of: (Int, Data).self) { group in
            for (index, segment) in segments.enumerated() {
                group.addTask { [url] in
                    guard !Task.isCancelled else { throw CancellationError() }
                    let data = try await self.downloadSegment(index: index, url: url, start: segment.start, end: segment.end)
                    return (index, data)
                }
            }

            for try await (index, data) in group {
                segmentData[index] = data
                completedSegments.insert(index)
            }
        }

        // Merge segments
        return try assembleSegments()
    }

    func cancel() {
        isCancelled = true
        for task in segmentTasks.values {
            task.cancel()
        }
        segmentTasks.removeAll()
    }

    // MARK: - Private

    private func downloadSegment(index: Int, url: URL, start: Int64, end: Int64) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("SwiftDownloader/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 206 else {
            throw URLError(.badServerResponse)
        }

        var data = Data()
        let expectedSize = end - start + 1
        data.reserveCapacity(Int(expectedSize))

        var lastReport = CFAbsoluteTimeGetCurrent()

        for try await byte in bytes {
            guard !isCancelled else { throw CancellationError() }
            data.append(byte)

            let now = CFAbsoluteTimeGetCurrent()
            if now - lastReport >= 0.3 {
                lastReport = now
                let segmentDownloaded = Int64(data.count)
                await updateProgress(segment: index, downloaded: segmentDownloaded)
            }
        }

        await updateProgress(segment: index, downloaded: Int64(data.count))
        return data
    }

    private func updateProgress(segment: Int, downloaded: Int64) {
        downloadedBytes[segment] = downloaded
        let totalDown = downloadedBytes.values.reduce(0, +)
        let speed = Double(totalDown) / max(1, CFAbsoluteTimeGetCurrent() - 1)
        onProgress(totalDown, totalBytes, speed)
    }

    private func assembleSegments() throws -> URL {
        let parentDir = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        var mergedData = Data()
        for i in 0..<segmentCount {
            guard let data = segmentData[i] else {
                throw NSError(domain: "SegmentedDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing segment \(i)"])
            }
            mergedData.append(data)
        }

        try mergedData.write(to: destinationURL)
        return destinationURL
    }

    private func singleConnectionDownload() async throws -> URL {
        var request = URLRequest(url: url)
        request.setValue("SwiftDownloader/1.0", forHTTPHeaderField: "User-Agent")

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0
        totalBytes = contentLength

        var data = Data()
        if contentLength > 0 { data.reserveCapacity(Int(contentLength)) }

        var lastReport = CFAbsoluteTimeGetCurrent()
        let startTime = lastReport

        for try await byte in bytes {
            guard !isCancelled else { throw CancellationError() }
            data.append(byte)

            let now = CFAbsoluteTimeGetCurrent()
            if now - lastReport >= 0.3 {
                lastReport = now
                let elapsed = now - startTime
                let speed = elapsed > 0 ? Double(data.count) / elapsed : 0
                onProgress(Int64(data.count), totalBytes, speed)
            }
        }

        let parentDir = destinationURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        try data.write(to: destinationURL)

        onProgress(Int64(data.count), totalBytes, 0)
        return destinationURL
    }
}
