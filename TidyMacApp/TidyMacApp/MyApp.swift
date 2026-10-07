import SwiftUI

@main
struct TidyMacApp: App {
    @State private var isAboutPresented = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $isAboutPresented) {
                    AboutView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Tidy…") {
                    isAboutPresented = true
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 900)
        .windowResizability(.contentMinSize)
    }
}
