import SwiftUI

// MARK: - Alarm List View
struct AlarmListView: View {
    @EnvironmentObject private var alarmViewModel: AlarmViewModel
    @StateObject private var alarmKitManager = AlarmKitManager.shared
    // Note: Advanced services will be integrated once they're properly added to the Xcode project
    // @StateObject private var dynamicIslandService = DynamicIslandAlarmService.shared
    // @StateObject private var customizationService = AdvancedAlarmCustomizationService.shared
    // @StateObject private var recommendationsService = SmartAlarmRecommendationsService.shared
    @State private var showingAddAlarm = false
    @State private var showingPermissionView = false
    @State private var selectedAlarm: Alarm?
    @State private var showingDeleteConfirmation = false
    @State private var alarmToDelete: Alarm?
    @State private var showingCustomization = false
    @State private var showingRecommendations = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                backgroundGradient
                
                // Main Content
                VStack(spacing: 0) {
                    // Header Section
                    headerSection
                    
                    // Content Section
                    if alarmViewModel.alarms.isEmpty {
                        emptyStateView
                    } else {
                        alarmListContent
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddAlarm) {
            AlarmFormView { alarm in
                alarmViewModel.addAlarm(alarm)
                showingAddAlarm = false
            }
        }
        .sheet(item: $selectedAlarm) { alarm in
            AlarmFormView(alarm: alarm) { updatedAlarm in
                alarmViewModel.updateAlarm(updatedAlarm)
                selectedAlarm = nil
            }
        }
        .sheet(isPresented: $showingPermissionView) {
            NotificationPermissionView {
                showingPermissionView = false
            }
        }
        // Note: Advanced features will be integrated once services are properly added to Xcode project
        // .sheet(isPresented: $showingCustomization) {
        //     AlarmCustomizationView()
        // }
        // .sheet(isPresented: $showingRecommendations) {
        //     SmartRecommendationsView()
        // }
        // .onAppear {
        //     // Start Dynamic Island activity for active alarms
        //     Task {
        //         await startDynamicIslandForActiveAlarms()
        //     }
        // }
        // .onChange(of: alarmViewModel.alarms) { alarms in
        //     // Update Dynamic Island when alarms change
        //     Task {
        //         await updateDynamicIslandForAlarms(alarms)
        //     }
        // }
        .alert("Delete Alarm", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                alarmToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let alarm = alarmToDelete {
                    alarmViewModel.deleteAlarm(alarm)
                    alarmToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this alarm?")
        }
        .onAppear {
            checkNotificationPermission()
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Alarms")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if let nextAlarm = alarmViewModel.nextAlarm {
                        Text("Next: \(nextAlarm.timeDisplayString)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if alarmViewModel.hasEnabledAlarms {
                        Text("\(alarmViewModel.enabledAlarms.count) active alarm\(alarmViewModel.enabledAlarms.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No active alarms")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Add Alarm Button
                Button(action: { showingAddAlarm = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(showingAddAlarm ? 0.95 : 1.0)
                .animation(.spring(response: 0.3), value: showingAddAlarm)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            // Error Message
            if let errorMessage = alarmViewModel.errorMessage {
                ErrorBannerView(message: errorMessage) {
                    alarmViewModel.errorMessage = nil
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Illustration
            Image(systemName: "alarm.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding(.bottom, 8)
            
            VStack(spacing: 12) {
                Text("No Alarms Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Create your first alarm to start your journey with personalized wake-up experiences.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Create First Alarm Button
            Button(action: { showingAddAlarm = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create First Alarm")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(25)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    // MARK: - Alarm List Content
    private var alarmListContent: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(alarmViewModel.alarms) { alarm in
                    AlarmRowView(
                        alarm: alarm,
                        onToggle: { alarmViewModel.toggleAlarm(alarm) },
                        onEdit: { selectedAlarm = alarm },
                        onDelete: { 
                            alarmToDelete = alarm
                            showingDeleteConfirmation = true
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .slide.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Helper Methods
    private func checkNotificationPermission() {
        Task {
            let status = await alarmKitManager.authorizationState
            if status != .authorized {
                await MainActor.run {
                    showingPermissionView = true
                }
            }
        }
    }
    
    // MARK: - Dynamic Island Integration
    // Note: These methods will be enabled once DynamicIslandAlarmService is properly added to Xcode project
    
    // private func startDynamicIslandForActiveAlarms() async {
    //     let activeAlarms = alarmViewModel.alarms.filter { $0.isEnabled }
    //     
    //     for alarm in activeAlarms {
    //         await dynamicIslandService.startAlarmActivity(for: alarm)
    //     }
    // }
    // 
    // private func updateDynamicIslandForAlarms(_ alarms: [Alarm]) async {
    //     let activeAlarms = alarms.filter { $0.isEnabled }
    //     
    //     // End current Dynamic Island activity
    //     await dynamicIslandService.endAlarmActivity()
    //     
    //     // Start new activity for the next alarm
    //     if let nextAlarm = getNextAlarm(from: activeAlarms) {
    //         await dynamicIslandService.startAlarmActivity(for: nextAlarm)
    //     }
    // }
    // 
    // private func getNextAlarm(from alarms: [Alarm]) -> Alarm? {
    //     let now = Date()
    //     let sortedAlarms = alarms.sorted { $0.time < $1.time }
    //     
    //     return sortedAlarms.first { $0.time > now }
    // }
}

// MARK: - Error Banner View
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.footnote)
                .foregroundColor(.orange)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    AlarmListView()
}
