import SwiftUI

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
            footer
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 540)
        .safeAreaInset(edge: .bottom) { statusBar }
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cloudflare WARP Configurator").font(.title).bold()
                Text("Bewerk de organisaties en klik installeren — de rest gaat vanzelf.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
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
                Text("Status onbekend").foregroundStyle(.secondary)
            case .installed(let configs):
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                if configs.isEmpty {
                    Text("Profiel geïnstalleerd")
                } else {
                    Text("Geïnstalleerd · \(configs.count) org\(configs.count == 1 ? "" : "s")")
                }
            case .notInstalled:
                Image(systemName: "xmark.seal").foregroundStyle(.secondary)
                Text("Niet geïnstalleerd").foregroundStyle(.secondary)
            }
            Button {
                refreshDetection()
            } label: { Image(systemName: "arrow.clockwise") }
            .buttonStyle(.plain)
            .help("Detectie verversen")
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
            Text("Het geïnstalleerde profiel bevat een andere set organisaties dan hierboven.")
                .font(.callout)
            Spacer()
            Button("Importeer geïnstalleerd") {
                store.importDetected()
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
                    Text("Nog geen organisaties. Klik op + om er één toe te voegen.")
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
                        Label("Organisatie toevoegen", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    Spacer()
                    Text("\(store.profile.configs.count) totaal")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .padding(8)
        } label: {
            Text("Organisaties").font(.headline)
        }
        .disabled(working || awaitingActivation)
    }

    private var columnHeaders: some View {
        HStack {
            Text("Naam")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Team-prefix (organization)")
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
            .help("Verwijder deze organisatie")
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                prepareInstall()
            } label: {
                Label(primaryButtonTitle, systemImage: "square.and.arrow.down.on.square")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut("i", modifiers: .command)
            .disabled(working || awaitingActivation || store.profile.configs.isEmpty)
        }
    }

    private var primaryButtonTitle: String {
        switch installStatus {
        case .installed: return "Vervang & herstart WARP"
        case .notInstalled, .unknown: return "Installeer & herstart WARP"
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
                Text("Wachten op activatie")
                    .font(.title2).bold()
                Text(activationHint.isEmpty
                     ? "Dubbelklik op 'Cloudflare WARP' in System Settings → Profielen, klik **Install** en voer je wachtwoord in. We gaan automatisch verder zodra het profiel actief is."
                     : activationHint)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button {
                    ProfileInstaller.openProfilesPane()
                } label: {
                    Label("Open Profielen", systemImage: "gearshape.2")
                }
                .controlSize(.large)

                Button {
                    forceComplete()
                } label: {
                    Label("Toch herstarten", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("Sla detectie over en herstart WARP nu meteen.")

                Button(role: .cancel) {
                    cancelAwaiting()
                } label: {
                    Text("Annuleren")
                }
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 520)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()
            Menu {
                Button(role: .destructive) {
                    revoke()
                } label: { Label("Verwijder huidig profiel", systemImage: "trash") }
                Button {
                    refreshDetection()
                } label: { Label("Detectie verversen", systemImage: "arrow.clockwise") }
                Button {
                    ProfileInstaller.openProfilesPane()
                } label: { Label("Open Profielen-instellingen", systemImage: "gearshape.2") }
                Button {
                    WarpController.launchWarpApp()
                } label: { Label("Open Cloudflare WARP", systemImage: "arrow.up.right.square") }
            } label: {
                Label("Meer", systemImage: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(working || awaitingActivation)
        }
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
        beginWork("Profiel klaarzetten…")
        let snapshot = store.profile
        let initialMtime = ProfileDetector.managedFileModifiedAt()
        let wasInstalled: Bool = {
            if case .installed = installStatus { return true }
            return false
        }()

        Task.detached(priority: .userInitiated) {
            do {
                if wasInstalled {
                    await setStatus("Bestaand profiel verwijderen…")
                    try? ProfileRevoker.revoke()
                }
                await setStatus("Profiel openen in System Settings…")
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
        status = "Wachten op activatie in System Settings…"

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
        beginWork("Activatie gedetecteerd — WARP herstarten…")
        Task.detached(priority: .userInitiated) {
            do {
                try WarpController.restartAndLaunch()
                await finishSuccess("Klaar — profiel actief, WARP herstart en geopend.")
            } catch {
                await finish(error: error.localizedDescription)
            }
        }
    }

    @MainActor
    private func timeoutAwaiting() {
        activationHint = "Geen activatie gedetecteerd na 10 minuten. Bevestig handmatig in System Settings en klik 'Toch herstarten'."
    }

    // MARK: - Install flow — step 2 (manual override / fallback)

    private func forceComplete() {
        pollTask?.cancel()
        pollTask = nil
        awaitingActivation = false
        beginWork("Cloudflare WARP herstarten…")
        Task.detached(priority: .userInitiated) {
            do {
                try WarpController.restartAndLaunch()
                await finishSuccess("Klaar — WARP herstart en geopend.")
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
        status = "Geannuleerd. Profiel staat eventueel nog in 'Downloaded' in System Settings."
        isError = false
    }

    // MARK: - Revoke

    private func revoke() {
        beginWork("Huidig WARP-profiel verwijderen…")
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
        status = "Profiel verwijderd."
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
        awaitingActivation = false
        pollTask = nil
        refreshDetection()
    }
}
