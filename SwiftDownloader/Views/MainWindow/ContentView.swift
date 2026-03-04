import SwiftUI
import SwiftData

struct ContentView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var selectedFilter: SidebarFilter = .all
    @State private var selectedItem: DownloadItem?
    @State private var searchText = ""
    @State private var showAddURL = false
    @State private var showSettings = false
    @State private var newURLText = ""
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 200, ideal: Theme.sidebarWidth, max: 280)
        } detail: {
            if let item = selectedItem {
                // Show detail when an item is selected
                HStack(spacing: 0) {
                    downloadListPanel
                    Divider().background(Theme.border)
                    DownloadDetailView(item: item)
                        .frame(minWidth: 300, idealWidth: 360)
                }
            } else {
                // Full width list when nothing selected
                downloadListPanel
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showAddURL = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .help("Add download URL")
            }
        }
        .sheet(isPresented: $showAddURL) {
            addURLSheet
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(width: 500, height: 600)
                .preferredColorScheme(.dark)
        }
        .onAppear {
            setupDownloadManager()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("clearAllDownloads"))) { _ in
            clearAllDownloads()
        }
    }

    // MARK: - Download List Panel

    private var downloadListPanel: some View {
        DownloadListView(
            selectedFilter: $selectedFilter,
            searchText: $searchText,
            selectedItem: $selectedItem
        )
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // App branding
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.primaryGradient)

                VStack(alignment: .leading, spacing: 1) {
                    Text("SwiftDownloader")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    if !downloadManager.activeDownloads.isEmpty {
                        Text("\(downloadManager.activeDownloads.count) active")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accent)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().background(Theme.border)

            // Filter sections
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    sectionHeader("Downloads")

                    ForEach(DownloadCategory.all) { category in
                        sidebarRow(
                            title: category.name,
                            icon: category.icon,
                            filter: category.filter,
                            isSelected: selectedFilter == category.filter
                        )
                    }

                    Divider().background(Theme.border).padding(.vertical, 8)

                    sectionHeader("Categories")

                    ForEach(DownloadCategory.fileCategories) { category in
                        sidebarRow(
                            title: category.name,
                            icon: category.icon,
                            filter: category.filter,
                            isSelected: selectedFilter == category.filter
                        )
                    }
                }
                .padding(8)
            }

            Divider().background(Theme.border)

            // Settings button
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 20)
                    Text("Settings")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .background(Theme.surfaceSecondary)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(Theme.textTertiary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func sidebarRow(title: String, icon: String, filter: SidebarFilter, isSelected: Bool) -> some View {
        Button {
            withAnimation(Theme.quickAnimation) {
                selectedFilter = filter
                selectedItem = nil
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? Theme.primary : Theme.textTertiary)
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textPrimary : Theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Theme.primary.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add URL Sheet

    private var addURLSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add Download")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Cancel") { showAddURL = false }
                    .buttonStyle(.plain)
                    .foregroundColor(Theme.textSecondary)
            }

            TextField("Paste download URL here...", text: $newURLText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack {
                Spacer()
                Button("Download") {
                    addDownloadFromURL()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newURLText.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    // MARK: - Helpers

    private func setupDownloadManager() {
        downloadManager.findItem = { [self] id in
            let descriptor = FetchDescriptor<DownloadItem>(predicate: #Predicate { $0.id == id })
            return try? modelContext.fetch(descriptor).first
        }
    }

    private func addDownloadFromURL() {
        guard let url = URL(string: newURLText) else { return }
        let fileName = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        let destination = FileOrganizer.shared.destinationURL(for: fileName)
        let category = FileCategory.from(extension: url.fileExtensionLowercased)

        let item = DownloadItem(
            url: newURLText,
            fileName: fileName,
            destinationPath: destination.path,
            category: category
        )
        modelContext.insert(item)
        try? modelContext.save()

        downloadManager.startDownload(item: item)

        newURLText = ""
        showAddURL = false
    }

    private func clearAllDownloads() {
        downloadManager.pauseAll()

        let descriptor = FetchDescriptor<DownloadItem>()
        if let items = try? modelContext.fetch(descriptor) {
            for item in items {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
        selectedItem = nil
    }
}
