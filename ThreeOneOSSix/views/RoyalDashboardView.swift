import SwiftUI
import UIKit

struct RoyalDashboardView: View {
    @EnvironmentObject private var store: PatchProjectStore
    @State private var selectedCategory = "FF NORMAL"
    @State private var showLibrary = false
    @State private var showLaunchMessage = false
    @State private var launchMessage = ""

    private let red = Color(red: 1, green: 0.23, blue: 0.27)
    private let panel = Color(red: 0.065, green: 0.005, blue: 0.012)
    private let outline = Color(red: 0.33, green: 0.075, blue: 0.095)
    private let background = Color(red: 0.035, green: 0, blue: 0.007)
    private let categories: [(String, String)] = [("FF NORMAL", "flame.fill"), ("FF MAX", "flame"), ("AP", "shield.lefthalf.filled")]

    private func font(_ size: CGFloat) -> Font { .custom("Montserrat-Bold", size: size) }

    private func displayName(_ item: PatchLibraryItem) -> String {
        let original = item.project?.name ?? item.packageURL.deletingPathExtension().lastPathComponent
        return original.replacingOccurrences(of: "(?i)[ _-]*(FFTH|FFMAX)$", with: "", options: .regularExpression)
    }

    private var listedFiles: [PatchLibraryItem] {
        var seenIDs = Set<UUID>()
        var seenNames = Set<String>()
        return store.items.filter { item in
            let name = displayName(item).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let raw = (item.project?.name ?? item.packageURL.lastPathComponent).uppercased()
            let category: String = raw.contains("FFMAX") || raw.contains("FF MAX") ? "FF MAX" : raw.contains("AP") ? "AP" : "FF NORMAL"
            guard category == selectedCategory, !seenIDs.contains(item.id), !seenNames.contains(name) else { return false }
            seenIDs.insert(item.id)
            seenNames.insert(name)
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        statusPanel
                        categoryPanel
                        launchPanel
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showLibrary) { PatchProjectsView() }
            .alert("Launch Game", isPresented: $showLaunchMessage) { Button("OK", role: .cancel) {} } message: { Text(launchMessage) }
        }
        .preferredColorScheme(.dark)
    }

    private func heading(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(red)
                .frame(width: 55, height: 55)
                .background(panel, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(outline, lineWidth: 1))
            Text(title).font(font(18)).tracking(2).foregroundStyle(.white)
            Spacer(minLength: 0)
            Circle().fill(red).frame(width: 8, height: 8)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("checkmark.shield.fill", "STATUS")
            HStack {
                VStack(alignment: .leading, spacing: 7) {
                    Text("PATCH PROJECTS").font(font(17)).tracking(2)
                    Text("\(store.items.count) imported projects").font(font(11)).foregroundStyle(.gray)
                }
                Spacer()
                Button { showLibrary = true } label: {
                    Image(systemName: "arrow.up.right").font(.system(size: 18, weight: .bold))
                        .foregroundStyle(red).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Manage Patch Projects")
            }
            .padding(16)
            .background(panel, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(outline, lineWidth: 1))
        }
    }

    private var categoryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("square.grid.2x2.fill", "CATEGORIES")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(categories, id: \.0) { category in
                    let selected = selectedCategory == category.0
                    Button { selectedCategory = category.0 } label: {
                        VStack(spacing: 8) {
                            Image(systemName: category.1).font(.system(size: 19))
                            Text(category.0).font(font(10)).tracking(0.5)
                        }
                        .foregroundStyle(selected ? Color.white : Color.gray)
                        .frame(maxWidth: .infinity).frame(height: 70)
                        .background(selected ? red : Color.black, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? Color.white.opacity(0.5) : outline, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if listedFiles.isEmpty {
                    Text("No projects in this category").font(font(11)).foregroundStyle(.gray).padding(16)
                }
                ForEach(listedFiles) { item in
                    Button { showLibrary = true } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "flame.fill").font(.system(size: 17))
                                .foregroundStyle(red).frame(width: 50, height: 50)
                                .background(panel, in: RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(displayName(item)).font(font(15)).lineLimit(3).foregroundStyle(.white)
                                Text(selectedCategory).font(font(11)).tracking(1).foregroundStyle(.gray)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "circle").font(.system(size: 19)).foregroundStyle(red)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(minHeight: 70)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(outline, lineWidth: 1))
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var launchPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("play.rectangle.fill", "LAUNCH GAME")
            HStack(spacing: 12) {
                launchButton("FF NORMAL", scheme: "freefire://")
                launchButton("FF MAX", scheme: "freefiremax://")
            }
            .padding(16)
            .background(panel, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(outline, lineWidth: 1.2))
        }
    }

    private func launchButton(_ title: String, scheme: String) -> some View {
        Button {
            guard let url = URL(string: scheme) else { return }
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    launchMessage = "The game could not be opened. Its URL scheme may not be supported."
                    showLaunchMessage = true
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                Text(title).font(font(14))
            }
            .foregroundStyle(red)
            .frame(maxWidth: .infinity).frame(height: 58)
            .background(red.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
        }.buttonStyle(.plain)
    }
}
