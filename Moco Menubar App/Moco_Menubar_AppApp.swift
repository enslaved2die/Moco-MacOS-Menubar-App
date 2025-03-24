import SwiftUI

@main
struct MocoTrayBooking: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("mocoDomain") private var mocoDomain: String = ""
    @AppStorage("mocoApiKey") private var apiKey: String = ""
    
    var body: some Scene {
        Settings {
            SetupView()
        }
    }
    
}
