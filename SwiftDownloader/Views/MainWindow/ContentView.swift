import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedFilter: SidebarFilter = .all
    @State private var selectedItem: DownloadItem?
    @State private var searchText = ""
    @State private var showAddURL = false
    @State private var showSettings = false
    @State private var newURLText = ""
    @State private var isDragOver = false
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else {
                mainView
            }
        }
    }

    private var mainView: some View {
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
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 320)
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
        // Drag & Drop URL
        .onDrop(of: [.url, .text], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
        }
        .overlay {
            if isDragOver {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.primary)
                        Text("Drop URL to download")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        // Keyboard shortcuts
        .keyboardShortcut("n", modifiers: .command)
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

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            addDownloadByURLString(url.absoluteString)
                        }
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.text.identifier) { item, _ in
                    if let text = item as? String, text.hasPrefix("http") {
                        DispatchQueue.main.async {
                            addDownloadByURLString(text)
                        }
                    }
                }
                return true
            }
        }
        return false
    }

    private func addDownloadByURLString(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let fileName = url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
        let destination = FileOrganizer.shared.destinationURL(for: fileName)
        let category = FileCategory.from(extension: url.fileExtensionLowercased)

        let item = DownloadItem(
            url: urlString,
            fileName: fileName,
            destinationPath: destination.path,
            category: category
        )
        modelContext.insert(item)
        try? modelContext.save()
        downloadManager.startDownload(item: item)
    }
}
