//
//  UsageTrackingService.swift
//  StartSmart
//
//  Tracks free tier usage limits (15 alarms per month)
//

import Foundation
import Combine

/// Manages usage tracking for free tier limits
class UsageTrackingService: ObservableObject {
    static let shared = UsageTrackingService()
    
    // Free tier limits
    private let freeAlarmCreditsPerMonth = 15
    private let freeVoiceCount = 2
    
    // Usage tracking
    @Published var alarmsUsedThisMonth: Int = 0
    @Published var currentMonthYear: String = ""
    
    private init() {
        loadUsageData()
        checkAndResetMonthlyUsage()
    }
    
    // MARK: - Usage Tracking
    
    func canCreateAlarm(isPremium: Bool) -> Bool {
        if isPremium {
            return true
        }
        
        checkAndResetMonthlyUsage()
        return alarmsUsedThisMonth < freeAlarmCreditsPerMonth
    }
    
    func incrementAlarmUsage() {
        checkAndResetMonthlyUsage()
        alarmsUsedThisMonth += 1
        saveUsageData()
        
        print("📊 Alarm usage: \(alarmsUsedThisMonth)/\(freeAlarmCreditsPerMonth)")
    }
    
    func getRemainingAlarmCredits(isPremium: Bool) -> Int? {
        if isPremium {
            return nil // Unlimited
        }
        
        checkAndResetMonthlyUsage()
        return max(0, freeAlarmCreditsPerMonth - alarmsUsedThisMonth)
    }
    
    func canAccessVoice(voiceIndex: Int, isPremium: Bool) -> Bool {
        if isPremium {
            return true
        }
        
        return voiceIndex < freeVoiceCount
    }
    
    func getAvailableVoiceCount(isPremium: Bool) -> Int {
        if isPremium {
            return Int.max // Unlimited
        }
        
        return freeVoiceCount
    }
    
    // MARK: - Monthly Reset
    
    private func checkAndResetMonthlyUsage() {
        let currentPeriod = getCurrentMonthYear()
        
        if currentPeriod != currentMonthYear {
            // New month - reset usage
            alarmsUsedThisMonth = 0
            currentMonthYear = currentPeriod
            saveUsageData()
            
            print("📅 New month detected - usage reset")
        }
    }
    
    private func getCurrentMonthYear() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    // MARK: - Persistence
    
    private func loadUsageData() {
        alarmsUsedThisMonth = UserDefaults.standard.integer(forKey: "alarmsUsedThisMonth")
        currentMonthYear = UserDefaults.standard.string(forKey: "currentMonthYear") ?? getCurrentMonthYear()
    }
    
    private func saveUsageData() {
        UserDefaults.standard.set(alarmsUsedThisMonth, forKey: "alarmsUsedThisMonth")
        UserDefaults.standard.set(currentMonthYear, forKey: "currentMonthYear")
    }
    
    // MARK: - Usage Info
    
    func getUsageInfo(isPremium: Bool) -> (used: Int, total: Int?, percentage: Double?) {
        if isPremium {
            return (used: alarmsUsedThisMonth, total: nil, percentage: nil)
        }
        
        checkAndResetMonthlyUsage()
        let percentage = Double(alarmsUsedThisMonth) / Double(freeAlarmCreditsPerMonth)
        return (used: alarmsUsedThisMonth, total: freeAlarmCreditsPerMonth, percentage: percentage)
    }
}

