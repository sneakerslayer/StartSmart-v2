import SwiftUI

// MARK: - Alarm Form View
struct AlarmFormView: View {
    @StateObject private var formViewModel: AlarmFormViewModel
    @StateObject private var subscriptionManager = DependencyContainer.shared.resolve() as SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    
    let onSave: (Alarm) -> Void
    
    // MARK: - Initialization
    init(alarm: Alarm? = nil, onSave: @escaping (Alarm) -> Void) {
        if let alarm = alarm {
            self._formViewModel = StateObject(wrappedValue: AlarmFormViewModel(alarm: alarm))
        } else {
            self._formViewModel = StateObject(wrappedValue: AlarmFormViewModel())
        }
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Subscription Status Banner
                    if !subscriptionManager.currentSubscriptionStatus.isPremium {
                        AlarmCountBadge()
                    }
                    
                    // Time Picker Section
                    timePickerSection
                    
                    // Label Section
                    labelSection
                    
                    // Repeat Days Section
                    repeatDaysSection
                    
                    // Tone Selection Section
                    VoiceSelectionGate(
                        selectedVoice: formViewModel.tone,
                        onVoiceChange: { tone in
                            formViewModel.tone = tone
                        }
                    )
                    
                    // Snooze Settings Section
                    snoozeSettingsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(formViewModel.isEditing ? "Edit Alarm" : "New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAlarm()
                    }
                    .fontWeight(.semibold)
                    .disabled(!formViewModel.validate())
                }
            }
        }
        .presentPaywall(
            isPresented: $showPaywall,
            configuration: subscriptionManager.getOptimalPaywallConfiguration(
                for: .unlimitedAlarms,
                source: "alarm_form"
            ),
            source: "alarm_form"
        )
        .alert("Validation Error", isPresented: .constant(formViewModel.errorMessage != nil)) {
            Button("OK") {
                formViewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = formViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Time Picker Section
    private var timePickerSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Time", icon: "clock.fill")
            
            VStack(spacing: 20) {
                // Large Time Display
                Text(formViewModel.timeDisplayString)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.vertical, 8)
                
                // Time Picker
                DatePicker(
                    "Alarm Time",
                    selection: $formViewModel.time,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
            }
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .blue.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Label Section
    private var labelSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Label", icon: "tag.fill")
            
            TextField("Enter alarm label", text: $formViewModel.label)
                .textFieldStyle(CustomTextFieldStyle())
        }
    }
    
    // MARK: - Repeat Days Section
    private var repeatDaysSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Repeat", icon: "repeat")
            
            VStack(spacing: 12) {
                Text(formViewModel.repeatDaysDisplayString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(WeekDay.allCases, id: \.self) { day in
                        WeekDayButton(
                            day: day,
                            isSelected: formViewModel.repeatDays.contains(day)
                        ) {
                            formViewModel.toggleRepeatDay(day)
                        }
                    }
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Tone Selection Section
    private var toneSelectionSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Tone", icon: "speaker.wave.2.fill")
            
            VStack(spacing: 12) {
                ForEach(AlarmTone.allCases, id: \.self) { tone in
                    ToneSelectionRow(
                        tone: tone,
                        isSelected: formViewModel.tone == tone
                    ) {
                        formViewModel.tone = tone
                    }
                }
            }
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    // MARK: - Snooze Settings Section
    private var snoozeSettingsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Snooze", icon: "moon.zzz.fill")
            
            VStack(spacing: 20) {
                // Snooze Enable Toggle
                HStack {
                    Text("Enable Snooze")
                        .font(.headline)
                    
                    Spacer()
                    
                    Toggle("", isOn: $formViewModel.snoozeEnabled)
                        .toggleStyle(CustomToggleStyle(isEnabled: formViewModel.snoozeEnabled))
                }
                
                if formViewModel.snoozeEnabled {
                    VStack(spacing: 16) {
                        // Snooze Duration
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Duration: \(formViewModel.snoozeDurationDisplayString)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(formViewModel.snoozeDuration / 60) },
                                    set: { formViewModel.snoozeDuration = TimeInterval($0 * 60) }
                                ),
                                in: 1...30,
                                step: 1
                            )
                            .tint(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        }
                        
                        // Max Snooze Count
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Maximum snoozes: \(formViewModel.maxSnoozeCount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(formViewModel.maxSnoozeCount) },
                                    set: { formViewModel.maxSnoozeCount = Int($0) }
                                ),
                                in: 1...10,
                                step: 1
                            )
                            .tint(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .animation(.easeInOut, value: formViewModel.snoozeEnabled)
        }
    }
    
    // MARK: - Helper Methods
    private func saveAlarm() {
        // Check if user can create more alarms
        if !formViewModel.isEditing && !subscriptionManager.canCreateAlarm() {
            showPaywall = true
            return
        }
        
        if formViewModel.validate() {
            let alarm = formViewModel.createAlarm()
            
            // Increment alarm count for new alarms
            if !formViewModel.isEditing {
                subscriptionManager.incrementAlarmCount()
            }
            
            onSave(alarm)
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
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
    }
}

// MARK: - Week Day Button
struct WeekDayButton: View {
    let day: WeekDay
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(
                            isSelected 
                                ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(.systemGray5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected ? Color.clear : Color(.systemGray4),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Tone Selection Row
struct ToneSelectionRow: View {
    let tone: AlarmTone
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                // Tone Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(tone.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(tone.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Play Button
                Button(action: {
                    // TODO: Implement tone preview
                }) {
                    Image(systemName: "play.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .gray.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

// MARK: - Preview
#Preview {
    AlarmFormView { alarm in
        print("Saved alarm: \(alarm)")
    }
}
