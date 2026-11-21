import SwiftUI
import UIKit

struct RoyalDashboardView: View {
    @EnvironmentObject private var store: PatchProjectStore
    @State private var selectedCategory = "FF NORMAL"
    @State private var workingIDs = Set<UUID>()
    @State private var actionError: String?
    @State private var actionSuccess: String?
    @State private var diagnosticStage: String?
    @State private var diagnosticResult: String?

    private let red = Color(red: 1, green: 0.23, blue: 0.27)
    private let panel = Color(red: 0.065, green: 0.005, blue: 0.012)
    private let outline = Color(red: 0.33, green: 0.075, blue: 0.095)
    private let background = Color(red: 0.035, green: 0, blue: 0.007)
    private let categories: [(String, String)] = [("FF NORMAL", "flame.fill"), ("FF MAX", "flame"), ("AP", "shield.lefthalf.filled")]

    private func font(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }

    private func displayName(_ item: PatchLibraryItem) -> String {
        let original = item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent
        return original
            .replacingOccurrences(of: "PESCOC╠ºO", with: "PESCOÇO")
            .replacingOccurrences(of: "PESCOÇO", with: "PESCOÇO")
            .replacingOccurrences(of: #"(?i)[ _/-]*(FFTH|FFMAX)$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var listedFiles: [PatchLibraryItem] {
        var seen = Set<String>()
        return store.items.filter { item in
            // A categoria original está no nome do arquivo .3105; o nome interno
            // do projeto pode não conter FFMAX após a importação.
            let filename = item.packageURL.deletingPathExtension().lastPathComponent.uppercased()
            let projectName = (item.project?.name ?? "").uppercased()
            let isMax = filename.contains("FFMAX") || filename.contains("FF MAX")
                || projectName.contains("FFMAX") || projectName.contains("FF MAX")
            let isAP = filename.hasPrefix("AP ") || projectName.hasPrefix("AP ")
            let category = isMax ? "FF MAX" : isAP ? "AP" : "FF NORMAL"
            let key = displayName(item).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
            return category == selectedCategory && seen.insert(key).inserted
        }.sorted { displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        statusPanel
                        categoryPanel
                        diagnosticPanel
                        launchPanel
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("Arquivo", isPresented: Binding(
                get: { actionSuccess != nil },
                set: { if !$0 { actionSuccess = nil } }
            )) {
                Button("OK", role: .cancel) { actionSuccess = nil }
            } message: {
                Text(actionSuccess ?? "")
            }
            .patchStorePresentation(store)
            .alert("Arquivo", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK", role: .cancel) { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func heading(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(red)
                .frame(width: 55, height: 55)
                .background(red.opacity(0.12), in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(outline))
            Text(title).font(font(18)).tracking(2).foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Circle().fill(red).frame(width: 8, height: 8)
        }
    }

    private var deviceModelName: String {
        var info = utsname()
        uname(&info)
        let identifier = withUnsafeBytes(of: &info.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
        let models: [String: String] = [
            "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
            "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS", "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max", "iPhone11,8": "iPhone XR",
            "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max", "iPhone12,8": "iPhone SE (2ª geração)",
            "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro", "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone14,2": "iPhone 13 Pro", "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,6": "iPhone SE (3ª geração)",
            "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro", "iPhone15,3": "iPhone 14 Pro Max", "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro", "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro", "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,5": "iPhone 16e",
            "iPhone18,1": "iPhone 17 Pro", "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air"
        ]
        if identifier == "x86_64" || identifier == "arm64" { return "Simulador iOS" }
        return models[identifier] ?? identifier
    }

    private var statusPanel: some View {
        VStack(spacing: 18) {
            HStack {
                Text("STATUS DO DISPOSITIVO").font(font(17)).tracking(2)
                Spacer()
                Circle().fill(red).frame(width: 9, height: 9)
            }
            statusRow("iphone.gen3", "Modelo", deviceModelName, red)
            statusRow("checkmark.seal.fill", "Suporte", "SUPORTADO", .green)
            statusRow("lock.shield.fill", "Version", "iOS \(UIDevice.current.systemVersion)", .green)
        }
        .padding(20)
        .background(panel, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
    }

    private func statusRow(_ symbol: String, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 15) {
            Image(systemName: symbol).font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint).frame(width: 53, height: 53)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(tint.opacity(0.35)))
            Text(label).foregroundStyle(.gray)
            Spacer(minLength: 4)
            Text(value).font(font(15)).foregroundStyle(value == "SUPORTADO" ? Color.green : Color.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            heading("bolt.fill", "CATEGORIAS ONLINE")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(categories, id: \.0) { item in
                    let selected = selectedCategory == item.0
                    Button { selectedCategory = item.0 } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.1).font(.system(size: 19, weight: .bold))
                            Text(item.0).font(font(10)).tracking(0.5)
                                .lineLimit(1).minimumScaleFactor(0.65)
                        }
                        .foregroundStyle(selected ? .white : .gray)
                        .frame(maxWidth: .infinity).frame(height: 70)
                        .background(selected ? red : .black, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .stroke(selected ? Color.white.opacity(0.5) : outline, lineWidth: 1.3))
                    }.buttonStyle(.plain)
                }
            }
            if selectedCategory == "AP" {
                Text("Nenhum arquivo AP disponível.").font(font(12))
                    .foregroundStyle(.gray).frame(maxWidth: .infinity).padding(.vertical, 20)
            } else if listedFiles.isEmpty {
                Text("Nenhum arquivo .3106 disponível para \(selectedCategory).")
                    .font(font(12)).foregroundStyle(.gray)
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(listedFiles) { item in
                        Button { toggleFile(item) } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 17, weight: .bold)).foregroundStyle(red)
                                    .frame(width: 50, height: 50)
                                    .background(Color(red: 0.13, green: 0.015, blue: 0.025),
                                                in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(outline))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(displayName(item)).font(font(15)).foregroundStyle(.white)
                                        .lineLimit(3).multilineTextAlignment(.leading)
                                    Text(selectedCategory).font(font(11)).tracking(1).foregroundStyle(red)
                                }
                                Spacer(minLength: 4)
                                if workingIDs.contains(item.id) {
                                    ProgressView().tint(red)
                                } else {
                                    Image(systemName: isFileActive(item) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isFileActive(item) ? red : .gray.opacity(0.6))
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 70)
                            .background(.black, in: RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(outline.opacity(0.75)))
                        }.buttonStyle(.plain)
                        .disabled(workingIDs.contains(item.id))
                    }
                }
            }
        }
        .padding(16)
        .background(panel, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
    }

    @ViewBuilder
    private var diagnosticPanel: some View {
        if let stage = diagnosticStage {
            HStack(spacing: 10) {
                ProgressView().tint(red)
                Text(stage).font(font(12)).foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(outline))
        } else if let result = diagnosticResult {
            VStack(alignment: .leading, spacing: 6) {
                Text("DIAGNÓSTICO DA ÚLTIMA OPERAÇÃO").font(font(12)).foregroundStyle(red)
                Text(result).font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                Button("Copiar diagnóstico") { UIPasteboard.general.string = result }
                    .font(font(12)).foregroundStyle(red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(outline))
        }
    }

    private func isFileActive(_ item: PatchLibraryItem) -> Bool {
        DevicePatchService.latestReceipt(projectID: item.id) != nil
    }

    private func toggleFile(_ item: PatchLibraryItem) {
        guard !workingIDs.contains(item.id) else { return }
        if item.isLocked {
            store.requestUnlock(for: item)
            return
        }
        workingIDs.insert(item.id)
        diagnosticResult = nil
        diagnosticStage = "Preparando operação…"
        let activeReceipt = DevicePatchService.latestReceipt(projectID: item.id)
        Task.detached(priority: .userInitiated) {
            let started = ProcessInfo.processInfo.systemUptime
            var stages: [String] = []
            func report(_ stage: String) {
                let elapsed = ProcessInfo.processInfo.systemUptime - started
                stages.append(String(format: "%.2f s — %@", elapsed, stage))
                NSLog("[Injetor] %@ em %.3f s (%@)", stage, elapsed, item.id.uuidString)
                Task { @MainActor in diagnosticStage = stage }
            }
            do {
                if let receipt = activeReceipt {
                    report("Iniciando restauração")
                    try DevicePatchService.restore(receipt: receipt, allowChangedTargets: false)
                    report("Restauração concluída")
                } else {
                    guard let baseProject = item.project else {
                        throw NSError(domain: "Injetor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Arquivo indisponível."])
                    }
                    // Pacotes importados sem workspace editado podem ser aplicados
                    // diretamente. Evita criar e copiar todos os arquivos para um
                    // workspace apenas para ativar o pacote pela primeira vez.
                    let hasWorkspace: Bool
                    if item.summary.schemaVersion >= 2 && item.canInspectContents,
                       let patchesRoot = try? PatchWorkspaceService.patchesRootURL() {
                        hasWorkspace = PatchWorkspaceService.workspaceURL(
                            projectID: baseProject.id,
                            patchesRoot: patchesRoot,
                            fileManager: .default
                        ) != nil
                    } else {
                        hasWorkspace = false
                    }
                    // Reutiliza o projeto importado diretamente quando não existe
                    // workspace editado; sincronização só ocorre se necessária.
                    report(hasWorkspace ? "Sincronizando workspace editado" : "Aplicação direta do pacote")
                    let project = hasWorkspace
                        ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                        : baseProject
                    report("Iniciando escrita dos arquivos")
                    _ = try DevicePatchService.apply(project: project)
                    report("Aplicação concluída")
                }
                await MainActor.run {
                    workingIDs.remove(item.id)
                    diagnosticStage = nil
                    diagnosticResult = stages.joined(separator: "\n")
                    store.reload()
                    actionSuccess = activeReceipt == nil
                        ? "Arquivo aplicado com sucesso!"
                        : "Aplicação desfeita com sucesso!"
                }
            } catch {
                report("Operação falhou: \(error.localizedDescription)")
                await MainActor.run {
                    workingIDs.remove(item.id)
                    diagnosticStage = nil
                    diagnosticResult = stages.joined(separator: "\n")
                    actionError = error.localizedDescription
                }
            }
        }
    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("arrow.up.right.square.fill", "LAUNCH GAME")
            HStack(spacing: 12) {
                launchButton("FF NORMAL", scheme: "freefire://")
                launchButton("FF MAX", scheme: "freefiremax://")
            }
        }
        .padding(16)
        .background(panel, in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
    }

    private func launchButton(_ title: String, scheme: String) -> some View {
        Button {
            guard let url = URL(string: scheme) else { return }
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } label: {
            Label(title, systemImage: "play.fill")
                .font(font(14)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(red.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(outline, lineWidth: 1.3))
        }.buttonStyle(.plain)
    }
}
