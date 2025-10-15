import SwiftUI

// MARK: - AlarmKit Migration UI Component

/// Migration banner to inform users about new AlarmKit features
struct AlarmKitMigrationBanner: View {
    @State private var isExpanded = false
    @State private var hasDismissed = false
    @AppStorage("alarmkit_migration_dismissed") private var migrationDismissed = false
    
    var body: some View {
        if !migrationDismissed && !hasDismissed {
            VStack(spacing: 0) {
                // Main banner
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text("New: iOS 26 AlarmKit Integration")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Enhanced alarm reliability with lock screen support")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Expand/Collapse button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                    
                    // Dismiss button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasDismissed = true
                            migrationDismissed = true
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
                
                // Expanded content
                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            FeatureRow(
                                icon: "lock.screen",
                                title: "Lock Screen Alarms",
                                description: "Alarms now play directly from your lock screen"
                            )
                            
                            FeatureRow(
                                icon: "siri",
                                title: "Siri Integration",
                                description: "Control alarms with voice commands"
                            )
                            
                            FeatureRow(
                                icon: "island",
                                title: "Dynamic Island",
                                description: "Alarm status in Dynamic Island on supported devices"
                            )
                            
                            FeatureRow(
                                icon: "bell.slash",
                                title: "Silent Mode Bypass",
                                description: "Alarms play even when your phone is on silent"
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - AlarmKit Status Indicator

/// Status indicator showing AlarmKit integration status
struct AlarmKitStatusIndicator: View {
    @StateObject private var alarmKitManager = AlarmKitManager.shared
    @State private var isAuthorized = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            Image(systemName: isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isAuthorized ? .green : .orange)
            
            // Status text
            Text(isAuthorized ? "AlarmKit Active" : "AlarmKit Pending")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .onAppear {
            checkAuthorizationStatus()
        }
    }
    
    private func checkAuthorizationStatus() {
        Task {
            do {
                let status = try await alarmKitManager.requestAuthorization()
                await MainActor.run {
                    isAuthorized = status == .authorized
                }
            } catch {
                await MainActor.run {
                    isAuthorized = false
                }
            }
        }
    }
}

// MARK: - Migration Progress View

/// Shows migration progress for users upgrading to AlarmKit
struct AlarmKitMigrationProgress: View {
    @StateObject private var alarmKitManager = AlarmKitManager.shared
    @State private var migrationProgress: Double = 0.0
    @State private var isMigrating = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Progress header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                
                Text("Migrating to AlarmKit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Progress bar
            ProgressView(value: migrationProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            // Status text
            Text(migrationStatusText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Start migration button
            if !isMigrating && migrationProgress == 0.0 {
                Button {
                    startMigration()
                } label: {
                    Text("Start Migration")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var migrationStatusText: String {
        if isMigrating {
            return "Migrating your alarms to the new system..."
        } else if migrationProgress == 1.0 {
            return "Migration completed successfully!"
        } else {
            return "Ready to migrate your alarms to AlarmKit"
        }
    }
    
    private func startMigration() {
        isMigrating = true
        
        Task {
            // Simulate migration progress
            for i in 1...10 {
                await MainActor.run {
                    migrationProgress = Double(i) / 10.0
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            await MainActor.run {
                isMigrating = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        AlarmKitMigrationBanner()
        AlarmKitStatusIndicator()
        AlarmKitMigrationProgress()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
