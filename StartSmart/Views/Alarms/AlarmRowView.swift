import SwiftUI

// MARK: - Alarm Row View
struct AlarmRowView: View {
    let alarm: Alarm
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isToggling = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Time Display
            timeSection
            
            // Alarm Details
            detailsSection
            
            Spacer()
            
            // Toggle Switch
            toggleSection
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(
                    color: alarm.isEnabled ? .black.opacity(0.1) : .gray.opacity(0.05),
                    radius: alarm.isEnabled ? 8 : 4,
                    x: 0,
                    y: alarm.isEnabled ? 4 : 2
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    alarm.isEnabled 
                        ? LinearGradient(colors: [.black.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [.gray.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
        )
        .opacity(alarm.isEnabled ? 1.0 : 0.7)
        .scaleEffect(isToggling ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: alarm.isEnabled)
        .animation(.spring(response: 0.2), value: isToggling)
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Time Section
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(alarm.timeDisplayString)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            if let nextTrigger = alarm.nextTriggerDate {
                Text(timeUntilNextTrigger(nextTrigger))
                    .font(.caption)
                    .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 80, alignment: .leading)
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label
            Text(alarm.label)
                .font(.headline)
                .foregroundColor(alarm.isEnabled ? .primary : .secondary)
                .lineLimit(1)
            
            // Repeat Days or Next Occurrence
            HStack(spacing: 8) {
                // Repeat Pattern
                HStack(spacing: 4) {
                    Image(systemName: alarm.isRepeating ? "repeat" : "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(alarm.repeatDaysDisplayString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Tone
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(alarm.tone.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            
            // Snooze Info (if applicable)
            if alarm.currentSnoozeCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text("Snoozed \(alarm.currentSnoozeCount)/\(alarm.maxSnoozeCount)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    // MARK: - Toggle Section
    private var toggleSection: some View {
        VStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in
                    withAnimation(.spring(response: 0.3)) {
                        isToggling = true
                        onToggle()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isToggling = false
                        }
                    }
                }
            ))
            .toggleStyle(CustomToggleStyle(isEnabled: alarm.isEnabled))
            .scaleEffect(0.9)
            
            // Quick Actions
            if alarm.isEnabled {
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .frame(width: 24, height: 24)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(width: 24, height: 24)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    // MARK: - Context Menu
    private var contextMenuItems: some View {
        Group {
            Button(action: onEdit) {
                Label("Edit Alarm", systemImage: "pencil")
            }
            
            Button(action: onToggle) {
                Label(
                    alarm.isEnabled ? "Disable Alarm" : "Enable Alarm",
                    systemImage: alarm.isEnabled ? "pause.circle" : "play.circle"
                )
            }
            
            if alarm.isEnabled && alarm.canSnooze {
                Button("Snooze 5 min") {
                    // This would trigger a 5-minute snooze
                    // Implementation would depend on alarm scheduling service
                }
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete Alarm", systemImage: "trash")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func timeUntilNextTrigger(_ triggerDate: Date) -> String {
        let now = Date()
        let timeInterval = triggerDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Now"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if hours > 24 {
            let days = hours / 24
            return "in \(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}

// MARK: - Custom Toggle Style
struct CustomToggleStyle: ToggleStyle {
    let isEnabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    configuration.isOn 
                        ? LinearGradient(colors: [Color.blue], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color(.systemGray4)], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                )
                .onTapGesture {
                    configuration.isOn.toggle()
                }
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        // Enabled alarm
        AlarmRowView(
            alarm: Alarm(
                time: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!,
                label: "Morning Workout",
                repeatDays: [.monday, .wednesday, .friday],
                tone: .energetic
            ),
            onToggle: {},
            onEdit: {},
            onDelete: {}
        )
        
        // Disabled alarm
        AlarmRowView(
            alarm: {
                var alarm = Alarm(
                    time: Calendar.current.date(byAdding: .hour, value: 8, to: Date())!,
                    label: "Work Meeting",
                    tone: .gentle
                )
                alarm.toggle() // Disable
                return alarm
            }(),
            onToggle: {},
            onEdit: {},
            onDelete: {}
        )
        
        // Snoozed alarm
        AlarmRowView(
            alarm: {
                var alarm = Alarm(
                    time: Calendar.current.date(byAdding: .minute, value: 30, to: Date())!,
                    label: "Take Medication",
                    tone: .toughLove
                )
                alarm.snooze()
                return alarm
            }(),
            onToggle: {},
            onEdit: {},
            onDelete: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
