import SwiftUI

struct SettingsView: View {
    @State private var showPaywall = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Legal Section
                Section("Legal") {
                    Link("Privacy Policy", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                    Link("Terms of Service", destination: URL(string: "https://www.startsmartmobile.com/support")!)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}