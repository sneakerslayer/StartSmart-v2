import SwiftUI

// MARK: - Alarm Detail View
struct AlarmDetailView: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                headerSection
                
                // Details Cards
                detailsSection
                
                // Actions Section
                actionsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.05),
                    Color.purple.opacity(0.02),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
        )
        .navigationTitle("Alarm Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    onEdit()
                }
                .fontWeight(.semibold)
            }
        }
        .alert("Delete Alarm", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this alarm? This action cannot be undone.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Time Display
            Text(alarm.timeDisplayString)
                .font(.system(size: 60, weight: .thin, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Label
            Text(alarm.label)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Status Badge
            HStack(spacing: 8) {
                Image(systemName: alarm.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundColor(alarm.isEnabled ? .green : .orange)
                
                Text(alarm.isEnabled ? "Active" : "Disabled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(alarm.isEnabled ? .green : .orange)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((alarm.isEnabled ? Color.green : Color.orange).opacity(0.1))
            )
            
            // Next Trigger Info
            if let nextTrigger = alarm.nextTriggerDate {
                VStack(spacing: 4) {
                    Text("Next Alarm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatNextTriggerDate(nextTrigger))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .blue.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(spacing: 16) {
            // Repeat Pattern Card
            DetailCard(
                title: "Repeat",
                icon: "repeat",
                content: alarm.repeatDaysDisplayString,
                description: alarm.isRepeating ? "Repeats on selected days" : "One-time alarm"
            )
            
            // Tone Card
            DetailCard(
                title: "Tone",
                icon: "speaker.wave.2",
                content: alarm.tone.displayName,
                description: alarm.tone.description
            )
            
            // Snooze Card
            DetailCard(
                title: "Snooze",
                icon: "moon.zzz",
                content: alarm.snoozeEnabled ? "Enabled" : "Disabled",
                description: alarm.snoozeEnabled 
                    ? "\(Int(alarm.snoozeDuration / 60)) min, max \(alarm.maxSnoozeCount) times"
                    : "Snooze is disabled for this alarm"
            )
            
            // Statistics Card (if alarm has been triggered)
            if alarm.lastTriggered != nil {
                statisticsCard
            }
        }
    }
    
    // MARK: - Statistics Card
    private var statisticsCard: some View {
        DetailCard(
            title: "Statistics",
            icon: "chart.bar",
            content: formatLastTriggered(),
            description: alarm.currentSnoozeCount > 0 
                ? "Snoozed \(alarm.currentSnoozeCount) time\(alarm.currentSnoozeCount == 1 ? "" : "s")"
                : "No snoozes used"
        )
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Toggle Button
            Button(action: onToggle) {
                HStack {
                    Image(systemName: alarm.isEnabled ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                    
                    Text(alarm.isEnabled ? "Disable Alarm" : "Enable Alarm")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: alarm.isEnabled ? [.orange, .red] : [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .buttonStyle(ScaleButtonStyle())
            
            // Secondary Actions
            HStack(spacing: 12) {
                // Edit Button
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                
                // Delete Button
                Button(action: { showingDeleteConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.red.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    private func formatNextTriggerDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
    
    private func formatLastTriggered() -> String {
        guard let lastTriggered = alarm.lastTriggered else {
            return "Never triggered"
        }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastTriggered) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: lastTriggered))"
        } else if calendar.isDateInYesterday(lastTriggered) {
            formatter.dateFormat = "h:mm a"
            return "Yesterday at \(formatter.string(from: lastTriggered))"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: lastTriggered)
        }
    }
}

// MARK: - Detail Card
struct DetailCard: View {
    let title: String
    let icon: String
    let content: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(content)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        AlarmDetailView(
            alarm: {
                var alarm = Alarm(
                    time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!,
                    label: "Morning Workout",
                    repeatDays: [.monday, .wednesday, .friday],
                    tone: .energetic
                )
                alarm.markTriggered()
                return alarm
            }(),
            onEdit: {},
            onDelete: {},
            onToggle: {}
        )
    }
}
