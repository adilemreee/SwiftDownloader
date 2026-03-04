import SwiftUI
import SwiftData

struct DownloadListView: View {
    @Query(sort: \DownloadItem.dateAdded, order: .reverse) private var allItems: [DownloadItem]
    @ObservedObject var downloadManager = DownloadManager.shared
    @Binding var selectedFilter: SidebarFilter
    @Binding var searchText: String
    @Binding var selectedItem: DownloadItem?
    @Environment(\.modelContext) private var modelContext

    private var filteredItems: [DownloadItem] {
        allItems.filter { item in
            let matchesFilter = selectedFilter.matches(item)
            let matchesSearch = searchText.isEmpty || item.fileName.localizedCaseInsensitiveContains(searchText)
            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBar
            Divider().background(Theme.border)

            if filteredItems.isEmpty {
                EmptyStateView(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            DownloadRowView(item: item)
                                .background(selectedItem?.id == item.id ? Theme.primary.opacity(0.1) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall))
                                .onTapGesture {
                                    withAnimation(Theme.quickAnimation) {
                                        selectedItem = (selectedItem?.id == item.id) ? nil : item
                                    }
                                }
                                .contextMenu {
                                    contextMenuItems(for: item)
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Theme.surfacePrimary)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("\(filteredItems.count) items")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }

            Spacer()

            HStack(spacing: 8) {
                if !downloadManager.activeDownloads.isEmpty {
                    SpeedBadge(speed: downloadManager.totalSpeed)

                    Button(action: { downloadManager.pauseAll() }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.warning)
                            .frame(width: 28, height: 28)
                            .background(Theme.warning.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Pause All")
                }

                if !allItems.isEmpty {
                    Button(action: { clearAllDownloads() }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.error)
                            .frame(width: 28, height: 28)
                            .background(Theme.error.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Clear All Downloads")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textTertiary)
                .font(.system(size: 12))
            TextField("Search downloads...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(Theme.textPrimary)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textTertiary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Titles

    private var headerTitle: String {
        switch selectedFilter {
        case .all: return "All Downloads"
        case .active: return "Active"
        case .completed: return "Completed"
        case .scheduled: return "Scheduled"
        case .history: return "History"
        case .category(let cat): return cat.rawValue
        }
    }

    private var emptyIcon: String {
        switch selectedFilter {
        case .active: return "arrow.down.circle"
        case .completed: return "checkmark.circle"
        case .scheduled: return "calendar.circle"
        default: return "tray"
        }
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .active: return "No Active Downloads"
        case .completed: return "No Completed Downloads"
        case .scheduled: return "No Scheduled Downloads"
        default: return "No Downloads"
        }
    }

    private var emptySubtitle: String {
        "Downloads from Safari will appear here.\nEnable the extension in Safari preferences."
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for item: DownloadItem) -> some View {
        if item.status == .downloading {
            Button("Pause") { downloadManager.pauseDownload(item: item) }
            Button("Cancel") { downloadManager.cancelDownload(item: item) }
        }
        if item.status == .paused {
            Button("Resume") { downloadManager.resumeDownload(item: item) }
            Button("Cancel") { downloadManager.cancelDownload(item: item) }
        }
        if item.status == .failed || item.status == .cancelled {
            Button("Retry") { downloadManager.retryDownload(item: item) }
        }
        if item.status == .completed {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.destinationPath)])
            }
            Button("Open") {
                NSWorkspace.shared.open(URL(fileURLWithPath: item.destinationPath))
            }
        }
        Divider()
        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url, forType: .string)
        }
        Divider()
        Button("Delete", role: .destructive) {
            deleteItem(item)
        }
    }

    // MARK: - Actions

    private func deleteItem(_ item: DownloadItem) {
        if item.status == .downloading || item.status == .paused {
            downloadManager.cancelDownload(item: item)
        }
        if selectedItem?.id == item.id {
            selectedItem = nil
        }
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func clearAllDownloads() {
        downloadManager.pauseAll()
        for item in allItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
        selectedItem = nil
    }
}
