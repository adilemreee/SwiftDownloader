import SwiftUI

struct DownloadDetailView: View {
    @Bindable var item: DownloadItem
    @ObservedObject var downloadManager = DownloadManager.shared

    private var speed: Double { downloadManager.speeds[item.id] ?? 0 }
    private var eta: TimeInterval { downloadManager.etas[item.id] ?? .infinity }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider().background(Theme.border)

                // Progress section
                if item.status.isActive || item.status == .paused {
                    progressSection
                }

                // Info section
                infoSection

                Divider().background(Theme.border)

                // Actions
                actionButtons

                Spacer()
            }
            .padding(24)
        }
        .background(Theme.surfaceSecondary)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            CategoryIcon(category: item.category, size: 56)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.fileName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(2)

                StatusBadge(status: item.status)
            }

            Spacer()
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProgressBar(progress: item.progress, height: 8)

            HStack {
                Text(item.progressPercentage)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.primary)

                Spacer()

                if item.status == .downloading {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(speed.formattedSpeed)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)

                        if !eta.isInfinite {
                            Text("\(eta.formattedETA) remaining")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
            }

            if item.totalBytes > 0 {
                Text("\(item.downloadedBytes.formattedFileSize) of \(item.totalBytes.formattedFileSize)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(16)
        .background(Theme.surfaceTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textSecondary)

            infoRow(label: "URL", value: item.url)
            infoRow(label: "Category", value: item.category.rawValue)
            infoRow(label: "Added", value: item.dateAdded.shortFormatted)

            if let completed = item.dateCompleted {
                infoRow(label: "Completed", value: completed.shortFormatted)
            }
            if item.status == .completed {
                infoRow(label: "Location", value: item.destinationPath)
            }
            if let error = item.errorMessage {
                infoRow(label: "Error", value: error, valueColor: Theme.error)
            }
        }
    }

    private func infoRow(label: String, value: String, valueColor: Color = Theme.textPrimary) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(valueColor)
                .lineLimit(3)
                .textSelection(.enabled)

            Spacer()
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            switch item.status {
            case .downloading:
                actionBtn("Pause", icon: "pause.fill", color: Theme.warning) {
                    downloadManager.pauseDownload(item: item)
                }
                actionBtn("Cancel", icon: "xmark", color: Theme.error) {
                    downloadManager.cancelDownload(item: item)
                }
            case .paused:
                actionBtn("Resume", icon: "play.fill", color: Theme.accent) {
                    downloadManager.resumeDownload(item: item)
                }
                actionBtn("Cancel", icon: "xmark", color: Theme.error) {
                    downloadManager.cancelDownload(item: item)
                }
            case .failed, .cancelled:
                actionBtn("Retry", icon: "arrow.clockwise", color: Theme.primary) {
                    downloadManager.retryDownload(item: item)
                }
            case .completed:
                actionBtn("Show in Finder", icon: "folder", color: Theme.textSecondary) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.destinationPath)])
                }
                actionBtn("Open", icon: "arrow.up.forward.square", color: Theme.primary) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.destinationPath))
                }
            default:
                EmptyView()
            }
            Spacer()
        }
    }

    private func actionBtn(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
