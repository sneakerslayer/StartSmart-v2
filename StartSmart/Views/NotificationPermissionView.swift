import SwiftUI

// MARK: - Notification Permission View
struct NotificationPermissionView: View {
    @StateObject private var notificationService = NotificationService()
    @State private var isRequestingPermission = false
    @State private var showingSettings = false
    
    let onPermissionGranted: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            headerSection
            
            // Permission Status
            permissionStatusSection
            
            // Action Button
            actionButtonSection
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            Task {
                await notificationService.getPermissionStatus()
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsNavigationView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "bell.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Title
            Text("Enable Notifications")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            Text("StartSmart needs notification permission to deliver your personalized wake-up alarms reliably.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.top, 40)
    }
    
    // MARK: - Permission Status Section
    private var permissionStatusSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: permissionStatusIcon)
                    .foregroundColor(permissionStatusColor)
                Text(permissionStatusText)
                    .font(.headline)
                    .foregroundColor(permissionStatusColor)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            
            if notificationService.permissionStatus == .denied {
                deniedPermissionHelpText
            }
        }
    }
    
    private var deniedPermissionHelpText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("To enable notifications:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Tap 'Open Settings' below")
                Text("2. Find 'StartSmart' in the app list")
                Text("3. Tap 'Notifications'")
                Text("4. Turn on 'Allow Notifications'")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - Action Button Section
    private var actionButtonSection: some View {
        VStack(spacing: 12) {
            switch notificationService.permissionStatus {
            case .notDetermined:
                requestPermissionButton
            case .denied:
                openSettingsButton
            case .authorized, .provisional:
                continueButton
            }
        }
    }
    
    private var requestPermissionButton: some View {
        Button(action: requestPermission) {
            HStack {
                if isRequestingPermission {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "bell.badge")
                }
                Text(isRequestingPermission ? "Requesting..." : "Allow Notifications")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(25)
        }
        .disabled(isRequestingPermission)
    }
    
    private var openSettingsButton: some View {
        Button(action: openSettings) {
            HStack {
                Image(systemName: "gear")
                Text("Open Settings")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(25)
        }
    }
    
    private var continueButton: some View {
        Button(action: onPermissionGranted) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Continue")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(25)
        }
    }
    
    // MARK: - Computed Properties
    private var permissionStatusIcon: String {
        switch notificationService.permissionStatus {
        case .notDetermined:
            return "questionmark.circle"
        case .denied:
            return "xmark.circle.fill"
        case .authorized, .provisional:
            return "checkmark.circle.fill"
        }
    }
    
    private var permissionStatusColor: Color {
        switch notificationService.permissionStatus {
        case .notDetermined:
            return .orange
        case .denied:
            return .red
        case .authorized, .provisional:
            return .green
        }
    }
    
    private var permissionStatusText: String {
        switch notificationService.permissionStatus {
        case .notDetermined:
            return "Permission not requested"
        case .denied:
            return "Notifications disabled"
        case .authorized:
            return "Notifications enabled"
        case .provisional:
            return "Provisional access granted"
        }
    }
    
    // MARK: - Actions
    private func requestPermission() {
        guard !isRequestingPermission else { return }
        
        isRequestingPermission = true
        
        Task {
            do {
                let status = try await notificationService.requestPermission()
                await MainActor.run {
                    isRequestingPermission = false
                    if status == .authorized {
                        onPermissionGranted()
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                }
            }
        }
    }
    
    private func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// MARK: - Settings Navigation View
struct SettingsNavigationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Open the Settings app to enable notifications for StartSmart")
                    .padding()
                Spacer()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NotificationPermissionView {
        print("Permission granted")
    }
}
