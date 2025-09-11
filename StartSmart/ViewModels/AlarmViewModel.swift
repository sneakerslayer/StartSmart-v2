import Foundation
import Combine

// MARK: - Alarm View Model
@MainActor
class AlarmViewModel: ObservableObject {
    @Published var alarms: [Alarm] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedAlarm: Alarm?
    
    private let alarmRepository: AlarmRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    @Injected private var contentService: ContentGenerationServiceProtocol
    
    init(alarmRepository: AlarmRepositoryProtocol = AlarmRepository()) {
        self.alarmRepository = alarmRepository
        setupSubscriptions()
        loadAlarms()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        alarmRepository.alarms
            .receive(on: DispatchQueue.main)
            .assign(to: \.alarms, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func loadAlarms() {
        Task {
            do {
                isLoading = true
                errorMessage = nil
                try await alarmRepository.loadAlarms()
                isLoading = false
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load alarms: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func addAlarm(_ alarm: Alarm) {
        Task {
            do {
                try await alarmRepository.saveAlarm(alarm)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func updateAlarm(_ alarm: Alarm) {
        Task {
            do {
                try await alarmRepository.updateAlarm(alarm)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to update alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteAlarm(_ alarm: Alarm) {
        Task {
            do {
                try await alarmRepository.deleteAlarm(alarm)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func deleteAlarm(at indexSet: IndexSet) {
        Task {
            do {
                for index in indexSet {
                    let alarm = alarms[index]
                    try await alarmRepository.deleteAlarm(alarm)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func toggleAlarm(_ alarm: Alarm) {
        Task {
            do {
                try await alarmRepository.toggleAlarm(withId: alarm.id)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to toggle alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func snoozeAlarm(_ alarm: Alarm) {
        Task {
            do {
                try await alarmRepository.snoozeAlarm(withId: alarm.id)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to snooze alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func snoozeAlarm(_ alarmId: UUID) {
        Task {
            do {
                try await alarmRepository.snoozeAlarm(withId: alarmId)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to snooze alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func dismissAlarm(_ alarmId: UUID) {
        Task {
            do {
                try await alarmRepository.dismissAlarm(withId: alarmId)
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to dismiss alarm: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func createQuickAlarm(time: Date, label: String = "Wake up") -> Alarm {
        let alarm = Alarm(time: time, label: label)
        addAlarm(alarm)
        return alarm
    }
    
    func duplicateAlarm(_ alarm: Alarm) -> Alarm {
        let newAlarm = Alarm(
            time: alarm.time,
            label: "\(alarm.label) (Copy)",
            isEnabled: false, // Start disabled for safety
            repeatDays: alarm.repeatDays,
            tone: alarm.tone,
            snoozeEnabled: alarm.snoozeEnabled,
            snoozeDuration: alarm.snoozeDuration,
            maxSnoozeCount: alarm.maxSnoozeCount
        )
        addAlarm(newAlarm)
        return newAlarm
    }
    
    // MARK: - Computed Properties
    var enabledAlarms: [Alarm] {
        alarms.filter { $0.isEnabled }
    }
    
    var nextAlarm: Alarm? {
        enabledAlarms
            .compactMap { alarm in
                guard let nextTrigger = alarm.nextTriggerDate else { return nil }
                return (alarm, nextTrigger)
            }
            .min { $0.1 < $1.1 }?
            .0
    }
    
    var hasEnabledAlarms: Bool {
        !enabledAlarms.isEmpty
    }
    
    // MARK: - Async Computed Properties
    func getEnabledAlarms() async -> [Alarm] {
        return await alarmRepository.getEnabledAlarms()
    }
    
    func getNextAlarm() async -> Alarm? {
        return await alarmRepository.getNextAlarm()
    }
    
    // MARK: - Advanced Operations
    func importAlarms(_ alarms: [Alarm]) async {
        do {
            if let repository = alarmRepository as? AlarmRepository {
                try await repository.importAlarms(alarms)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to import alarms: \(error.localizedDescription)"
            }
        }
    }
    
    func exportAlarms() async -> [Alarm] {
        if let repository = alarmRepository as? AlarmRepository {
            return await repository.exportAlarms()
        }
        return alarms
    }
    
    func deleteAllAlarms() async {
        do {
            try await alarmRepository.deleteAllAlarms()
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete all alarms: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Content Generation Integration
    func generateContentForAlarm(_ alarm: Alarm, userIntent: String) async {
        guard !userIntent.isEmpty else {
            errorMessage = "Please provide your goal for tomorrow"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let context = buildContextForAlarm(alarm)
            let content = try await contentService.generateAlarmContent(
                userIntent: userIntent,
                tone: alarm.tone.rawValue,
                context: context
            )
            
            // Cache the content for later use
            // This would typically integrate with your content caching system
            print("Generated content for alarm: \(content.text)")
            
        } catch {
            errorMessage = "Failed to generate content: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func buildContextForAlarm(_ alarm: Alarm) -> [String: String] {
        let calendar = Calendar.current
        let triggerDate = alarm.nextTriggerDate ?? alarm.time
        
        let timeOfDay = calendar.component(.hour, from: triggerDate) < 12 ? "morning" : "afternoon"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        let dayOfWeek = dayFormatter.string(from: triggerDate)
        
        return [
            "timeOfDay": timeOfDay,
            "dayOfWeek": dayOfWeek,
            "weather": "sunny", // Would be fetched from weather API in real implementation
            "temperature": "72°F"
        ]
    }
}

// MARK: - Alarm Form View Model
@MainActor
class AlarmFormViewModel: ObservableObject {
    @Published var time = Date()
    @Published var label = "Wake up"
    @Published var isEnabled = true
    @Published var repeatDays: Set<WeekDay> = []
    @Published var tone: AlarmTone = .energetic
    @Published var snoozeEnabled = true
    @Published var snoozeDuration: TimeInterval = 300 // 5 minutes
    @Published var maxSnoozeCount = 3
    
    @Published var isEditing = false
    @Published var errorMessage: String?
    
    private var editingAlarm: Alarm?
    
    // MARK: - Initialization
    init() {
        setupDefaultTime()
    }
    
    init(alarm: Alarm) {
        loadFromAlarm(alarm)
    }
    
    // MARK: - Public Methods
    func loadFromAlarm(_ alarm: Alarm) {
        self.editingAlarm = alarm
        self.time = alarm.time
        self.label = alarm.label
        self.isEnabled = alarm.isEnabled
        self.repeatDays = alarm.repeatDays
        self.tone = alarm.tone
        self.snoozeEnabled = alarm.snoozeEnabled
        self.snoozeDuration = alarm.snoozeDuration
        self.maxSnoozeCount = alarm.maxSnoozeCount
        self.isEditing = true
    }
    
    func createAlarm() -> Alarm {
        if let existingAlarm = editingAlarm {
            // Update existing alarm
            var updatedAlarm = existingAlarm
            updatedAlarm.updateTime(time)
            updatedAlarm.label = label
            updatedAlarm.isEnabled = isEnabled
            updatedAlarm.repeatDays = repeatDays
            updatedAlarm.tone = tone
            updatedAlarm.snoozeEnabled = snoozeEnabled
            updatedAlarm.snoozeDuration = snoozeDuration
            updatedAlarm.maxSnoozeCount = maxSnoozeCount
            return updatedAlarm
        } else {
            // Create new alarm
            return Alarm(
                time: time,
                label: label,
                isEnabled: isEnabled,
                repeatDays: repeatDays,
                tone: tone,
                snoozeEnabled: snoozeEnabled,
                snoozeDuration: snoozeDuration,
                maxSnoozeCount: maxSnoozeCount
            )
        }
    }
    
    func reset() {
        editingAlarm = nil
        setupDefaultTime()
        label = "Wake up"
        isEnabled = true
        repeatDays = []
        tone = .energetic
        snoozeEnabled = true
        snoozeDuration = 300
        maxSnoozeCount = 3
        isEditing = false
        errorMessage = nil
    }
    
    func toggleRepeatDay(_ day: WeekDay) {
        if repeatDays.contains(day) {
            repeatDays.remove(day)
        } else {
            repeatDays.insert(day)
        }
    }
    
    func validate() -> Bool {
        errorMessage = nil
        
        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Alarm label cannot be empty"
            return false
        }
        
        if snoozeDuration < 60 || snoozeDuration > 1800 { // 1 minute to 30 minutes
            errorMessage = "Snooze duration must be between 1 and 30 minutes"
            return false
        }
        
        if maxSnoozeCount < 1 || maxSnoozeCount > 10 {
            errorMessage = "Maximum snooze count must be between 1 and 10"
            return false
        }
        
        return true
    }
    
    // MARK: - Computed Properties
    var timeDisplayString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    var repeatDaysDisplayString: String {
        if repeatDays.isEmpty {
            return "Never"
        } else if repeatDays.count == 7 {
            return "Every day"
        } else if Set([.monday, .tuesday, .wednesday, .thursday, .friday]).isSubset(of: repeatDays) && repeatDays.count == 5 {
            return "Weekdays"
        } else if Set([.saturday, .sunday]).isSubset(of: repeatDays) && repeatDays.count == 2 {
            return "Weekends"
        } else {
            return repeatDays.sorted().map(\.shortName).joined(separator: ", ")
        }
    }
    
    var snoozeDurationDisplayString: String {
        let minutes = Int(snoozeDuration / 60)
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
    
    // MARK: - Private Methods
    private func setupDefaultTime() {
        let calendar = Calendar.current
        let now = Date()
        
        // Set default time to next hour
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
        
        time = calendar.date(from: components) ?? now
    }
}
