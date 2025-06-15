import SwiftUI

@main
struct lazyvoiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We don't need a window for a menu bar app
        Settings {
            PreferencesView()
        }
    }
} 