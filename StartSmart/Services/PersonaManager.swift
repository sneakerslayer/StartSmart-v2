import Foundation

// MARK: - Persona Card Structure
struct PersonaCard {
    let name: String
    let description: String
    let characteristics: [String]
    let samplePhrase: String
    let voiceMapping: String // iOS TTS voice identifier
    let icon: String // SF Symbol icon name
    let color: String // Hex color for UI theming
}

// MARK: - Persona Manager
class PersonaManager {
    
    // MARK: - Persona Enum
    enum Persona: String, CaseIterable {
        case drillSergeantDrew = "Drill Sergeant Drew"
        case girlBestie = "Girl Bestie"
        case mrsWalker = "Mrs. Walker"
        case motivationalMike = "Motivational Mike"
        case calmKyle = "Calm Kyle"
        case angryAllen = "Angry Allen"
        
        var id: String { return self.rawValue }
        
        var shortName: String {
            switch self {
            case .drillSergeantDrew: return "Drew"
            case .girlBestie: return "Bestie"
            case .mrsWalker: return "Mrs. Walker"
            case .motivationalMike: return "Mike"
            case .calmKyle: return "Kyle"
            case .angryAllen: return "Allen"
            }
        }
    }
    
    // MARK: - Tone Level Enum
    enum ToneLevel {
        case gentle      // 0.0 - 0.3
        case balanced    // 0.3 - 0.7
        case toughLove   // 0.7 - 1.0
        
        static func fromSliderValue(_ value: Double) -> ToneLevel {
            if value <= 0.3 {
                return .gentle
            } else if value <= 0.7 {
                return .balanced
            } else {
                return .toughLove
            }
        }
    }
    
    // MARK: - Singleton
    static let shared = PersonaManager()
    private init() {}
    
    // MARK: - Persona Cards
    func getPersonaCard(for persona: Persona) -> PersonaCard {
        switch persona {
        case .drillSergeantDrew:
            return PersonaCard(
                name: "🎖️ Drill Sergeant Drew",
                description: "A tough but caring military drill instructor who believes discipline equals success. Drew pushes you to your limits because he knows you're capable of greatness.",
                characteristics: [
                    "Direct and commanding",
                    "Uses military terminology",
                    "Tough love approach",
                    "Believes in discipline",
                    "Results-oriented"
                ],
                samplePhrase: "Listen up! Do you think that goal is going to achieve itself? Time to move out and conquer your day! THAT'S AN ORDER!",
                voiceMapping: "DGzg6RaUqxGRTHSBjfgF", // ElevenLabs: Drill Sergeant Drew
                icon: "star.fill",
                color: "#4A5D23"
            )
            
        case .girlBestie:
            return PersonaCard(
                name: "✨ Girl Bestie",
                description: "Your supportive best friend who's always got your back. She's enthusiastic, caring, and knows exactly what to say to pump you up for success.",
                characteristics: [
                    "Enthusiastic and supportive",
                    "Uses modern slang",
                    "Encouraging and uplifting",
                    "Celebrates your wins",
                    "Like talking to your BFF"
                ],
                samplePhrase: "Heyyy gorgeous! Today is literally going to be amazing and you're going to absolutely crush it! Let's goooo bestie!",
                voiceMapping: "uYXf8XasLslADfZ2MB4u", // ElevenLabs: Girl Bestie
                icon: "heart.fill",
                color: "#FF6B9D"
            )
            
        case .mrsWalker:
            return PersonaCard(
                name: "🏡 Mrs. Walker",
                description: "A warm, caring Southern mom who believes in you completely. She offers gentle wisdom, unconditional support, and that special motherly encouragement.",
                characteristics: [
                    "Warm and nurturing",
                    "Southern charm and wisdom",
                    "Believes in you completely",
                    "Gentle but firm guidance",
                    "Motherly love and support"
                ],
                samplePhrase: "Rise and shine, darlin'. I just know you're going to do wonderfully today. Mama believes in you, sweetheart.",
                voiceMapping: "DLsHlh26Ugcm6ELvS0qi", // ElevenLabs: Mrs. Walker
                icon: "house.fill",
                color: "#8B4513"
            )
            
        case .motivationalMike:
            return PersonaCard(
                name: "🚀 Motivational Mike",
                description: "A high-energy motivational speaker who sees unlimited potential in everyone. Mike transforms challenges into opportunities and turns dreams into actionable plans.",
                characteristics: [
                    "High-energy and inspiring",
                    "Sees unlimited potential",
                    "Transforms challenges to opportunities",
                    "Future-focused mindset",
                    "Champion mentality"
                ],
                samplePhrase: "RISE AND SHINE, CHAMPION! Today is not just another day—it's your opportunity to become the person you're destined to be!",
                voiceMapping: "84Fal4DSXWfp7nJ8emqQ", // ElevenLabs: Motivational Mike
                icon: "flame.fill",
                color: "#FF4500"
            )
            
        case .calmKyle:
            return PersonaCard(
                name: "🧘 Calm Kyle",
                description: "A mindful, zen-like guide who approaches life with peaceful wisdom. Kyle helps you find inner strength and clarity through gentle, thoughtful guidance.",
                characteristics: [
                    "Peaceful and mindful",
                    "Zen-like wisdom",
                    "Gentle guidance",
                    "Present-moment awareness",
                    "Inner strength focus"
                ],
                samplePhrase: "Good morning. As the light enters the room, gently awaken your mind. The path to your goals begins with this single, mindful step.",
                voiceMapping: "MpZY6e8MW2zHVi4Vtxrn", // ElevenLabs: Calm Kyle
                icon: "leaf.fill",
                color: "#20B2AA"
            )
            
        case .angryAllen:
            return PersonaCard(
                name: "😡 Angry Allen",
                description: "A brutally honest, no-nonsense coach who's frustrated by wasted potential. Allen's tough approach comes from genuine care about your success.",
                characteristics: [
                    "Brutally honest",
                    "No-nonsense approach",
                    "Frustrated by wasted potential",
                    "Sarcastic but caring",
                    "Pushes through excuses"
                ],
                samplePhrase: "Are you KIDDING me? Still sleeping while your dreams are waiting? I'm more stressed about your success than you are! GET UP!",
                voiceMapping: "KLZOWyG48RjZkAAjuM89", // ElevenLabs: Angry Allen
                icon: "bolt.fill",
                color: "#DC143C"
            )
        }
    }
    
    // MARK: - Tone Modifier Generation
    func getToneModifier(for toneLevel: ToneLevel) -> String {
        switch toneLevel {
        case .gentle:
            return """
            [TONE MODIFIER]
            **Instruction:** The user has selected a "Gentle & Nurturing" tone. You must emphasize the most supportive, kind, and encouraging aspects of your persona. Soften your delivery and reduce any harshness or aggressive language.
            """
            
        case .balanced:
            return "" // No modifier for balanced - uses persona's default style
            
        case .toughLove:
            return """
            [TONE MODIFIER]
            **Instruction:** The user has selected a "Tough Love & Direct" tone. You must amplify the most intense, direct, and no-nonsense aspects of your persona. Be as firm and challenging as your character allows.
            """
        }
    }
    
    // MARK: - Full Persona Description for AI
    func getFullPersonaDescription(for persona: Persona) -> String {
        let card = getPersonaCard(for: persona)
        
        let characteristicsText = card.characteristics
            .map { "- \($0)" }
            .joined(separator: "\n")
        
        return """
        **Character:** \(card.name)
        
        **Background:** \(card.description)
        
        **Speaking Style & Characteristics:**
        \(characteristicsText)
        
        **Example of your voice:** "\(card.samplePhrase)"
        
        **Important:** Stay completely in character throughout the entire script. Your personality should be evident in every sentence.
        """
    }
    
    // MARK: - Voice Mapping for TTS
    func getVoiceMapping(for persona: Persona) -> String {
        let card = getPersonaCard(for: persona)
        
        // Map personas to specific iOS voices for better character representation
        switch persona {
        case .drillSergeantDrew:
            return "en-US" // Aaron - deeper, more authoritative
        case .girlBestie:
            return "en-GB" // Kate - energetic British accent
        case .mrsWalker:
            return "en-US" // Samantha - warm American voice
        case .motivationalMike:
            return "en-AU" // Lee - enthusiastic Australian accent
        case .calmKyle:
            return "en-CA" // Alex - calm Canadian voice
        case .angryAllen:
            return "en-US" // Aaron - intense American voice
        }
    }
    
    // MARK: - UI Helper Methods
    func getAllPersonas() -> [Persona] {
        return Persona.allCases
    }
    
    func getPersonaIcon(for persona: Persona) -> String {
        return getPersonaCard(for: persona).icon
    }
    
    func getPersonaColor(for persona: Persona) -> String {
        return getPersonaCard(for: persona).color
    }
    
    func getPersonaPreview(for persona: Persona, toneLevel: ToneLevel) -> String {
        let card = getPersonaCard(for: persona)
        
        // Generate a brief preview based on persona and tone
        switch (persona, toneLevel) {
        case (.drillSergeantDrew, .gentle):
            return "Alright soldier, [short pause] time to rise. Today's mission awaits, [short pause] and I know you're ready."
        case (.drillSergeantDrew, .balanced):
            return "Listen up! [short pause] Your objectives won't complete themselves. Time to move out and dominate!"
        case (.drillSergeantDrew, .toughLove):
            return "GET UP NOW! [short pause] No excuses, no delays! [short pause] Your mission starts THIS INSTANT!"
            
        case (.girlBestie, .gentle):
            return "Hey hun, [short pause] it's time to start your amazing day. You've got this, [short pause] I believe in you!"
        case (.girlBestie, .balanced):
            return "Wake up bestie! [short pause] Today is going to be incredible and you're going to slay it!"
        case (.girlBestie, .toughLove):
            return "Girl, get UP! [short pause] We are NOT wasting this day. Time to show the world what you're made of!"
            
        case (.mrsWalker, .gentle):
            return "Rise and shine, darlin'. Mama's here to help you start this beautiful day right."
        case (.mrsWalker, .balanced):
            return "Come on now, sweetheart. The day is calling and you're going to answer beautifully."
        case (.mrsWalker, .toughLove):
            return "Now listen here. I didn't raise someone to stay in bed when there's work to be done!"
            
        case (.motivationalMike, .gentle):
            return "Good morning, champion. Today holds incredible possibilities for your growth."
        case (.motivationalMike, .balanced):
            return "RISE AND SHINE! Today is your stage, and you're the star performer!"
        case (.motivationalMike, .toughLove):
            return "LEGENDS DON'T SLEEP WHILE DESTINY CALLS! YOUR GREATNESS STARTS NOW!"
            
        case (.calmKyle, .gentle):
            return "Gently welcome the morning light. Let peace guide your awakening to purposeful action."
        case (.calmKyle, .balanced):
            return "The day begins with awareness. Rise mindfully and embrace your intentions."
        case (.calmKyle, .toughLove):
            return "Recognize the resistance. Now choose growth over comfort. Rise with purpose."
            
        case (.angryAllen, .gentle):
            return "Look, you have things to do today. Maybe consider getting started... eventually."
        case (.angryAllen, .balanced):
            return "Are you serious right now? The day is wasting away while you're sleeping!"
        case (.angryAllen, .toughLove):
            return "WHAT IS WRONG WITH YOU?! GET OUT OF BED THIS INSTANT! STOP WASTING MY TIME!"
        }
    }
}

// MARK: - Extensions for Convenience

extension PersonaManager.Persona {
    var displayName: String {
        return self.rawValue
    }
}
