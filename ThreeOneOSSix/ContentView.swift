import SwiftUI

// A interface vermelha é a única tela principal do aplicativo.
struct ContentView: View {
    @EnvironmentObject private var patchStore: PatchProjectStore
    @EnvironmentObject private var repositoryStore: PackageRepositoryStore

    var body: some View {
        RoyalDashboardView()
            .preferredColorScheme(.dark)
            .patchStorePresentation(patchStore)
            .repositoryStorePresentation(repositoryStore, patchStore: patchStore)
    }
}
