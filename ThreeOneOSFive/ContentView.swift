import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore
    @AppStorage(FeatureVisibility.developerModeStorageKey)
    private var developerModeEnabled = false
    @State private var tabNavigation: AppTabNavigationState
    @State private var showSettings = false
    @State private var showLogs = false

    init() {
#if targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        let initialTab: Int
        if arguments.contains("--simulate-new-tab") {
            initialTab = 1
        } else if arguments.contains("--simulate-sources-tab") {
            initialTab = 2
        } else if arguments.contains("--simulate-installed-tab")
                    || arguments.contains("--simulate-patch-tab")
                    || arguments.contains("--simulate-wallpaper-tab") {
            initialTab = 3
        } else if arguments.contains("--simulate-files-tab") {
            initialTab = 4
        } else if arguments.contains("--simulate-search-tab") {
            initialTab = 5
        } else {
            initialTab = AppSection.installed.rawValue
        }
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
        _showSettings = State(
            initialValue: arguments.contains("--simulate-settings")
        )
#else
        _tabNavigation = State(initialValue: AppTabNavigationState())
#endif
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .tint(AppTheme.accent)
        .imageScale(.small)
        .onChange(of: developerModeEnabled) { _ in
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .onAppear {
            tabNavigation.reconcileSelection(with: featureVisibility)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showLogs) { LogView() }
        .patchStorePresentation(patchStore)
        .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }

    private var compactLayout: some View {
        RoyalDashboardView()
    }

    private var regularLayout: some View {
        RoyalDashboardView()
    }

    @ViewBuilder
    private func sectionContent(_ section: AppSection) -> some View {
        switch section {
        case .home:
            RepositoryHomeView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .new:
            RepositoryNewView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .sources:
            RepositorySourcesView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .installed:
            PatchProjectsView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .files:
            AppDataBrowserView(
                tabSession: filesTabSession,
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        case .search:
            RepositorySearchView(
                onOpenSettings: openSettings,
                onOpenLogs: openLogs
            )
        }
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabNavigation.selectedTab },
            set: { tabNavigation.select($0) }
        )
    }

    private var filesTabSession: Binding<FilesTabSession> {
        Binding(
            get: { tabNavigation.filesTabs },
            set: { tabNavigation.setFilesTabs($0) }
        )
    }

    private var featureVisibility: FeatureVisibility {
        FeatureVisibility(developerModeEnabled: developerModeActive)
    }

    private var developerModeActive: Bool {
#if targetEnvironment(simulator)
        developerModeEnabled
            || ProcessInfo.processInfo.arguments.contains("--simulate-developer-mode")
            || ProcessInfo.processInfo.arguments.contains("--simulate-files-tab")
#else
        developerModeEnabled
#endif
    }

    private var selectedVisibleSection: AppSection {
        let selected = AppSection(rawValue: tabNavigation.selectedTab)
        return selected.flatMap {
            featureVisibility.isVisible($0) ? $0 : nil
        } ?? .installed
    }

    private func openSettings() {
        showSettings = true
    }

    private func openLogs() {
        showLogs = true
    }
}

private struct CompactTabLabel: View {
    let title: String
    let systemImage: String

    @ViewBuilder
    var body: some View {
        if let image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        )?.withRenderingMode(.alwaysTemplate) {
            Image(uiImage: image)
        } else {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
        }
        Text(title)
    }
}

private extension AppSection {
    var titleKey: String {
        switch self {
        case .home: return "tab.home"
        case .new: return "tab.new"
        case .sources: return "tab.sources"
        case .installed: return "tab.installed"
        case .files: return "tab.files"
        case .search: return "tab.search"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house.fill"
        case .new: return "clock.fill"
        case .sources: return "shippingbox.fill"
        case .installed: return "tray.full.fill"
        case .files: return "folder.fill"
        case .search: return "magnifyingglass"
        }
    }
}


// Custom dashboard presentation. Existing Installed functionality remains available.
private struct RoyalDashboardView: View {
    @EnvironmentObject private var patchStore: PatchProjectStore
    @State private var selectedCategory = "FF NORMAL"

    @State private var matchingAssetFiles: [URL] = []
    @State private var bundledHSFiles: [URL] = []
    private func cleanPatchName(_ name: String) -> String {
        let normalized = name
            .replacingOccurrences(of: "PESCOC╠ºO", with: "PESCOÇO")
            .replacingOccurrences(of: "PESCOÇO", with: "PESCOÇO")
            .precomposedStringWithCanonicalMapping
        return normalized
            .replacingOccurrences(
                of: #"(?i)(?:\s*[-–—_/]\s*|\s+)(?:FFTH|FFMAX)\s*[-–—_]*\s*$"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct ListedFile: Identifiable {
        let id: String
        let name: String
    }
    private var listedFiles: [ListedFile] {
        let assetId = selectedCategory == "FF MAX"
            ? "YJ~2FW7EkU5pRkVg51NrKyx4LXid8~3D"
            : "U6Zffc4YIR3DslNj3cXvYGAqz58~3D"
        // Show .3105 packages, not arbitrary asset files. Classify installed
        // projects by their declared target directory rather than package name.
        // Bundled .3105 files live at the root of BundledPatches, not in
        // Documents/assetindexer.*. Display them immediately in both game tabs.
        // Packages explicitly named FFMAX belong to FF MAX; the others to FF NORMAL.
        let categoryPackages = bundledHSFiles.filter { url in
            let isMax = url.deletingPathExtension().lastPathComponent
                .localizedCaseInsensitiveContains("FFMAX")
            switch selectedCategory {
            case "FF MAX": return isMax
            case "FF NORMAL": return !isMax
            case "HS VIPS": return false
            default: return false
            }
        }
        // The bundled file is the canonical row. A previously imported copy
        // must not create a second row with a different display name.
        let bundledPackageIDs = Set(bundledHSFiles.compactMap { url -> UUID? in
            guard let data = try? PatchProjectLibrary.readPackage(at: url),
                  let summary = try? PatchPackageCodec.inspect(data) else { return nil }
            return summary.packageID
        })
        let documents = (categoryPackages + matchingAssetFiles).map { url -> ListedFile in
            if let data = try? PatchProjectLibrary.readPackage(at: url),
               let summary = try? PatchPackageCodec.inspect(data),
               let existing = patchStore.items.first(where: { $0.id == summary.packageID && $0.project != nil }) {
                return ListedFile(id: "project-\(existing.id)", name: cleanPatchName(url.deletingPathExtension().lastPathComponent))
            }
            return ListedFile(id: url.path, name: cleanPatchName(url.deletingPathExtension().lastPathComponent))
        }
        let installed = patchStore.items.compactMap { item -> ListedFile? in
            guard let project = item.project, item.canInspectContents,
                  !bundledPackageIDs.contains(item.id) else { return nil }
            let paths = project.rules.map(\.relativePath) + project.directories.map(\.relativePath)
            guard paths.contains(where: { path in
                path.split(separator: "/").contains(where: { component in
                    String(component).lowercased() == "assetindexer.\(assetId.lowercased())"
                })
            }) else { return nil }
            return ListedFile(id: "project-\(item.id)", name: cleanPatchName(project.name))
        }
        // De-duplicate by stable project ID, then by normalized visible name.
        // Keep the bundled copy first to preserve its friendly display name.
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        return (documents + installed).filter { file in
            let nameKey = file.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            return seenIDs.insert(file.id).inserted && seenNames.insert(nameKey).inserted
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    // The checked state is derived from a real, restorable transaction,
    // rather than from an in-memory selection that survives failed restores.
    @State private var selectedAssetPath: String? = nil
    @State private var activationBusy = false
    @State private var pendingActivationPackageID: UUID? = nil
    @State private var bundledImportQueue: [URL] = []
    @State private var bundledImportInProgress = false
    @State private var bundledImportPrepared = false
    @State private var activationMessage: String? = nil
    @State private var showActivationMessage = false
    @State private var showSupport = false
    private let red = Color(red: 1, green: 0.23, blue: 0.27)
    private let panel = Color(red: 0.065, green: 0.005, blue: 0.012)
    private let outline = Color(red: 0.33, green: 0.075, blue: 0.095)
    private let categories: [(String, String)] = [
        ("FF NORMAL", "flame.fill"), ("FF MAX", "flame"),
        ("AP", "shield.lefthalf.filled")
    ]

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0, blue: 0.007).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    statusPanel
                    categoryPanel
                    launchPanel
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { hsVipsBottomButton }
        .preferredColorScheme(.dark)
        .onAppear { prepareBundledImports() }
        .onChange(of: patchStore.isBusy) { busy in
            if !busy && bundledImportInProgress {
                bundledImportInProgress = false
                patchStore.reload()
                importNextBundledPackage()
                return
            }
            // The store loads asynchronously on launch. Resume the bundled
            // import queue when that initial load (or another task) completes.
            if !busy && !bundledImportQueue.isEmpty {
                importNextBundledPackage()
                return
            }
            guard !busy, let packageID = pendingActivationPackageID else { return }
            pendingActivationPackageID = nil
            patchStore.reload()
            guard let imported = patchStore.items.first(where: { $0.id == packageID && $0.project != nil }) else {
                activationBusy = false
                activationMessage = "Não foi possível importar este arquivo .3105. Confira o erro apresentado pela biblioteca de patches."
                showActivationMessage = true
                return
            }
            activateListedFile(ListedFile(id: "project-\(imported.id)", name: imported.project?.name ?? "Patch"))
        }
        .alert("Ativação do arquivo", isPresented: $showActivationMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(activationMessage ?? "Não foi possível concluir a operação.")
        }
        .alert("Suporte", isPresented: $showSupport) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("As informações de suporte não estão configuradas neste projeto.")
        }
    }

    private var hsVipsBottomButton: some View {
        VStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .bold))
            Text("HS VIPS")
                .font(.custom("Montserrat-Bold", size: 10))
                .tracking(0.6)
        }
        .foregroundStyle(Color(red: 1.0, green: 0.32, blue: 0.37))
        .frame(width: 98, height: 57)
        .background(Color(red: 0.23, green: 0.19, blue: 0.20),
                    in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .stroke(Color(red: 0.35, green: 0.27, blue: 0.29), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .frame(maxWidth: .infinity)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .background(Color.clear)
        .accessibilityLabel("HS VIPS")
    }

    private var iphoneModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = systemInfo.machine
        let identifier = withUnsafeBytes(of: machine) { bytes in
            let chars = bytes.bindMemory(to: CChar.self)
            return String(cString: chars.baseAddress!)
        }
        let models: [String: String] = [
            "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max", "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE (2ª geração)",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,6": "iPhone SE (3ª geração)", "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
            "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air",
            "i386": "iPhone (simulador)", "x86_64": "iPhone (simulador)", "arm64": "iPhone (simulador)"
        ]
        return models[identifier] ?? identifier
    }

    private var dispositivoSuportado: Bool {
        let version = AppInfo.versionTuple
        return ExploitSupportPolicy.isSupported(
            major: version.major,
            minor: version.minor,
            patch: version.patch,
            build: AppInfo.osBuild
        )
    }

    private var statusPanel: some View {
        VStack(spacing: 18) {
            HStack {
                Text("STATUS DO DISPOSITIVO").font(.custom("Montserrat-Bold", size: 17)).tracking(2)
                Spacer()
                Circle().fill(red).frame(width: 9, height: 9)
            }
            statusRow("iphone.gen3", "Device", iphoneModelName, red)
            Button { showSupport = true } label: {
                statusRow("checkmark.seal.fill", "Suporte", dispositivoSuportado ? "SUPORTADO" : "NÃO SUPORTADO", dispositivoSuportado ? .green : .red)
            }.buttonStyle(.plain)
            statusRow("lock.shield.fill", "Version", "iOS \(UIDevice.current.systemVersion)", .green)
        }
        .padding(20)
        .background(panel, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
    }

    private func statusRow(_ symbol: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 53, height: 53)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(tint.opacity(0.35)))
            Text(label).foregroundStyle(.gray)
            Spacer(minLength: 4)
            Text(value).font(.custom("Montserrat-Bold", size: 15))
                .foregroundStyle(label == "Suporte" ? tint : .white).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("bolt.fill", "CATEGORIAS ONLINE")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(categories, id: \.0) { item in
                    Button { selectedCategory = item.0; if item.0 == "FF NORMAL" || item.0 == "FF MAX" { refreshAssetFiles() } } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.1).font(.system(size: 19, weight: .bold))
                            Text(item.0).font(.custom("Montserrat-Bold", size: 10))
                                .tracking(0.5).lineLimit(1).minimumScaleFactor(0.65)
                        }
                        .foregroundStyle(selectedCategory == item.0 ? .white : .gray)
                        .frame(maxWidth: .infinity).frame(height: 70)
                        .background(selectedCategory == item.0 ? red : .black, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedCategory == item.0 ? Color.white.opacity(0.5) : outline, lineWidth: 1.3))
                    }.buttonStyle(.plain)
                }
            }
            if selectedCategory == "FF NORMAL" || selectedCategory == "FF MAX" {
                if listedFiles.isEmpty {
                    Text("Nenhum arquivo .3105 disponível para \(selectedCategory).")
                        .foregroundStyle(.gray).font(.system(size: 13))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity).padding(.vertical, 36)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(listedFiles) { file in
                            Button {
                                activateListedFile(file)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(red)
                                        .frame(width: 50, height: 50)
                                        .background(Color(red: 0.13, green: 0.015, blue: 0.025), in: RoundedRectangle(cornerRadius: 11))
                                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(outline, lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(file.name)
                                            .font(.custom("Montserrat-Bold", size: 15))
                                            .foregroundStyle(.white)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(selectedCategory)
                                            .font(.custom("Montserrat-Bold", size: 11))
                                            .tracking(1)
                                            .foregroundStyle(red)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: isListedFileActive(file) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 19, weight: .medium))
                                        .foregroundStyle(isListedFileActive(file) ? red : Color.gray.opacity(0.6))
                                        .fixedSize()
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: 70, alignment: .center)
                                .background(Color.black, in: RoundedRectangle(cornerRadius: 24))
                                .overlay(RoundedRectangle(cornerRadius: 24).stroke(outline.opacity(0.75), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(activationBusy)
                        }
                    }
                }
            } else {
                Text("Nenhum patch nesta categoria.")
                    .foregroundStyle(.gray).font(.system(size: 15))
                    .frame(maxWidth: .infinity).padding(.vertical, 36)
            }

        }
        .padding(20)
        .background(panel, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
        .onAppear { refreshAssetFiles() }
    }

    // Load the HS VIPS files shipped inside the app into the patch library.
    // They are imported only when not already present; activation remains a
    // separate user action and only reports success after a real apply.
    private func prepareBundledImports() {
        guard !bundledImportPrepared else { return }
        guard let root = Bundle.main.resourceURL?.appendingPathComponent("BundledPatches", isDirectory: true),
              let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        bundledImportPrepared = true
        // Display bundled files immediately, even if their import or validation fails.
        bundledHSFiles = urls.filter { $0.pathExtension.lowercased() == "3105" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        bundledImportQueue = urls.filter { url in
            guard url.pathExtension.lowercased() == "3105",
                  let data = try? PatchProjectLibrary.readPackage(at: url),
                  let summary = try? PatchPackageCodec.inspect(data) else { return false }
            return !patchStore.items.contains(where: { $0.id == summary.packageID })
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        importNextBundledPackage()
    }

    private func importNextBundledPackage() {
        guard !patchStore.isBusy, !bundledImportInProgress else { return }
        while !bundledImportQueue.isEmpty {
            let url = bundledImportQueue.removeFirst()
            guard let data = try? PatchProjectLibrary.readPackage(at: url),
                  let summary = try? PatchPackageCodec.inspect(data),
                  !patchStore.items.contains(where: { $0.id == summary.packageID }) else { continue }
            bundledImportInProgress = true
            patchStore.importPackage(at: url)
            return
        }
    }

    private func packageID(for file: ListedFile) -> UUID? {
        if file.id.hasPrefix("project-") {
            return UUID(uuidString: String(file.id.dropFirst("project-".count)))
        }
        guard let data = try? PatchProjectLibrary.readPackage(at: URL(fileURLWithPath: file.id)),
              let summary = try? PatchPackageCodec.inspect(data) else { return nil }
        return summary.packageID
    }

    private func isListedFileActive(_ file: ListedFile) -> Bool {
        guard let id = packageID(for: file) else { return false }
        return DevicePatchService.latestReceipt(projectID: id) != nil
    }

    private func deactivateListedFile(_ file: ListedFile, receipt: PatchTransactionReceipt) {
        activationBusy = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    selectedAssetPath = nil
                    activationBusy = false
                    patchStore.reload()
                    activationMessage = "Arquivo desativado e alterações restauradas."
                    showActivationMessage = true
                }
            } catch {
                await MainActor.run {
                    activationBusy = false
                    activationMessage = "Não foi possível desativar o arquivo: \(error.localizedDescription). O arquivo permanece marcado como ativo enquanto a restauração não for concluída."
                    showActivationMessage = true
                }
            }
        }
    }

    private func activateListedFile(_ file: ListedFile) {
        guard !activationBusy else { return }
        if let id = packageID(for: file),
           let receipt = DevicePatchService.latestReceipt(projectID: id) {
            deactivateListedFile(file, receipt: receipt)
            return
        }
        // Import bundled and document packages through the same validated library
        // pipeline used by the regular file importer. Never treat an unvalidated
        // resource as an executable patch.
        if !file.id.hasPrefix("project-") {
            let sourceURL = URL(fileURLWithPath: file.id)
            guard sourceURL.pathExtension.lowercased() == "3105",
                  FileManager.default.fileExists(atPath: sourceURL.path) else {
                activationMessage = "Arquivo .3105 não encontrado."
                showActivationMessage = true
                return
            }
            guard !patchStore.isBusy else {
                activationMessage = "Aguarde a conclusão da operação anterior."
                showActivationMessage = true
                return
            }
            do {
                let packageData = try PatchProjectLibrary.readPackage(at: sourceURL)
                let summary = try PatchPackageCodec.inspect(packageData)
                pendingActivationPackageID = summary.packageID
                activationBusy = true
                patchStore.importPackage(at: sourceURL)
            } catch {
                activationMessage = "Arquivo inválido ou não suportado: \(error.localizedDescription)"
                showActivationMessage = true
            }
            return
        }
        guard let item = patchStore.items.first(where: { "project-\($0.id)" == file.id }),
              let baseProject = item.project else {
            activationMessage = "O patch ainda não está disponível na biblioteca."
            showActivationMessage = true
            return
        }
        activationBusy = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2 && item.canInspectContents
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    selectedAssetPath = file.id
                    activationBusy = false
                    patchStore.reload()
                    activationMessage = "Patch aplicado com sucesso."
                    showActivationMessage = true
                }
            } catch {
                await MainActor.run {
                    activationBusy = false
                    activationMessage = "Não foi possível aplicar o patch: \(error.localizedDescription)"
                    showActivationMessage = true
                }
            }
        }
    }

    // Match parent directory components, never the filename. Limited to app-accessible Documents.
    private func refreshAssetFiles() {
        let assetId = selectedCategory == "FF MAX"
            ? "YJ~2FW7EkU5pRkVg51NrKyx4LXid8~3D"
            : "U6Zffc4YIR3DslNj3cXvYGAqz58~3D"
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let enumerator = FileManager.default.enumerator(at: documents,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]) else {
            matchingAssetFiles = []
            return
        }
        var found: [URL] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "3105",
                  url.deletingLastPathComponent().pathComponents.contains(where: { component in
                      let name = component.lowercased()
                      return name == "assetindexer.\(assetId.lowercased())"
                  }),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            found.append(url)
            if found.count >= 200 { break }
        }
        matchingAssetFiles = Array(Set(found)).sorted { $0.lastPathComponent < $1.lastPathComponent }

    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("arrow.up.right.square.fill", "LAUNCH GAME")
            HStack(spacing: 12) {
                launchButton("FF NORMAL")
                launchButton("FF MAX")
            }
        }
        .padding(16)
        .background(panel, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
    }

    private func launchButton(_ title: String) -> some View {
        Button { openFreeFire(title) } label: {
            Label(title, systemImage: "play.fill")
                .font(.custom("Montserrat-Bold", size: 14))
                .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: 58)
                .background(red.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(outline, lineWidth: 1.3))
        }.buttonStyle(.plain)
    }

    private func openFreeFire(_ title: String) {
        // Attempt direct launch without an in-app confirmation or error alert.
        // iOS may still display system-controlled prompts.
        let scheme = title == "FF MAX" ? "freefiremax://" : "freefire://"
        guard let url = URL(string: scheme) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func heading(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 17, weight: .bold))
                .foregroundStyle(red).frame(width: 55, height: 55)
                .background(red.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(outline))
            Text(title).font(.custom("Montserrat-Bold", size: 18))
                .tracking(2).foregroundStyle(.white).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Circle().fill(red).frame(width: 8, height: 8)
        }
    }
}
