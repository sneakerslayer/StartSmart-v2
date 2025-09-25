import SwiftUI

// MARK: - Intent Input View
struct IntentInputView: View {
    @StateObject private var formViewModel = IntentFormViewModel()
    @StateObject private var intentViewModel = IntentViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let alarm: Alarm?
    let onSave: (Intent) -> Void
    
    @State private var showingAdvancedOptions = false
    @State private var showingToneInfo = false
    @State private var showingPreview = false
    @State private var previewContent = ""
    
    // MARK: - Initialization
    init(alarm: Alarm? = nil, onSave: @escaping (Intent) -> Void) {
        self.alarm = alarm
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Goal Input Section
                    goalInputSection
                    
                    // Tone Selection Section
                    toneSelectionSection
                    
                    // Scheduled Time Section
                    scheduledTimeSection
                    
                    // Advanced Options
                    if showingAdvancedOptions {
                        advancedOptionsSection
                    }
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Set Your Intention")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Advanced") {
                        withAnimation(.easeInOut) {
                            showingAdvancedOptions.toggle()
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .onAppear {
            setupForAlarm()
        }
        .sheet(isPresented: $showingToneInfo) {
            ToneInfoView()
        }
        .sheet(isPresented: $showingPreview) {
            IntentPreviewView(content: previewContent)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("What's your goal?")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
            
            Text("Tell us what you want to achieve, and we'll create a personalized wake-up message to motivate you.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Goal Input Section
    private var goalInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Your Goal", systemImage: "flag.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(formViewModel.userGoal.count)/100")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(formViewModel.userGoal.isEmpty ? Color(.systemGray4) : Color.blue, lineWidth: 1)
                    )
                
                if formViewModel.userGoal.isEmpty {
                    Text("e.g., Exercise for 30 minutes, Read 20 pages, Meditate for 10 minutes...")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $formViewModel.userGoal)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    .onChange(of: formViewModel.userGoal) { newValue in
                        if newValue.count > 100 {
                            formViewModel.userGoal = String(newValue.prefix(100))
                        }
                    }
            }
            .frame(minHeight: 80)
            
            // Quick Goal Suggestions
            goalSuggestionsSection
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Goal Suggestions
    private var goalSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Popular Goals")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(popularGoals, id: \.self) { goal in
                    Button(action: {
                        formViewModel.userGoal = goal
                    }) {
                        Text(goal)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - Tone Selection Section
    private var toneSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Motivation Style", systemImage: "speaker.wave.2.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Learn More") {
                    showingToneInfo = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                ForEach(AlarmTone.allCases, id: \.self) { tone in
                    ToneSelectionRow(
                        tone: tone,
                        isSelected: formViewModel.tone == tone,
                        onSelect: {
                            formViewModel.tone = tone
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Scheduled Time Section
    private var scheduledTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("When to wake you up", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                DatePicker(
                    "Scheduled Time",
                    selection: $formViewModel.scheduledFor,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                
                if alarm != nil {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        
                        Text("This intention will be linked to your alarm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Advanced Options Section
    private var advancedOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Advanced Options", systemImage: "gearshape.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Custom Note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Note (Optional)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    TextField("Add a personal note or reminder...", text: $formViewModel.customNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                
                // Context Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Include Context")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Toggle("Weather Information", isOn: $formViewModel.includeWeather)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    Toggle("Calendar Events", isOn: $formViewModel.includeCalendar)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Preview Button
            Button(action: generatePreview) {
                HStack {
                    Image(systemName: "eye.fill")
                    Text("Preview Message")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!formViewModel.isValid)
            
            // Save Button
            Button(action: saveIntent) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Create Intention")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(formViewModel.isValid ? Color.blue : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!formViewModel.isValid)
            
            if let errorMessage = formViewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
    
    // MARK: - Private Methods
    private func setupForAlarm() {
        if let alarm = alarm {
            formViewModel.scheduledFor = alarm.nextTriggerDate ?? alarm.time
            formViewModel.tone = alarm.tone
        }
    }
    
    private func generatePreview() {
        guard let intent = formViewModel.createIntent() else { return }
        
        // Mock preview content - in real implementation, this would call the AI service
        previewContent = """
        Good morning! Today is the perfect day to \(intent.userGoal). 
        
        The \(intent.tone.displayName.lowercased()) energy you need is right here with you. You have the strength and determination to make this happen. 
        
        Let's take the first step together and build momentum throughout your day. You've got this!
        """
        
        showingPreview = true
    }
    
    private func saveIntent() {
        guard let intent = formViewModel.createIntent() else { return }
        
        // Link to alarm if provided
        var finalIntent = intent
        if let alarm = alarm {
            finalIntent.alarmId = alarm.id
        }
        
        onSave(finalIntent)
        dismiss()
    }
    
    // MARK: - Constants
    private let popularGoals = [
        "Exercise for 30 minutes",
        "Read 20 pages",
        "Meditate for 10 minutes",
        "Drink 8 glasses of water",
        "Write in journal",
        "Study for 1 hour",
        "Clean the house",
        "Call family member",
        "Practice gratitude",
        "Learn something new"
    ]
}

// MARK: - Tone Selection Row
struct ToneSelectionRow: View {
    let tone: AlarmTone
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Tone Icon
                Image(systemName: toneIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 24)
                
                // Tone Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(tone.displayName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(tone.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var toneIcon: String {
        switch tone {
        case .gentle:
            return "heart.fill"
        case .energetic:
            return "bolt.fill"
        case .toughLove:
            return "flame.fill"
        case .storyteller:
            return "book.fill"
        }
    }
}

// MARK: - Tone Info View
struct ToneInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Motivation Styles")
                            .font(.title.weight(.semibold))
                        
                        Text("Choose the tone that best matches your personality and motivation preferences.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    
                    // Tone Details
                    ForEach(AlarmTone.allCases, id: \.self) { tone in
                        ToneInfoCard(tone: tone)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Motivation Styles")
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

// MARK: - Tone Info Card
struct ToneInfoCard: View {
    let tone: AlarmTone
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: toneIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(tone.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(tone.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(toneExample)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var toneIcon: String {
        switch tone {
        case .gentle:
            return "heart.fill"
        case .energetic:
            return "bolt.fill"
        case .toughLove:
            return "flame.fill"
        case .storyteller:
            return "book.fill"
        }
    }
    
    private var toneExample: String {
        switch tone {
        case .gentle:
            return "\"Good morning, beautiful soul. Today's a gentle reminder that you have everything within you to achieve your goals...\""
        case .energetic:
            return "\"RISE AND SHINE! Today is YOUR day to CRUSH those goals! Let's GO GO GO!\""
        case .toughLove:
            return "\"Time to get up. No excuses, no delays. You set this goal for a reason - now prove you meant it.\""
        case .storyteller:
            return "\"Once upon a time, there was someone just like you who decided today would be the day they changed their story...\""
        }
    }
}

// MARK: - Intent Preview View
struct IntentPreviewView: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preview Header
                    VStack(spacing: 12) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Message Preview")
                            .font(.title2.weight(.semibold))
                        
                        Text("This is what your wake-up message will sound like:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    
                    // Content
                    VStack(alignment: .leading, spacing: 16) {
                        Text(content)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Play Button (mock)
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                Text("Play Audio Preview")
                            }
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Preview")
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

// MARK: - Preview Provider
#Preview {
    IntentInputView { intent in
        print("Intent created: \(intent.userGoal)")
    }
}
