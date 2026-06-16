import SwiftUI

private func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}

struct ContentView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var status: String = ""
    @State private var isError: Bool = false
    @State private var working: Bool = false
    @State private var installStatus: InstallStatus = .unknown
    @State private var awaitingActivation: Bool = false
    @State private var activationHint: String = ""
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if shouldShowImportBanner { importBanner }
            orgsSection
            actions
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(minWidth: 720, minHeight: 520)
        .safeAreaInset(edge: .bottom) { statusBar }
        .toolbar { ToolbarItem(placement: .primaryAction) { moreMenu } }
        .task { refreshDetection() }
        .sheet(isPresented: $awaitingActivation) { activationSheet }
    }

    // MARK: - Computed

    private var detectedConfigs: [OrgConfig] {
        if case .installed(let c) = installStatus { return c }
        return []
    }

    private var shouldShowImportBanner: Bool {
        let detected = detectedConfigs
        guard !detected.isEmpty else { return false }
        let detectedKey = detected.map { "\($0.organization)|\($0.displayName)" }.sorted()
        let localKey = store.profile.configs.map { "\($0.organization)|\($0.displayName)" }.sorted()
        return detectedKey != localKey
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Edit the organisations and click install — the rest happens automatically.", bundle: .module)
                .foregroundStyle(.secondary)
                .font(.callout)
            Spacer()
            installBadge
        }
    }

    @ViewBuilder
    private var installBadge: some View {
        HStack(spacing: 6) {
            switch installStatus {
            case .unknown:
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.secondary)
                Text("Status unknown", bundle: .module).foregroundStyle(.secondary)
            case .installed(let configs):
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                if configs.isEmpty {
                    Text("Profile installed", bundle: .module)
                } else {
                    Text("Installed · \(configs.count) orgs", bundle: .module)
                }
            case .notInstalled:
                Image(systemName: "xmark.seal").foregroundStyle(.secondary)
                Text("Not installed", bundle: .module).foregroundStyle(.secondary)
            }
            Button {
                refreshDetection()
            } label: { Image(systemName: "arrow.clockwise") }
            .buttonStyle(.plain)
            .help(Text("Refresh detection", bundle: .module))
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    // MARK: - Import banner

    private var importBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill").foregroundStyle(.tint)
            Text("The installed profile contains a different set of organisations than shown above.", bundle: .module)
                .font(.callout)
            Spacer()
            Button {
                store.importDetected()
            } label: {
                Text("Import installed", bundle: .module)
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.1))
        )
    }

    // MARK: - Orgs

    private var orgsSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                columnHeaders
                Divider()
                if store.profile.configs.isEmpty {
                    Text("No organisations yet. Click + to add one.", bundle: .module)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach($store.profile.configs) { $org in
                        orgRow($org)
                    }
                }
                Divider()
                HStack {
                    Button {
                        store.addOrg()
                    } label: {
                        Label {
                            Text("Add organisation", bundle: .module)
                        } icon: {
                            Image(systemName: "plus.circle.fill")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    Spacer()
                    Text("\(store.profile.configs.count) total", bundle: .module)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .padding(8)
        } label: {
            Text("Organisations", bundle: .module).font(.headline)
        }
        .disabled(working || awaitingActivation)
    }

    private var columnHeaders: some View {
        HStack {
            Text("Name", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Team prefix (organization)", bundle: .module)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 28)
        }
    }

    private func orgRow(_ binding: Binding<OrgConfig>) -> some View {
        HStack(spacing: 8) {
            TextField("Acme Corp", text: binding.displayName)
                .textFieldStyle(.roundedBorder)
            TextField("acme-corp", text: binding.organization)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            Button {
                store.remove(id: binding.wrappedValue.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help(Text("Remove this organisation", bundle: .module))
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                prepareInstall()
            } label: {
                Label {
                    primaryButtonLabel
                } icon: {
                    Image(systemName: "square.and.arrow.down.on.square")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("i", modifiers: .command)
            .disabled(working || awaitingActivation || store.profile.configs.isEmpty)
        }
    }

    @ViewBuilder
    private var primaryButtonLabel: some View {
        switch installStatus {
        case .installed:
            Text("Replace & restart WARP", bundle: .module)
        case .notInstalled, .unknown:
            Text("Install & restart WARP", bundle: .module)
        }
    }

    // MARK: - Activation sheet

    private var activationSheet: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 6)
                    .frame(width: 60, height: 60)
                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: 6) {
                Text("Waiting for activation", bundle: .module)
                    .font(.title2).bold()
                if activationHint.isEmpty {
                    Text("Double-click 'Cloudflare WARP' in System Settings → Profiles, click **Install** and enter your password. We'll continue automatically once the profile is active.", bundle: .module)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(activationHint)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button {
                    ProfileInstaller.openProfilesPane()
                } label: {
                    Label {
                        Text("Open Profiles", bundle: .module)
                    } icon: {
                        Image(systemName: "gearshape.2")
                    }
                }
                .controlSize(.large)

                Button {
                    forceComplete()
                } label: {
                    Label {
                        Text("Restart anyway", bundle: .module)
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help(Text("Skip detection and restart WARP now.", bundle: .module))

                Button(role: .cancel) {
                    cancelAwaiting()
                } label: {
                    Text("Cancel", bundle: .module)
                }
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    // MARK: - More menu (toolbar)

    private var moreMenu: some View {
        Menu {
            Button(role: .destructive) {
                revoke()
            } label: {
                Label { Text("Remove current profile", bundle: .module) } icon: { Image(systemName: "trash") }
            }
            Button {
                refreshDetection()
            } label: {
                Label { Text("Refresh detection", bundle: .module) } icon: { Image(systemName: "arrow.clockwise") }
            }
            Button {
                ProfileInstaller.openProfilesPane()
            } label: {
                Label { Text("Open Profiles settings", bundle: .module) } icon: { Image(systemName: "gearshape.2") }
            }
            Button {
                WarpController.launchWarpApp()
            } label: {
                Label { Text("Open Cloudflare WARP", bundle: .module) } icon: { Image(systemName: "arrow.up.right.square") }
            }
        } label: {
            Label { Text("More", bundle: .module) } icon: { Image(systemName: "ellipsis.circle") }
        }
        .disabled(working || awaitingActivation)
    }

    // MARK: - Status bar

    @ViewBuilder
    private var statusBar: some View {
        if !status.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "info.circle")
                    .foregroundStyle(isError ? Color.red : Color.accentColor)
                Text(status).font(.callout)
                Spacer()
                if working { ProgressView().controlSize(.small) }
            }
            .padding(10)
            .background(.thinMaterial)
        }
    }

    // MARK: - Install flow — step 1: prepare + open + start polling

    private func prepareInstall() {
        beginWork(L("Preparing profile…"))
        let snapshot = store.profile
        let initialMtime = ProfileDetector.managedFileModifiedAt()
        let wasInstalled: Bool = {
            if case .installed = installStatus { return true }
            return false
        }()

        Task.detached(priority: .userInitiated) {
            do {
                if wasInstalled {
                    await setStatus(L("Removing existing profile…"))
                    try? ProfileRevoker.revoke()
                }
                await setStatus(L("Opening profile in System Settings…"))
                let data = try ProfileBuilder().build(snapshot)
                _ = try ProfileInstaller.install(data: data, displayName: "Cloudflare WARP")
                try? await Task.sleep(nanoseconds: 600_000_000)
                await MainActor.run { ProfileInstaller.openProfilesPane() }
                await beginAwaitingActivation(initialMtime: initialMtime)
            } catch {
                await finish(error: error.localizedDescription)
            }
        }
    }

    @MainActor
    private func beginAwaitingActivation(initialMtime: Date?) {
        working = false
        isError = false
        awaitingActivation = true
        activationHint = ""
        status = L("Waiting for activation in System Settings…")

        pollTask = Task.detached(priority: .utility) {
            let confirmed = await waitForInstall(initial: initialMtime, timeout: 600)
            if Task.isCancelled { return }
            if confirmed {
                await proceedAfterActivation()
            } else {
                await timeoutAwaiting()
            }
        }
    }

    private func waitForInstall(initial: Date?, timeout: TimeInterval) async -> Bool {
        let start = Date()
        while !Task.isCancelled {
            let now = ProfileDetector.managedFileModifiedAt()
            if let now {
                if initial == nil { return true }
                if let initial, now != initial { return true }
            }
            if Date().timeIntervalSince(start) > timeout { return false }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        return false
    }

    @MainActor
    private func proceedAfterActivation() {
        awaitingActivation = false
        beginWork(L("Activation detected — restarting WARP…"))
        Task.detached(priority: .userInitiated) {
            do {
                try WarpController.restartAndLaunch()
                await finishSuccess(L("Done — profile active, WARP restarted and opened."))
            } catch {
                await finish(error: error.localizedDescription)
            }
        }
    }

    @MainActor
    private func timeoutAwaiting() {
        activationHint = L("No activation detected after 10 minutes. Confirm manually in System Settings and click 'Restart anyway'.")
    }

    // MARK: - Install flow — step 2 (manual override / fallback)

    private func forceComplete() {
        pollTask?.cancel()
        pollTask = nil
        awaitingActivation = false
        beginWork(L("Restarting Cloudflare WARP…"))
        Task.detached(priority: .userInitiated) {
            do {
                try WarpController.restartAndLaunch()
                await finishSuccess(L("Done — WARP restarted and opened."))
            } catch {
                await finish(error: error.localizedDescription)
            }
        }
    }

    private func cancelAwaiting() {
        pollTask?.cancel()
        pollTask = nil
        awaitingActivation = false
        working = false
        status = L("Cancelled. Profile may still be in 'Downloaded' in System Settings.")
        isError = false
    }

    // MARK: - Revoke

    private func revoke() {
        beginWork(L("Removing current WARP profile…"))
        Task.detached(priority: .userInitiated) {
            do {
                try ProfileRevoker.revoke()
                await finishRevoke()
            } catch {
                await finish(error: error.localizedDescription)
            }
        }
    }

    // MARK: - Detection

    private func refreshDetection() {
        Task.detached(priority: .utility) {
            let result = ProfileDetector.detect()
            await applyDetection(result)
        }
    }

    // MARK: - State helpers

    private func beginWork(_ message: String) {
        working = true
        isError = false
        status = message
    }

    @MainActor
    private func setStatus(_ msg: String) {
        status = msg
    }

    @MainActor
    private func applyDetection(_ result: InstallStatus) {
        installStatus = result
    }

    @MainActor
    private func finishSuccess(_ msg: String) {
        status = msg
        isError = false
        working = false
        awaitingActivation = false
        pollTask = nil
        refreshDetection()
    }

    @MainActor
    private func finishRevoke() {
        status = L("Profile removed.")
        isError = false
        working = false
        awaitingActivation = false
        pollTask = nil
        refreshDetection()
    }

    @MainActor
    private func finish(error message: String) {
        status = message
        isError = true
        working = false
        refreshDetection()
    }
}
