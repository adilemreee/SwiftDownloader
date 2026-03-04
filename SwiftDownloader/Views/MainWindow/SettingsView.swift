import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage(Constants.Keys.maxConcurrentDownloads) private var maxConcurrent = Constants.defaultMaxConcurrentDownloads
    @AppStorage(Constants.Keys.speedLimitMBps) private var speedLimit = Constants.defaultSpeedLimitMBps
    @AppStorage(Constants.Keys.autoCategorizationEnabled) private var autoCategorize = Constants.defaultAutoCategorizationEnabled
    @AppStorage(Constants.Keys.showMenuBarIcon) private var showMenuBar = true
    @AppStorage(Constants.Keys.launchAtLogin) private var launchAtLogin = false
    @AppStorage(Constants.Keys.startMinimized) private var startMinimized = false
    @AppStorage(Constants.Keys.hideFromDock) private var hideFromDock = false
    @AppStorage(Constants.Keys.soundEnabled) private var soundEnabled = true
    @AppStorage(Constants.Keys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(Constants.Keys.autoRetryEnabled) private var autoRetryEnabled = true
    @AppStorage(Constants.Keys.autoRetryCount) private var autoRetryCount = 3
    @AppStorage(Constants.Keys.completionAction) private var completionAction = "none"
    @AppStorage(Constants.Keys.proxyEnabled) private var proxyEnabled = false
    @AppStorage(Constants.Keys.proxyHost) private var proxyHost = ""
    @AppStorage(Constants.Keys.proxyPort) private var proxyPort = ""
    @State private var downloadDirectory: String = FileOrganizer.shared.baseDownloadDirectory.path
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().background(Theme.border)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    downloadLocationSection
                    performanceSection
                    fileOrganizationSection
                    notificationsSection
                    autoRetrySection
                    completionActionSection
                    appBehaviorSection
                    appearanceSection
                    proxySection
                    safariExtensionSection
                    dangerZoneSection
                    Spacer(minLength: 16)
                }
                .padding(24)
            }
        }
        .background(Theme.surfacePrimary)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Sections

    private var downloadLocationSection: some View {
        settingsSection("Download Location", icon: "folder.fill") {
            HStack {
                Text(downloadDirectory)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change") { chooseDirectory() }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.primary)
                    .buttonStyle(.plain)
            }
        }
    }

    private var performanceSection: some View {
        settingsSection("Performance", icon: "gauge.high") {
            VStack(spacing: 16) {
                HStack {
                    Text("Max Concurrent Downloads")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    Picker("", selection: $maxConcurrent) {
                        ForEach(1...10, id: \.self) { i in Text("\(i)").tag(i) }
                    }
                    .frame(width: 80)
                }

                HStack {
                    Text("Speed Limit")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    HStack(spacing: 6) {
                        TextField("0", value: $speedLimit, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("MB/s")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                Text("Set to 0 for unlimited speed")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private var fileOrganizationSection: some View {
        settingsSection("File Organization", icon: "folder.badge.gearshape") {
            settingsToggle(isOn: $autoCategorize, title: "Auto-categorize downloads", subtitle: "Sort files into category folders")
        }
    }

    private var notificationsSection: some View {
        settingsSection("Notifications", icon: "bell.fill") {
            VStack(spacing: 14) {
                settingsToggle(isOn: $notificationsEnabled, title: "Desktop notifications", subtitle: "Show notification when download completes or fails")
                Divider().background(Theme.border)
                settingsToggle(isOn: $soundEnabled, title: "Sound alerts", subtitle: "Play sound when download completes")
            }
        }
    }

    private var autoRetrySection: some View {
        settingsSection("Auto Retry", icon: "arrow.clockwise") {
            VStack(spacing: 14) {
                settingsToggle(isOn: $autoRetryEnabled, title: "Auto-retry failed downloads", subtitle: "Automatically retry when a download fails")

                if autoRetryEnabled {
                    Divider().background(Theme.border)
                    HStack {
                        Text("Max retry attempts")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                        Picker("", selection: $autoRetryCount) {
                            ForEach(1...5, id: \.self) { i in Text("\(i)").tag(i) }
                        }
                        .frame(width: 60)
                    }
                }
            }
        }
    }

    private var completionActionSection: some View {
        settingsSection("After Download Completes", icon: "checkmark.circle.fill") {
            Picker("", selection: $completionAction) {
                Text("Do nothing").tag("none")
                Text("Open file").tag("openFile")
                Text("Show in Finder").tag("openFolder")
            }
            .pickerStyle(.radioGroup)
        }
    }

    private var appBehaviorSection: some View {
        settingsSection("App Behavior", icon: "gearshape.2.fill") {
            VStack(spacing: 14) {
                settingsToggle(isOn: $launchAtLogin, title: "Launch at login", subtitle: "Start when you log in")
                    .onChange(of: launchAtLogin) { _, val in setLaunchAtLogin(val) }
                Divider().background(Theme.border)
                settingsToggle(isOn: $startMinimized, title: "Start minimized", subtitle: "Only show menu bar on launch")
                Divider().background(Theme.border)
                settingsToggle(isOn: $hideFromDock, title: "Hide from Dock", subtitle: "Requires restart")
                    .onChange(of: hideFromDock) { _, val in setHideFromDock(val) }
            }
        }
    }

    private var appearanceSection: some View {
        settingsSection("Appearance", icon: "paintbrush.fill") {
            settingsToggle(isOn: $showMenuBar, title: "Show menu bar icon", subtitle: "Quick access from status bar")
        }
    }

    private var proxySection: some View {
        settingsSection("Proxy", icon: "network") {
            VStack(spacing: 14) {
                settingsToggle(isOn: $proxyEnabled, title: "Use proxy", subtitle: "Route downloads through a proxy server")

                if proxyEnabled {
                    Divider().background(Theme.border)
                    HStack(spacing: 8) {
                        TextField("Host (e.g. 127.0.0.1)", text: $proxyHost)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                        Text(":")
                            .foregroundColor(Theme.textTertiary)
                        TextField("Port", text: $proxyPort)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12))
                            .frame(width: 60)
                    }
                }
            }
        }
    }

    private var safariExtensionSection: some View {
        settingsSection("Safari Extension", icon: "safari.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle().fill(Theme.accent).frame(width: 8, height: 8)
                    Text("Extension Installed")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.accent)
                }
                Text("Safari → Settings → Extensions → SwiftDownloader")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                Button("Open Safari Extension Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Safari.Extensions")!)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.primary)
                .buttonStyle(.plain)
            }
        }
    }

    private var dangerZoneSection: some View {
        settingsSection("Data", icon: "trash.fill") {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clear all downloads")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textPrimary)
                    Text("Remove all download records")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
                Spacer()
                Button("Clear") {
                    NotificationCenter.default.post(name: Notification.Name("clearAllDownloads"), object: nil)
                    dismiss()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Theme.error)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.primary)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private func settingsToggle(isOn: Binding<Bool>, title: String, subtitle: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13)).foregroundColor(Theme.textPrimary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(Theme.textTertiary)
            }
        }
        .toggleStyle(.switch)
        .tint(Theme.primary)
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            downloadDirectory = url.path
            UserDefaults.standard.set(url.path, forKey: Constants.Keys.downloadDirectory)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { print("Launch at login error: \(error)") }
    }

    private func setHideFromDock(_ hidden: Bool) {
        NSApp.setActivationPolicy(hidden ? .accessory : .regular)
    }
}
