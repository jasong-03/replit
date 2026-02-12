//
//  ContentView.swift
//  replit
//
//  Arc Search / Unified AI Assistant
//  5 modes: Alarm, Meeting, Mood, Inbox, Schedule
//  Flow: dashboard → voice → preview → creating → saved → dashboard
//

import SwiftUI
import SwiftData
import Combine
import Speech
import AVFoundation

// MARK: - Data Models

enum AppPhase: Equatable {
    case onboarding
    case dashboard
    case voice
    case preview
    case creating
    case saved
}

enum UseCase: String, CaseIterable, Identifiable {
    case alarm, meeting, mood, inbox, schedule

    var id: String { rawValue }

    var label: String {
        switch self {
        case .alarm: "Alarm"
        case .meeting: "Meeting"
        case .mood: "Mood"
        case .inbox: "Inbox"
        case .schedule: "Schedule"
        }
    }

    var icon: String {
        switch self {
        case .alarm: "alarm.fill"
        case .meeting: "briefcase.fill"
        case .mood: "heart.fill"
        case .inbox: "tray.fill"
        case .schedule: "calendar"
        }
    }

    var color: Color {
        switch self {
        case .alarm: .black
        case .meeting: .blue
        case .mood: .purple
        case .inbox: .orange
        case .schedule: .teal
        }
    }

    var placeholder: String {
        switch self {
        case .alarm: "Try: \"Set alarm 9:45 AM morning run\""
        case .meeting: "Try: \"Prep for interview Friday 2pm\""
        case .mood: "Try: \"I feel anxious today\""
        case .inbox: "Try: \"Check inbox, create action items\""
        case .schedule: "Try: \"Gym 6pm, study after dinner\""
        }
    }

    var creatingLabel: String {
        switch self {
        case .alarm: "Creating Alarm"
        case .meeting: "Setting Up Meeting"
        case .mood: "Logging Mood"
        case .inbox: "Processing Inbox"
        case .schedule: "Building Schedule"
        }
    }

    var creatingSubtitle: String {
        switch self {
        case .alarm: "Setting up your routine..."
        case .meeting: "Preparing your prep list..."
        case .mood: "Analyzing your mood..."
        case .inbox: "Extracting action items..."
        case .schedule: "Organizing your day..."
        }
    }

    var savedLabel: String {
        switch self {
        case .alarm: "Alarm Saved"
        case .meeting: "Meeting Prepped"
        case .mood: "Mood Logged"
        case .inbox: "Tasks Created"
        case .schedule: "Schedule Set"
        }
    }

    var savedSubtitle: String {
        switch self {
        case .alarm: "Added to your alarms"
        case .meeting: "Ready for your meeting"
        case .mood: "Tracked in your journal"
        case .inbox: "Action items ready"
        case .schedule: "Your day is planned"
        }
    }
}

struct RoutineStep: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var duration: String
    var icon: String
    var isCompleted: Bool

    init(title: String, duration: String, icon: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title
        self.duration = duration
        self.icon = icon
        self.isCompleted = isCompleted
    }
}

@Model
class AlarmItem: Identifiable {
    var id: UUID
    var label: String
    var time: String
    var isOn: Bool
    var icon: String
    var streak: Int
    var bestStreak: Int
    var completionRate: Double
    var weekHistory: [Bool]
    var monthHistory: [Double]
    var avgWakeDeviation: Int
    var snoozeRate: Double
    var totalCompletions: Int
    var routine: [RoutineStep]

    init(label: String, time: String, isOn: Bool, icon: String,
         streak: Int = 0, bestStreak: Int = 0, completionRate: Double = 0,
         weekHistory: [Bool] = Array(repeating: false, count: 7),
         monthHistory: [Double] = Array(repeating: 0, count: 30),
         avgWakeDeviation: Int = 0, snoozeRate: Double = 0,
         totalCompletions: Int = 0, routine: [RoutineStep] = []) {
        self.id = UUID()
        self.label = label; self.time = time; self.isOn = isOn; self.icon = icon
        self.streak = streak; self.bestStreak = bestStreak; self.completionRate = completionRate
        self.weekHistory = weekHistory; self.monthHistory = monthHistory
        self.avgWakeDeviation = avgWakeDeviation; self.snoozeRate = snoozeRate
        self.totalCompletions = totalCompletions; self.routine = routine
    }
}

@Model
class MeetingItem: Identifiable {
    var id: UUID
    var title: String
    var date: String
    var time: String
    var icon: String
    var checklist: [RoutineStep]
    var notes: String

    init(title: String, date: String, time: String, icon: String = "briefcase.fill",
         checklist: [RoutineStep] = [], notes: String = "") {
        self.id = UUID()
        self.title = title; self.date = date; self.time = time
        self.icon = icon; self.checklist = checklist; self.notes = notes
    }
}

@Model
class MoodEntry: Identifiable {
    var id: UUID
    var mood: String
    var level: Double
    var trigger: String
    var suggestion: String
    var date: Date
    var weekMoods: [Double]

    @Transient var moodIcon: String {
        switch mood.lowercased() {
        case "happy", "energized": return "sun.max.fill"
        case "calm", "good": return "leaf.fill"
        case "anxious", "stressed": return "cloud.rain.fill"
        case "sad": return "cloud.fill"
        default: return "circle.fill"
        }
    }
    @Transient var moodColor: Color {
        if level >= 0.7 { return .green }
        if level >= 0.5 { return .yellow }
        if level >= 0.3 { return .orange }
        return .red
    }

    init(mood: String, level: Double, trigger: String, suggestion: String,
         date: Date = Date(), weekMoods: [Double] = Array(repeating: 0, count: 7)) {
        self.id = UUID()
        self.mood = mood; self.level = level; self.trigger = trigger
        self.suggestion = suggestion; self.date = date; self.weekMoods = weekMoods
    }
}

@Model
class InboxItem: Identifiable {
    var id: UUID
    var source: String
    var sourceIcon: String
    var priority: String
    var actionItems: [RoutineStep]

    @Transient var completedCount: Int { actionItems.filter(\.isCompleted).count }

    init(source: String, sourceIcon: String, priority: String, actionItems: [RoutineStep] = []) {
        self.id = UUID()
        self.source = source; self.sourceIcon = sourceIcon
        self.priority = priority; self.actionItems = actionItems
    }
}

@Model
class ScheduleBlock: Identifiable {
    var id: UUID
    var title: String
    var startTime: String
    var endTime: String
    var duration: String
    var icon: String
    var colorName: String
    var isCompleted: Bool

    @Transient var color: Color {
        switch colorName {
        case "blue": .blue; case "green": .green; case "purple": .purple
        case "orange": .orange; case "teal": .teal; case "red": .red
        default: .gray
        }
    }

    init(title: String, startTime: String, endTime: String, duration: String,
         icon: String, colorName: String, isCompleted: Bool = false) {
        self.id = UUID()
        self.title = title; self.startTime = startTime; self.endTime = endTime
        self.duration = duration; self.icon = icon; self.colorName = colorName
        self.isCompleted = isCompleted
    }
}

@Model
class UserProfile {
    var name: String
    var avatarIndex: Int
    var createdAt: Date

    init(name: String, avatarIndex: Int) {
        self.name = name
        self.avatarIndex = avatarIndex
        self.createdAt = Date()
    }
}

enum DashboardSelection: Identifiable {
    case alarm(AlarmItem)
    case meeting(MeetingItem)
    case mood(MoodEntry)
    case inbox(InboxItem)
    var id: String {
        switch self {
        case .alarm(let a): "a-\(a.id)"
        case .meeting(let m): "m-\(m.id)"
        case .mood(let m): "d-\(m.id)"
        case .inbox(let i): "i-\(i.id)"
        }
    }
}

// MARK: - Replit Backend Service

enum ReplitService {
    static func parse(text: String, mode: UseCase) async throws -> [String: Any] {
        let baseURL = Config.replitBackendURL
        guard !baseURL.isEmpty else { throw URLError(.badURL) }
        let url = URL(string: "\(baseURL)/api/parse")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.replitApiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body: [String: Any] = ["text": text, "mode": mode.rawValue]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              parsed["error"] == nil
        else { throw URLError(.badServerResponse) }
        return parsed
    }

    static func saveItem(_ item: [String: Any], type: String) async throws {
        let baseURL = Config.replitBackendURL
        guard !baseURL.isEmpty else { return }
        let url = URL(string: "\(baseURL)/api/\(type)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.replitApiKey, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try JSONSerialization.data(withJSONObject: item)
        let _ = try await URLSession.shared.data(for: request)
    }
}

// MARK: - Gemini Service (Fallback)

enum GeminiService {
    static func parse(text: String, mode: UseCase) async throws -> [String: Any] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.geminiApiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let prompt = buildPrompt(for: mode, text: text)
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = response["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let jsonText = parts.first?["text"] as? String,
              let jsonData = jsonText.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { throw URLError(.badServerResponse) }
        return parsed
    }

    private static func buildPrompt(for mode: UseCase, text: String) -> String {
        let base = "You are a voice command parser for a personal assistant app. Parse the user's voice input into structured JSON. Be creative and helpful — fill in reasonable defaults for anything not explicitly mentioned. Use valid Apple SF Symbol names for icons."
        let schema: String
        switch mode {
        case .alarm:
            schema = """
            Return JSON: {"label":"short alarm name","time":"HH:mm (24h)","icon":"SF Symbol name","routine":[{"title":"step name","duration":"e.g. 5 min","icon":"SF Symbol"}]} Include 2-4 routine steps relevant to the alarm context.
            """
        case .meeting:
            schema = """
            Return JSON: {"title":"meeting name","date":"day/date","time":"h:mm a","icon":"SF Symbol","checklist":[{"title":"prep step","duration":"e.g. 15 min","icon":"SF Symbol"}],"notes":"brief context/notes"} Include 2-4 checklist steps.
            """
        case .mood:
            schema = """
            Return JSON: {"mood":"one word (e.g. Anxious, Happy, Tired, Stressed, Calm, Energized)","level":0.0to1.0,"trigger":"cause","suggestion":"one helpful action"} level: 0=terrible, 1=great.
            """
        case .inbox:
            schema = """
            Return JSON: {"source":"Email/Messages/Slack/etc","sourceIcon":"SF Symbol","priority":"High/Medium/Low","actionItems":[{"title":"task","duration":"e.g. 5 min","icon":"SF Symbol"}]} Include 2-4 action items.
            """
        case .schedule:
            schema = """
            Return JSON: {"blocks":[{"title":"activity","startTime":"h:mm a","endTime":"h:mm a","duration":"e.g. 1h","icon":"SF Symbol","colorName":"blue/green/purple/orange/teal/red"}]} Include all mentioned time blocks. Estimate reasonable durations if not specified.
            """
        }
        return "\(base)\n\n\(schema)\n\nVoice input: \"\(text)\""
    }

    // MARK: JSON → Model

    static func alarmFromJSON(_ json: [String: Any]) -> AlarmItem {
        let label = json["label"] as? String ?? "New Alarm"
        let time = json["time"] as? String ?? "09:00"
        let icon = json["icon"] as? String ?? "alarm.fill"
        let routineData = json["routine"] as? [[String: Any]] ?? []
        let routine = routineData.map { s in
            RoutineStep(title: s["title"] as? String ?? "Step", duration: s["duration"] as? String ?? "5 min", icon: s["icon"] as? String ?? "checkmark")
        }
        return AlarmItem(label: label, time: time, isOn: true, icon: icon, routine: routine)
    }

    static func meetingFromJSON(_ json: [String: Any]) -> MeetingItem {
        let title = json["title"] as? String ?? "Meeting"
        let date = json["date"] as? String ?? "Today"
        let time = json["time"] as? String ?? "2:00 PM"
        let icon = json["icon"] as? String ?? "briefcase.fill"
        let notes = json["notes"] as? String ?? ""
        let checklistData = json["checklist"] as? [[String: Any]] ?? []
        let checklist = checklistData.map { s in
            RoutineStep(title: s["title"] as? String ?? "Step", duration: s["duration"] as? String ?? "10 min", icon: s["icon"] as? String ?? "checkmark")
        }
        return MeetingItem(title: title, date: date, time: time, icon: icon, checklist: checklist, notes: notes)
    }

    static func moodFromJSON(_ json: [String: Any]) -> MoodEntry {
        let mood = json["mood"] as? String ?? "Neutral"
        let level = json["level"] as? Double ?? 0.5
        let trigger = json["trigger"] as? String ?? ""
        let suggestion = json["suggestion"] as? String ?? "Take a moment to breathe"
        return MoodEntry(mood: mood, level: level, trigger: trigger, suggestion: suggestion, weekMoods: [level, 0, 0, 0, 0, 0, 0])
    }

    static func inboxFromJSON(_ json: [String: Any]) -> InboxItem {
        let source = json["source"] as? String ?? "Inbox"
        let sourceIcon = json["sourceIcon"] as? String ?? "tray.fill"
        let priority = json["priority"] as? String ?? "Medium"
        let itemsData = json["actionItems"] as? [[String: Any]] ?? []
        let actionItems = itemsData.map { s in
            RoutineStep(title: s["title"] as? String ?? "Task", duration: s["duration"] as? String ?? "5 min", icon: s["icon"] as? String ?? "checkmark")
        }
        return InboxItem(source: source, sourceIcon: sourceIcon, priority: priority, actionItems: actionItems)
    }

    static func scheduleFromJSON(_ json: [String: Any]) -> [ScheduleBlock] {
        let blocksData = json["blocks"] as? [[String: Any]] ?? []
        return blocksData.map { b in
            ScheduleBlock(
                title: b["title"] as? String ?? "Block",
                startTime: b["startTime"] as? String ?? "9:00 AM",
                endTime: b["endTime"] as? String ?? "10:00 AM",
                duration: b["duration"] as? String ?? "1h",
                icon: b["icon"] as? String ?? "calendar",
                colorName: b["colorName"] as? String ?? "blue"
            )
        }
    }
}

// MARK: - App State

class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .onboarding
    @Published var userName: String = ""
    @Published var selectedAvatar: Int = 0
    @Published var selectedMode: UseCase = .alarm
    @Published var lastCreatedMode: UseCase = .alarm
    @Published var transcriptionText: String = ""
    @Published var isRecording: Bool = false
    @Published var processingProgress: Double = 0
    @Published var transcriptionDone: Bool = false
    @Published var isParsing: Bool = false
    @Published var pendingItemId: UUID?

    // Pending items (one per mode, not yet persisted)
    @Published var pendingAlarm: AlarmItem?
    @Published var pendingMeeting: MeetingItem?
    @Published var pendingMood: MoodEntry?
    @Published var pendingInbox: InboxItem?
    @Published var pendingScheduleBlocks: [ScheduleBlock]?

    var modelContext: ModelContext?

    // Speech recognition
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var processingTimer: Timer?

    // MARK: - Persistence

    func loadProfile() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<UserProfile>()
        if let profile = try? ctx.fetch(descriptor).first {
            userName = profile.name
            selectedAvatar = profile.avatarIndex
            phase = .dashboard
        } else {
            phase = .onboarding
            seedDemoData()
        }
    }

    func seedDemoData() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<AlarmItem>()
        guard (try? ctx.fetchCount(descriptor)) == 0 else { return }

        // Preset alarms
        ctx.insert(AlarmItem(label: "Walking the dog", time: "07:30", isOn: false, icon: "figure.walk",
            streak: 5, bestStreak: 14, completionRate: 0.78,
            weekHistory: [true, true, false, true, true, true, false],
            monthHistory: [1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,0.5,1,1,0,1,1,1],
            avgWakeDeviation: -3, snoozeRate: 0.12, totalCompletions: 45,
            routine: [
                RoutineStep(title: "Leash up", duration: "2 min", icon: "link"),
                RoutineStep(title: "Walk 20 min", duration: "20 min", icon: "figure.walk"),
                RoutineStep(title: "Water bowl", duration: "1 min", icon: "drop.fill"),
            ]))
        ctx.insert(AlarmItem(label: "Team standup", time: "10:00", isOn: true, icon: "person.3.fill",
            streak: 21, bestStreak: 21, completionRate: 0.95,
            weekHistory: [true, true, true, true, true, true, true],
            monthHistory: [1,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
            avgWakeDeviation: -1, snoozeRate: 0.05, totalCompletions: 89,
            routine: [
                RoutineStep(title: "Open Slack", duration: "1 min", icon: "bubble.left.fill"),
                RoutineStep(title: "Review PRs", duration: "5 min", icon: "doc.text.magnifyingglass"),
                RoutineStep(title: "Join call", duration: "15 min", icon: "phone.fill"),
            ]))
        ctx.insert(AlarmItem(label: "Lunch break", time: "12:30", isOn: false, icon: "fork.knife",
            streak: 3, bestStreak: 8, completionRate: 0.62,
            weekHistory: [true, false, true, true, false, true, false],
            monthHistory: [1,0,1,0,1,1,0,0,1,1,0,1,0,1,1,0,0,1,1,0,1,0,1,1,0,1,0,0,1,0],
            avgWakeDeviation: 7, snoozeRate: 0.35, totalCompletions: 28,
            routine: [
                RoutineStep(title: "Stretch", duration: "3 min", icon: "figure.flexibility"),
                RoutineStep(title: "Eat lunch", duration: "20 min", icon: "fork.knife"),
                RoutineStep(title: "Short walk", duration: "10 min", icon: "figure.walk"),
            ]))

        // Preset meeting
        ctx.insert(MeetingItem(title: "Design Review", date: "Thursday", time: "3:00 PM", icon: "paintbrush.fill",
            checklist: [
                RoutineStep(title: "Gather mockups", duration: "10 min", icon: "photo.on.rectangle"),
                RoutineStep(title: "Review feedback", duration: "15 min", icon: "text.bubble"),
                RoutineStep(title: "Update Figma", duration: "20 min", icon: "pencil.and.ruler"),
            ], notes: "Focus on mobile flows. Bring latest user research."))

        // Preset moods
        ctx.insert(MoodEntry(mood: "Energized", level: 0.85, trigger: "Good sleep",
            suggestion: "Channel energy into your top priority",
            weekMoods: [0.7, 0.6, 0.85, 0, 0, 0, 0]))
        ctx.insert(MoodEntry(mood: "Calm", level: 0.65, trigger: "Morning meditation",
            suggestion: "Great day for deep work",
            weekMoods: [0.7, 0.65, 0, 0, 0, 0, 0]))

        // Preset inbox
        ctx.insert(InboxItem(source: "Email", sourceIcon: "envelope.fill", priority: "Medium",
            actionItems: [
                RoutineStep(title: "Reply to team update", duration: "5 min", icon: "arrowshape.turn.up.left.fill"),
                RoutineStep(title: "Review attachment", duration: "10 min", icon: "paperclip"),
            ]))

        // Preset schedule
        ctx.insert(ScheduleBlock(title: "Focus Work", startTime: "9:00 AM", endTime: "12:00 PM", duration: "3h", icon: "brain", colorName: "blue"))
        ctx.insert(ScheduleBlock(title: "Lunch", startTime: "12:00 PM", endTime: "1:00 PM", duration: "1h", icon: "fork.knife", colorName: "green"))
        ctx.insert(ScheduleBlock(title: "Meetings", startTime: "2:00 PM", endTime: "4:00 PM", duration: "2h", icon: "person.2.fill", colorName: "purple"))

        try? ctx.save()
    }

    // MARK: - Voice (Speech Recognition)

    func requestSpeechPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    func startRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        transcriptionText = ""
        transcriptionDone = false

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self, self.isRecording else { return }
            if let result = result {
                DispatchQueue.main.async {
                    guard self.isRecording else { return }
                    self.transcriptionText = result.bestTranscription.formattedString
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch { return }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false  // Set FIRST so callback stops updating
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if !transcriptionText.isEmpty {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                transcriptionDone = true
            }
        }
    }

    func switchMode(to mode: UseCase) {
        guard mode != selectedMode else { return }
        selectedMode = mode
        stopRecording()
        transcriptionText = ""
        transcriptionDone = false
        startRecording()
    }

    // MARK: - Voice → Preview

    func confirmVoiceInput() {
        stopRecording()
        let text = transcriptionText
        isParsing = true

        Task { @MainActor in
            defer { isParsing = false }

            // Try: Replit backend → Gemini direct → hardcoded fallback
            var json: [String: Any]?

            // 1. Try Replit backend (shows Replit AI integration)
            if let result = try? await ReplitService.parse(text: text, mode: selectedMode) {
                json = result
            }
            // 2. Fallback: direct Gemini API
            if json == nil, let result = try? await GeminiService.parse(text: text, mode: selectedMode) {
                json = result
            }

            if let json = json {
                switch selectedMode {
                case .alarm: pendingAlarm = GeminiService.alarmFromJSON(json)
                case .meeting: pendingMeeting = GeminiService.meetingFromJSON(json)
                case .mood: pendingMood = GeminiService.moodFromJSON(json)
                case .inbox: pendingInbox = GeminiService.inboxFromJSON(json)
                case .schedule: pendingScheduleBlocks = GeminiService.scheduleFromJSON(json)
                }
            } else {
                // 3. Fallback: hardcoded demo data
                switch selectedMode {
                case .alarm: pendingAlarm = makeAlarm()
                case .meeting: pendingMeeting = makeMeeting()
                case .mood: pendingMood = makeMood()
                case .inbox: pendingInbox = makeInbox()
                case .schedule: pendingScheduleBlocks = makeSchedule()
                }
            }

            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) { phase = .preview }
        }
    }

    // MARK: - Preview → Creating

    func createEntry() {
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) { phase = .creating }
        startProcessing()
    }

    func startProcessing() {
        processingProgress = 0
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.processingProgress += 0.007
            if self.processingProgress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { self.phase = .saved }
                }
            }
        }
    }

    // MARK: - Saved → Dashboard

    func viewDashboard() {
        guard let ctx = modelContext else { return }
        switch selectedMode {
        case .alarm:
            if let a = pendingAlarm { ctx.insert(a); pendingItemId = a.id }
        case .meeting:
            if let m = pendingMeeting { ctx.insert(m); pendingItemId = m.id }
        case .mood:
            if let m = pendingMood { ctx.insert(m); pendingItemId = m.id }
        case .inbox:
            if let i = pendingInbox { ctx.insert(i); pendingItemId = i.id }
        case .schedule:
            if let blocks = pendingScheduleBlocks {
                blocks.forEach { ctx.insert($0) }
                pendingItemId = blocks.first?.id
            }
        }
        try? ctx.save()
        lastCreatedMode = selectedMode
        syncToReplit()
        withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { phase = .dashboard }
    }

    private func syncToReplit() {
        Task {
            switch selectedMode {
            case .alarm:
                if let a = pendingAlarm {
                    try? await ReplitService.saveItem(["id": a.id.uuidString, "label": a.label, "time": a.time, "icon": a.icon], type: "alarms")
                }
            case .meeting:
                if let m = pendingMeeting {
                    try? await ReplitService.saveItem(["id": m.id.uuidString, "title": m.title, "date": m.date, "time": m.time], type: "meetings")
                }
            case .mood:
                if let m = pendingMood {
                    try? await ReplitService.saveItem(["id": m.id.uuidString, "mood": m.mood, "level": m.level, "trigger": m.trigger], type: "moods")
                }
            case .inbox:
                if let i = pendingInbox {
                    try? await ReplitService.saveItem(["id": i.id.uuidString, "source": i.source, "priority": i.priority], type: "inbox")
                }
            case .schedule:
                if let blocks = pendingScheduleBlocks {
                    for b in blocks {
                        try? await ReplitService.saveItem(["id": b.id.uuidString, "title": b.title, "startTime": b.startTime, "endTime": b.endTime], type: "schedule")
                    }
                }
            }
        }
    }

    // MARK: - Dashboard → Voice

    func startNewEntry() {
        pendingAlarm = nil; pendingMeeting = nil; pendingMood = nil
        pendingInbox = nil; pendingScheduleBlocks = nil; pendingItemId = nil
        transcriptionText = ""; transcriptionDone = false
        isRecording = false; processingProgress = 0
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { phase = .voice }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.requestSpeechPermission { granted in
                if granted { self.startRecording() }
            }
        }
    }

    func completeOnboarding() {
        if let ctx = modelContext {
            let profile = UserProfile(name: userName, avatarIndex: selectedAvatar)
            ctx.insert(profile)
            try? ctx.save()
        }
        withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { phase = .dashboard }
    }

    func finishRecording() {
        stopRecording()
    }

    func stopAndReset() {
        stopRecording()
        processingTimer?.invalidate()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            phase = .dashboard
            transcriptionText = ""; transcriptionDone = false
            isRecording = false; processingProgress = 0
            pendingAlarm = nil; pendingMeeting = nil; pendingMood = nil
            pendingInbox = nil; pendingScheduleBlocks = nil
        }
    }

    // MARK: - Parsers (demo: hardcoded)

    private func makeAlarm() -> AlarmItem {
        AlarmItem(label: "Morning Run", time: "09:45", isOn: true, icon: "alarm.fill",
            routine: [
                RoutineStep(title: "Stretch", duration: "5 min", icon: "figure.flexibility"),
                RoutineStep(title: "Run", duration: "20 min", icon: "figure.run"),
                RoutineStep(title: "Cool down", duration: "5 min", icon: "wind"),
            ])
    }

    private func makeMeeting() -> MeetingItem {
        MeetingItem(title: "Interview at Acme Corp", date: "Friday", time: "2:00 PM",
            checklist: [
                RoutineStep(title: "Research company", duration: "30 min", icon: "magnifyingglass"),
                RoutineStep(title: "Prepare questions", duration: "15 min", icon: "questionmark.bubble"),
                RoutineStep(title: "Update portfolio", duration: "20 min", icon: "folder.fill"),
            ], notes: "Check Glassdoor reviews. Prepare STAR stories.")
    }

    private func makeMood() -> MoodEntry {
        MoodEntry(mood: "Anxious", level: 0.35, trigger: "Work deadline",
            suggestion: "Try 5-min box breathing exercise",
            weekMoods: [0.7, 0.6, 0.4, 0.35, 0, 0, 0])
    }

    private func makeInbox() -> InboxItem {
        InboxItem(source: "Email", sourceIcon: "envelope.fill", priority: "High",
            actionItems: [
                RoutineStep(title: "Reply to client proposal", duration: "10 min", icon: "arrowshape.turn.up.left.fill"),
                RoutineStep(title: "Schedule follow-up call", duration: "5 min", icon: "phone.fill"),
                RoutineStep(title: "Update CRM entry", duration: "5 min", icon: "square.and.pencil"),
            ])
    }

    private func makeSchedule() -> [ScheduleBlock] {
        [
            ScheduleBlock(title: "Gym", startTime: "6:00 PM", endTime: "7:00 PM", duration: "1h", icon: "figure.run", colorName: "blue"),
            ScheduleBlock(title: "Study", startTime: "8:00 PM", endTime: "10:00 PM", duration: "2h", icon: "book.fill", colorName: "green"),
            ScheduleBlock(title: "Call Mom", startTime: "10:00 PM", endTime: "10:15 PM", duration: "15m", icon: "phone.fill", colorName: "purple"),
        ]
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.modelContext) private var modelContext
    @Namespace private var hero

    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97).ignoresSafeArea()
            DotGridBackground()

            switch viewModel.phase {
            case .onboarding:
                OnboardingPhase(viewModel: viewModel)
                    .transition(.opacity)
            case .dashboard:
                DashboardPhase(viewModel: viewModel, ns: hero)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 30)),
                        removal: .opacity
                    ))
            case .voice:
                VoicePhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .preview:
                PreviewPhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity)
            case .creating:
                CreatingPhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity)
            case .saved:
                SavedPhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.loadProfile()
        }
    }
}

// MARK: - Dot Grid Background

struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            let dotRadius: CGFloat = 1.2
            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Circle().path(in: rect), with: .color(.black.opacity(0.12)))
                    y += spacing
                }
                x += spacing
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Pixel Avatars

struct PixelAvatarData {
    // Palette: 0=transparent, 1=black, 2=dark gray, 3=light gray, 4=white/skin
    static let palette: [Color] = [
        .clear,
        Color(white: 0.12),
        Color(white: 0.38),
        Color(white: 0.65),
        Color(white: 0.88),
    ]

    struct Avatar {
        let name: String
        let pixels: [[UInt8]]
    }

    static let avatars: [Avatar] = [
        // 0: Classic — clean short hair
        Avatar(name: "Classic", pixels: [
            [0,0,0,1,1,1,1,1,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,1,1,1,1,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
        // 1: Messy — wild spiky hair
        Avatar(name: "Messy", pixels: [
            [0,1,0,1,1,0,1,1,0,1,0,0],
            [1,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,0,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,4,1,1,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
        // 2: Glasses — round glasses, neat
        Avatar(name: "Glasses", pixels: [
            [0,0,0,1,1,1,1,1,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,1,1,1,4,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,1,1,1,1,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
        // 3: Beanie — beanie hat
        Avatar(name: "Beanie", pixels: [
            [0,0,0,0,0,1,1,0,0,0,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,2,2,1,2,2,1,2,2,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,4,1,1,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
        // 4: Punk — mohawk
        Avatar(name: "Punk", pixels: [
            [0,0,0,0,1,1,1,0,0,0,0,0],
            [0,0,0,0,1,1,1,0,0,0,0,0],
            [0,0,0,1,1,1,1,1,0,0,0,0],
            [0,1,4,4,1,1,1,4,4,4,1,0],
            [0,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,1,4,4,1,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,1,1,2,2,1,1,1,0,0],
        ]),
        // 5: Curly — curly/afro hair
        Avatar(name: "Curly", pixels: [
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,1,2,1,2,1,2,1,1,1,0],
            [1,1,2,1,2,1,2,1,2,1,1,0],
            [1,1,4,4,4,4,4,4,4,4,1,0],
            [1,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,4,1,1,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
        // 6: Cap — baseball cap
        Avatar(name: "Cap", pixels: [
            [0,0,0,0,0,0,0,0,0,0,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [1,1,2,2,2,2,2,2,2,1,0,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,4,1,1,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
        // 7: Hoodie — hood up
        Avatar(name: "Hoodie", pixels: [
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,2,2,2,2,2,2,2,2,1,0],
            [1,2,2,2,2,2,2,2,2,2,2,1],
            [1,2,4,4,4,4,4,4,4,4,2,1],
            [1,2,4,1,4,4,4,4,1,4,2,1],
            [1,2,4,4,4,4,4,4,4,4,2,1],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,4,1,1,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,2,4,4,4,4,4,4,2,1,0],
            [0,1,2,2,4,4,4,4,2,2,1,0],
            [0,1,2,2,2,2,2,2,2,2,1,0],
        ]),
        // 8: Beard — full beard
        Avatar(name: "Beard", pixels: [
            [0,0,0,1,1,1,1,1,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,1,4,4,4,4,1,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,2,2,1,1,1,1,2,2,1,0],
            [0,1,2,2,2,2,2,2,2,2,1,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
            [0,0,0,1,2,2,2,2,1,0,0,0],
            [0,0,0,0,1,1,1,1,0,0,0,0],
        ]),
        // 9: Bob — bob haircut
        Avatar(name: "Bob", pixels: [
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [1,1,4,4,4,4,4,4,4,4,1,1],
            [1,1,4,1,4,4,4,4,1,4,1,1],
            [1,1,4,4,4,4,4,4,4,4,1,1],
            [0,1,4,4,4,3,3,4,4,4,1,0],
            [0,1,4,4,4,1,1,4,4,4,1,0],
            [0,1,4,4,4,4,4,4,4,4,1,0],
            [0,0,1,4,4,4,4,4,4,1,0,0],
            [0,0,0,1,4,4,4,4,1,0,0,0],
            [0,0,1,2,2,2,2,2,2,1,0,0],
        ]),
    ]
}

struct PixelAvatarView: View {
    let index: Int
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let avatar = PixelAvatarData.avatars[((index % PixelAvatarData.avatars.count) + PixelAvatarData.avatars.count) % PixelAvatarData.avatars.count]
            let gridSize = 12
            let cellSize = canvasSize.width / CGFloat(gridSize)
            for row in 0..<gridSize {
                for col in 0..<gridSize {
                    let value = Int(avatar.pixels[row][col])
                    guard value > 0 else { continue }
                    let color = PixelAvatarData.palette[min(value, PixelAvatarData.palette.count - 1)]
                    let rect = CGRect(x: CGFloat(col) * cellSize, y: CGFloat(row) * cellSize, width: cellSize + 0.5, height: cellSize + 0.5)
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
        .overlay(RoundedRectangle(cornerRadius: size * 0.18).stroke(.black.opacity(0.12), lineWidth: 1))
    }
}

// MARK: - Onboarding Phase

struct OnboardingPhase: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showLogo = false
    @State private var showName = false
    @State private var showTagline = false
    @State private var showForm = false
    @State private var taglineProgress: Int = 0
    @FocusState private var nameFieldFocused: Bool

    private let taglineWords = ["Your", "AI", "Assistant"]
    private let appName = "HabitCards"

    var body: some View {
        ZStack {
            // Intro layer (fades out when form appears)
            if !showForm {
                VStack(spacing: 20) {
                    Spacer()

                    // Logo icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.black)
                            .frame(width: 80, height: 80)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(showLogo ? 1 : 0)
                    .opacity(showLogo ? 1 : 0)

                    // App name
                    Text(appName)
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(.black)
                        .opacity(showName ? 1 : 0)
                        .offset(y: showName ? 0 : 10)

                    // Tagline typing
                    Text(taglineWords.prefix(taglineProgress).joined(separator: " "))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.black.opacity(0.4))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: taglineProgress)
                        .frame(height: 24)

                    Spacer()
                }
                .transition(.opacity)
            }

            // Form layer
            if showForm {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 100)

                        // Small logo
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.black)
                                .frame(width: 48, height: 48)
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.bottom, 28)

                        // Header
                        Text("What should we call you?")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 24)

                        // Name field
                        TextField("Your name", text: $viewModel.userName)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(.black.opacity(nameFieldFocused ? 0.2 : 0.06), lineWidth: 1)
                            )
                            .padding(.horizontal, 40)
                            .focused($nameFieldFocused)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        // Avatar section
                        Text("Pick your avatar")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.black.opacity(0.4))
                            .padding(.top, 32)
                            .padding(.bottom, 16)

                        // Avatar grid: 2 rows x 5 cols
                        VStack(spacing: 12) {
                            ForEach(0..<2, id: \.self) { row in
                                HStack(spacing: 12) {
                                    ForEach(0..<5, id: \.self) { col in
                                        let idx = row * 5 + col
                                        if idx < PixelAvatarData.avatars.count {
                                            Button {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    viewModel.selectedAvatar = idx
                                                }
                                            } label: {
                                                VStack(spacing: 6) {
                                                    PixelAvatarView(index: idx, size: 52)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 52 * 0.18)
                                                                .stroke(.black, lineWidth: viewModel.selectedAvatar == idx ? 2.5 : 0)
                                                        )
                                                        .scaleEffect(viewModel.selectedAvatar == idx ? 1.08 : 1.0)
                                                    Text(PixelAvatarData.avatars[idx].name)
                                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                                        .foregroundColor(viewModel.selectedAvatar == idx ? .black : .black.opacity(0.3))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 28)

                        // Get Started button
                        Button(action: {
                            nameFieldFocused = false
                            viewModel.completeOnboarding()
                        }) {
                            HStack(spacing: 8) {
                                Text("Get Started")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule().fill(viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty ? .black.opacity(0.2) : .black)
                            )
                            .padding(.horizontal, 40)
                        }
                        .disabled(viewModel.userName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, 36)

                        Spacer().frame(height: 60)
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 40)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
            }
        }
        .onAppear { startIntroSequence() }
    }

    private func startIntroSequence() {
        // Logo
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3)) { showLogo = true }
        // App name
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.0)) { showName = true }
        // Tagline words
        for i in 1...taglineWords.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5 + Double(i) * 0.35) {
                withAnimation { taglineProgress = i }
            }
        }
        // Show form
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) { showForm = true }
        }
    }
}

// MARK: - Mode Selector Chips

struct ModeSelectorChips: View {
    @Binding var selected: UseCase
    var onSwitch: (UseCase) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UseCase.allCases) { mode in
                    Button {
                        onSwitch(mode)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 11, weight: .medium))
                            Text(mode.label)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(selected == mode ? .white : .black.opacity(0.5))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selected == mode ? mode.color : .black.opacity(0.05))
                        )
                    }
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Phase 1: Voice

struct VoicePhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false
    @State private var breathe = false
    @State private var currentTime = Date()

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: currentTime)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Time header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.black.opacity(0.35))
                    Text(timeString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.black.opacity(0.15))
                }
                Spacer()
                if viewModel.isRecording {
                    HStack(spacing: 6) {
                        Circle().fill(.red).frame(width: 8, height: 8)
                            .opacity(breathe ? 1 : 0.4)
                        Text("Listening")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.black.opacity(0.3))
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 28).padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.1), value: appeared)

            Spacer().frame(height: 16)

            // Mode selector
            ModeSelectorChips(selected: $viewModel.selectedMode) { mode in
                viewModel.switchMode(to: mode)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer()

            // Transcription card
            VStack(alignment: .leading, spacing: 0) {
                TranscriptionText(
                    text: viewModel.transcriptionText,
                    placeholder: viewModel.selectedMode.placeholder
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 140)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white.opacity(!viewModel.transcriptionText.isEmpty ? 0.7 : 0))
                    .animation(.easeOut(duration: 0.5), value: viewModel.transcriptionText)
            )
            .matchedGeometryEffect(id: "card", in: ns)
            .padding(.horizontal, 24)
            .scaleEffect(breathe ? 1.008 : 0.995)
            .offset(y: breathe ? -1 : 1)

            if viewModel.isParsing {
                HStack(spacing: 8) {
                    ProgressView().tint(viewModel.selectedMode.color)
                    Text("Parsing...")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.black.opacity(0.5))
                }
                .padding(.top, 24)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if viewModel.transcriptionDone {
                Button(action: { viewModel.confirmVoiceInput() }) {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Capsule().fill(viewModel.selectedMode.color))
                }
                .padding(.top, 24)
                .transition(.opacity.combined(with: .offset(y: 12)).combined(with: .scale(scale: 0.95)))
            }

            Spacer()

            BarWaveform(isActive: viewModel.isRecording)
                .frame(height: 60).padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.3), value: appeared)

            Spacer().frame(height: 24)

            ControlBar(viewModel: viewModel)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)

            Spacer().frame(height: 40)
        }
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { breathe = true }
        }
        .onDisappear { appeared = false }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in currentTime = t }
    }
}

struct TranscriptionText: View {
    let text: String
    let placeholder: String

    var body: some View {
        Text(text.isEmpty ? placeholder : text)
            .font(.system(size: text.isEmpty ? 20 : 32, weight: text.isEmpty ? .medium : .heavy, design: .rounded))
            .foregroundColor(text.isEmpty ? .black.opacity(0.2) : .black)
            .multilineTextAlignment(.leading)
            .lineLimit(5)
            .animation(.easeOut(duration: 0.15), value: text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BarWaveform: View {
    let isActive: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !isActive)) { timeline in
            Canvas { context, size in
                let barCount = 40
                let gap: CGFloat = 2
                let barWidth = (size.width - CGFloat(barCount - 1) * gap) / CGFloat(barCount)
                let maxH = size.height * 0.9
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<barCount {
                    let di = Double(i)
                    let s1 = sin(time * 8 + di * 0.7) * 0.5 + 0.5
                    let s2 = cos(time * 12 + di * 1.3) * 0.3
                    let center = Double(barCount) / 2.0
                    let dist = abs(di - center) / center
                    let envelope = 1.0 - dist * 0.6
                    let height = (s1 + s2) * envelope
                    let h = maxH * CGFloat(max(0.05, min(0.95, height)))
                    let x = CGFloat(i) * (barWidth + gap)
                    let y = (size.height - h) / 2
                    let rect = CGRect(x: x, y: y, width: barWidth, height: max(h, 2))
                    context.fill(RoundedRectangle(cornerRadius: barWidth / 2).path(in: rect), with: .color(.black.opacity(0.7)))
                }
            }
        }
    }
}

struct ControlBar: View {
    @ObservedObject var viewModel: AppViewModel
    var body: some View {
        HStack(spacing: 0) {
            Button(action: { viewModel.stopAndReset() }) {
                Circle().fill(Color.red).frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 4).fill(.white).frame(width: 14, height: 14))
            }
            Spacer()
            if viewModel.isRecording {
                Button(action: { viewModel.finishRecording() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                        Text("Done").font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white).padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Capsule().fill(viewModel.selectedMode.color))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Spacer()
            if !viewModel.isRecording && !viewModel.transcriptionDone {
                Button(action: {
                    viewModel.requestSpeechPermission { granted in
                        if granted { viewModel.startRecording() }
                    }
                }) {
                    Circle().fill(Color.black.opacity(0.08)).frame(width: 44, height: 44)
                        .overlay(Image(systemName: "mic.fill").font(.system(size: 16, weight: .medium)).foregroundColor(.black.opacity(0.6)))
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 28)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isRecording)
    }
}

// MARK: - Phase 2: Preview

struct PreviewPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false
    @State private var cardPulse = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New \(viewModel.selectedMode.label)")
                        .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.black)
                    Text("Confirm details")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 28).padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer()

            previewCard
                .matchedGeometryEffect(id: "card", in: ns)
                .padding(.horizontal, 28)
                .scaleEffect(cardPulse ? 1.0 : 0.97)

            Spacer()

            Button(action: { viewModel.createEntry() }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18))
                    Text("Create \(viewModel.selectedMode.label)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Capsule().fill(viewModel.selectedMode.color))
                .padding(.horizontal, 28)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: appeared)
            .padding(.bottom, 50)
        }
        .onAppear {
            appeared = true
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { cardPulse = true }
        }
        .onDisappear { appeared = false }
    }

    @ViewBuilder var previewCard: some View {
        switch viewModel.selectedMode {
        case .alarm: PreviewAlarmCard(alarm: viewModel.pendingAlarm)
        case .meeting: PreviewMeetingCard(meeting: viewModel.pendingMeeting)
        case .mood: PreviewMoodCard(mood: viewModel.pendingMood)
        case .inbox: PreviewInboxCard(inbox: viewModel.pendingInbox)
        case .schedule: PreviewScheduleCard(blocks: viewModel.pendingScheduleBlocks)
        }
    }
}

struct PreviewAlarmCard: View {
    let alarm: AlarmItem?
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PREVIEW").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.black.opacity(0.5))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.08)))
                    Image(systemName: alarm?.icon ?? "alarm").font(.system(size: 28)).foregroundColor(.black.opacity(0.4))
                }
                Spacer()
                Image(systemName: "figure.run").font(.system(size: 20, weight: .medium)).foregroundColor(.black.opacity(0.3))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm?.label ?? "Alarm").font(.system(size: 15, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.5))
                Text(alarm?.time ?? "--:--").font(.system(size: 48, weight: .bold, design: .rounded)).foregroundColor(.black)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.06), radius: 16, y: 6))
    }
}

struct PreviewMeetingCard: View {
    let meeting: MeetingItem?
    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MEETING PREP").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.blue.opacity(0.1)))
                    Image(systemName: meeting?.icon ?? "briefcase.fill").font(.system(size: 24)).foregroundColor(.blue.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(meeting?.date ?? "—").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.5))
                    Text(meeting?.time ?? "—").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.black)
                }
            }
            Text(meeting?.title ?? "Meeting").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let items = meeting?.checklist, !items.isEmpty {
                VStack(spacing: 6) {
                    ForEach(items) { step in
                        HStack(spacing: 8) {
                            Image(systemName: "circle").font(.system(size: 12)).foregroundColor(.black.opacity(0.2))
                            Text(step.title).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.6))
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .blue.opacity(0.08), radius: 16, y: 6))
    }
}

struct PreviewMoodCard: View {
    let mood: MoodEntry?
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("MOOD CHECK").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.purple).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.purple.opacity(0.1)))
                    Image(systemName: mood?.moodIcon ?? "heart.fill").font(.system(size: 28)).foregroundColor(mood?.moodColor ?? .purple)
                }
                Spacer()
                Text(mood?.mood ?? "—").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.black)
            }
            // Level bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.black.opacity(0.06)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(mood?.moodColor ?? .gray).frame(width: geo.size.width * (mood?.level ?? 0), height: 8)
                }
            }.frame(height: 8)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Trigger:").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.4))
                    Text(mood?.trigger ?? "—").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.7))
                }
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill").font(.system(size: 12)).foregroundColor(.yellow)
                    Text(mood?.suggestion ?? "—").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.6))
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .purple.opacity(0.08), radius: 16, y: 6))
    }
}

struct PreviewInboxCard: View {
    let inbox: InboxItem?
    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INBOX").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.orange.opacity(0.1)))
                    Image(systemName: inbox?.sourceIcon ?? "tray.fill").font(.system(size: 24)).foregroundColor(.orange.opacity(0.5))
                }
                Spacer()
                Text(inbox?.priority ?? "—").font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(inbox?.priority == "High" ? .red : .orange))
            }
            Text("\(inbox?.actionItems.count ?? 0) action items found")
                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let items = inbox?.actionItems {
                VStack(spacing: 6) {
                    ForEach(items) { step in
                        HStack(spacing: 8) {
                            Image(systemName: "circle").font(.system(size: 12)).foregroundColor(.black.opacity(0.2))
                            Text(step.title).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.6))
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .orange.opacity(0.08), radius: 16, y: 6))
    }
}

struct PreviewScheduleCard: View {
    let blocks: [ScheduleBlock]?
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("TODAY'S PLAN").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.teal).padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.teal.opacity(0.1)))
                }
                Spacer()
                if let b = blocks {
                    Text("\(b.count) blocks")
                        .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(.black.opacity(0.4))
                }
            }
            if let blocks = blocks {
                VStack(spacing: 8) {
                    ForEach(blocks) { block in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 2).fill(block.color).frame(width: 4, height: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.title).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.black)
                                Text("\(block.startTime) - \(block.endTime)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                            }
                            Spacer()
                            Text(block.duration).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(block.color)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .teal.opacity(0.08), radius: 16, y: 6))
    }
}

// MARK: - Phase 3: Creating

struct CreatingPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var startDate = Date()
    @State private var appeared = false

    var body: some View {
        ZStack {
            ASCIIRunnerCanvas(startDate: startDate)
                .frame(width: 220, height: 400)
                .opacity(appeared ? 0.25 : 0)
                .animation(.easeOut(duration: 1.0).delay(0.3), value: appeared)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.selectedMode.creatingLabel)
                            .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text(viewModel.selectedMode.creatingSubtitle)
                            .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                    }
                    Spacer()
                }
                .padding(.horizontal, 28).padding(.top, 60)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                Spacer()

                CreatingMiniCard(mode: viewModel.selectedMode, progress: viewModel.processingProgress)
                    .matchedGeometryEffect(id: "card", in: ns)
                    .padding(.horizontal, 48)

                Spacer()

                VStack(spacing: 8) {
                    ProgressView(value: viewModel.processingProgress).tint(viewModel.selectedMode.color).padding(.horizontal, 60)
                    Text("\(Int(viewModel.processingProgress * 100))%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(.black.opacity(0.3))
                }
                .padding(.bottom, 50)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
            }
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

struct CreatingMiniCard: View {
    let mode: UseCase
    let progress: Double

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(.black.opacity(0.06), lineWidth: 4)
                Circle().trim(from: 0, to: progress)
                    .stroke(mode.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                Image(systemName: mode.icon).font(.system(size: 24)).foregroundColor(mode.color.opacity(0.6))
            }.frame(width: 56, height: 56)
            VStack(spacing: 4) {
                Text(mode.creatingLabel).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.5))
                Text(mode.label).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.black)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 28).padding(.horizontal, 24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.08), radius: 20, y: 8))
    }
}

struct ASCIIRunnerCanvas: View {
    let startDate: Date
    @ViewBuilder
    private func trailLayer(index: Int, elapsed: Double, bounce: Double) -> some View {
        let i = CGFloat(index)
        CharacterGrid(elapsed: elapsed - Double(index) * 0.06)
            .frame(width: 200, height: 380)
            .mask { Image(systemName: "figure.run").font(.system(size: 300, weight: .black)).foregroundColor(.black) }
            .offset(x: -i * 14, y: CGFloat(bounce) + i * 2)
            .opacity(0.12 * Double(4 - index) / 3.0)
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 8.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let bounce = sin(elapsed * 8) * 3
            ZStack {
                trailLayer(index: 1, elapsed: elapsed, bounce: bounce)
                trailLayer(index: 2, elapsed: elapsed, bounce: bounce)
                CharacterGrid(elapsed: elapsed)
                    .frame(width: 200, height: 380)
                    .mask { Image(systemName: "figure.run").font(.system(size: 300, weight: .black)).foregroundColor(.black) }
                    .offset(y: bounce)
            }
        }
    }
}

struct CharacterGrid: View {
    let elapsed: Double
    private static let chars: [String] = ["$", "#", ":", ".", "@", "%", "&", "*", "~", ";"]
    var body: some View {
        Canvas { context, size in
            let cellW: CGFloat = 8; let cellH: CGFloat = 12; let fontSize: CGFloat = 11
            let cols = Int(size.width / cellW) + 1; let rows = Int(size.height / cellH) + 1
            var resolved: [GraphicsContext.ResolvedText] = []
            for ch in Self.chars {
                resolved.append(context.resolve(Text(ch).font(.system(size: fontSize, weight: .bold, design: .monospaced)).foregroundColor(.black)))
            }
            let seed = Int(elapsed * 12); let count = Self.chars.count
            for row in 0..<rows {
                for col in 0..<cols {
                    let idx = ((seed + row * 7 + col * 3) % count + count) % count
                    context.draw(resolved[idx], at: CGPoint(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH))
                }
            }
        }
    }
}

// MARK: - Phase 4: Saved

struct SavedPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false
    @State private var showCheck = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundColor(.green)
                        Text(viewModel.selectedMode.savedLabel)
                            .font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.black)
                    }
                    Text(viewModel.selectedMode.savedSubtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 28).padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer()

            savedCard
                .matchedGeometryEffect(id: "card", in: ns)
                .padding(.horizontal, 28)

            Spacer()

            Button(action: { viewModel.viewDashboard() }) {
                HStack(spacing: 8) {
                    Text("View Dashboard").font(.system(size: 17, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Capsule().fill(viewModel.selectedMode.color)).padding(.horizontal, 28)
            }
            .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: appeared)
            .padding(.bottom, 50)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) { showCheck = true }
            }
        }
        .onDisappear { appeared = false }
    }

    @ViewBuilder var savedCard: some View {
        let mode = viewModel.selectedMode
        switch mode {
        case .alarm:
            SavedGenericCard(icon: viewModel.pendingAlarm?.icon ?? "alarm.fill",
                title: viewModel.pendingAlarm?.label ?? "Alarm",
                subtitle: viewModel.pendingAlarm?.time ?? "--:--",
                badge: "ON", badgeColor: .black, showCheck: showCheck)
        case .meeting:
            SavedGenericCard(icon: "briefcase.fill",
                title: viewModel.pendingMeeting?.title ?? "Meeting",
                subtitle: "\(viewModel.pendingMeeting?.date ?? "") · \(viewModel.pendingMeeting?.time ?? "")",
                badge: "SET", badgeColor: .blue, showCheck: showCheck)
        case .mood:
            SavedGenericCard(icon: viewModel.pendingMood?.moodIcon ?? "heart.fill",
                title: viewModel.pendingMood?.mood ?? "Mood",
                subtitle: viewModel.pendingMood?.trigger ?? "",
                badge: "LOGGED", badgeColor: .purple, showCheck: showCheck)
        case .inbox:
            SavedGenericCard(icon: "tray.fill",
                title: "\(viewModel.pendingInbox?.actionItems.count ?? 0) Tasks",
                subtitle: viewModel.pendingInbox?.source ?? "Inbox",
                badge: viewModel.pendingInbox?.priority ?? "—", badgeColor: .orange, showCheck: showCheck)
        case .schedule:
            SavedGenericCard(icon: "calendar",
                title: "\(viewModel.pendingScheduleBlocks?.count ?? 0) Blocks",
                subtitle: "Day planned",
                badge: "SET", badgeColor: .teal, showCheck: showCheck)
        }
    }
}

struct SavedGenericCard: View {
    let icon: String; let title: String; let subtitle: String
    let badge: String; let badgeColor: Color; let showCheck: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(badge).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(badgeColor))
                    Image(systemName: icon).font(.system(size: 28)).foregroundColor(.black.opacity(0.6))
                }
                Spacer()
                if showCheck {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 32)).foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.black)
                Text(subtitle).font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.black)
                    .minimumScaleFactor(0.5).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.08), radius: 20, y: 8))
    }
}

// MARK: - Phase 5: Dashboard

struct DashboardPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false
    @State private var selectedItem: DashboardSelection?

    @Query var alarms: [AlarmItem]
    @Query var meetings: [MeetingItem]
    @Query var moods: [MoodEntry]
    @Query var inboxItems: [InboxItem]
    @Query var scheduleBlocks: [ScheduleBlock]

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.black.opacity(0.35))
                    HStack(spacing: 10) {
                        PixelAvatarView(index: viewModel.selectedAvatar, size: 36)
                        Text(viewModel.userName.isEmpty ? "Dashboard" : viewModel.userName)
                            .font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.black)
                    }
                }
                Spacer()
                Button(action: { viewModel.startNewEntry() }) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 28))
                        .foregroundColor(.black.opacity(0.6))
                }
            }
            .padding(.horizontal, 28).padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: appeared)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 8)

                    // Hero widget
                    heroWidget
                        .frame(width: 200, height: 200)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.9)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

                    // Alarms
                    if !alarms.isEmpty {
                        sectionHeader(title: "Alarms", icon: "alarm.fill", count: alarms.count, delay: 0.15)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(alarms) { alarm in
                                    let isNew = alarm.id == viewModel.pendingItemId
                                    AlarmBentoCard(alarm: alarm, isHighlighted: isNew)
                                        .matchedGeometryEffect(id: isNew ? "card" : "alarm-\(alarm.id)", in: ns)
                                        .onTapGesture { selectedItem = .alarm(alarm) }
                                }
                            }.padding(.horizontal, 28)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
                    }

                    // Meetings
                    if !meetings.isEmpty {
                        sectionHeader(title: "Meetings", icon: "briefcase.fill", count: meetings.count, delay: 0.25)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(meetings) { m in
                                    let isNew = m.id == viewModel.pendingItemId
                                    MeetingBentoCard(meeting: m, isHighlighted: isNew)
                                        .matchedGeometryEffect(id: isNew ? "card" : "meet-\(m.id)", in: ns)
                                        .onTapGesture { selectedItem = .meeting(m) }
                                }
                            }.padding(.horizontal, 28)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: appeared)
                    }

                    // Moods
                    if !moods.isEmpty {
                        sectionHeader(title: "Moods", icon: "heart.fill", count: moods.count, delay: 0.35)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(moods) { m in
                                    let isNew = m.id == viewModel.pendingItemId
                                    MoodBentoCard(mood: m, isHighlighted: isNew)
                                        .matchedGeometryEffect(id: isNew ? "card" : "mood-\(m.id)", in: ns)
                                        .onTapGesture { selectedItem = .mood(m) }
                                }
                            }.padding(.horizontal, 28)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.4), value: appeared)
                    }

                    // Inbox
                    if !inboxItems.isEmpty {
                        sectionHeader(title: "Inbox", icon: "tray.fill", count: inboxItems.count, delay: 0.45)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(inboxItems) { i in
                                    let isNew = i.id == viewModel.pendingItemId
                                    InboxBentoCard(inbox: i, isHighlighted: isNew)
                                        .matchedGeometryEffect(id: isNew ? "card" : "inbox-\(i.id)", in: ns)
                                        .onTapGesture { selectedItem = .inbox(i) }
                                }
                            }.padding(.horizontal, 28)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.5), value: appeared)
                    }

                    // Schedule
                    if !scheduleBlocks.isEmpty {
                        sectionHeader(title: "Schedule", icon: "calendar", count: scheduleBlocks.count, delay: 0.55)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(scheduleBlocks) { block in
                                    let isNew = block.id == viewModel.pendingItemId
                                    ScheduleBentoCard(block: block, isHighlighted: isNew)
                                        .matchedGeometryEffect(id: isNew ? "card" : "sched-\(block.id)", in: ns)
                                }
                            }.padding(.horizontal, 28)
                        }
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.6), value: appeared)
                    }

                    Spacer().frame(height: 20)
                }
            }

            Spacer().frame(height: 40)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .sheet(item: $selectedItem) { item in
            DetailSheet(item: item).presentationDetents([.large]).presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder var heroWidget: some View {
        switch viewModel.lastCreatedMode {
        case .alarm: LargeAnalogClock()
        case .meeting: CalendarMiniWidget()
        case .mood: MoodRingWidget(moods: moods)
        case .inbox: InboxRingWidget(items: inboxItems)
        case .schedule: DayRingWidget(blocks: scheduleBlocks)
        }
    }

    func sectionHeader(title: String, icon: String, count: Int, delay: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12, weight: .medium)).foregroundColor(.black.opacity(0.35))
            Text(title).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.black.opacity(0.5))
            Spacer()
            Text("\(count)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.black.opacity(0.25))
        }
        .padding(.horizontal, 28)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(delay), value: appeared)
    }
}

// MARK: - Bento Cards

struct AlarmBentoCard: View {
    let alarm: AlarmItem; var isHighlighted: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: alarm.icon).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.4))
                Spacer()
                if alarm.streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.system(size: 10)).foregroundColor(.orange)
                        Text("\(alarm.streak)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.orange)
                    }.padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(.orange.opacity(0.12)))
                } else {
                    Text(alarm.isOn ? "ON" : "OFF").font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(alarm.isOn ? .white : .black.opacity(0.4))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(alarm.isOn ? .black : .black.opacity(0.08)))
                }
            }
            Spacer()
            Text(alarm.label).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.5)).lineLimit(1)
            Text(alarm.time).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.black)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Circle().fill(i < alarm.weekHistory.count && alarm.weekHistory[i] ? Color.green : Color.black.opacity(0.08)).frame(width: 6, height: 6)
                }
            }.padding(.top, 2)
        }
        .padding(16).frame(width: 150, height: 160)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: isHighlighted ? .green.opacity(0.15) : .black.opacity(0.06), radius: 12, y: 4))
        .overlay(isHighlighted ? RoundedRectangle(cornerRadius: 20).stroke(.green.opacity(0.3), lineWidth: 2) : nil)
    }
}

struct MeetingBentoCard: View {
    let meeting: MeetingItem; var isHighlighted: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: meeting.icon).font(.system(size: 14, weight: .medium)).foregroundColor(.blue.opacity(0.5))
                Spacer()
                Text(meeting.date).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.blue.opacity(0.6))
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(.blue.opacity(0.1)))
            }
            Spacer()
            Text(meeting.title).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.5)).lineLimit(1)
            Text(meeting.time).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
            HStack(spacing: 4) {
                ForEach(0..<min(meeting.checklist.count, 5), id: \.self) { i in
                    Circle().fill(meeting.checklist[i].isCompleted ? Color.blue : Color.black.opacity(0.08)).frame(width: 6, height: 6)
                }
            }.padding(.top, 2)
        }
        .padding(16).frame(width: 150, height: 160)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: isHighlighted ? .blue.opacity(0.15) : .black.opacity(0.06), radius: 12, y: 4))
        .overlay(isHighlighted ? RoundedRectangle(cornerRadius: 20).stroke(.blue.opacity(0.3), lineWidth: 2) : nil)
    }
}

struct MoodBentoCard: View {
    let mood: MoodEntry; var isHighlighted: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: mood.moodIcon).font(.system(size: 16, weight: .medium)).foregroundColor(mood.moodColor)
                Spacer()
                Text("\(Int(mood.level * 100))%").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(mood.moodColor)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(mood.moodColor.opacity(0.12)))
            }
            Spacer()
            Text(mood.trigger).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4)).lineLimit(1)
            Text(mood.mood).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
            // Mini mood dots
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    Circle().fill(i < mood.weekMoods.count && mood.weekMoods[i] > 0 ? mood.moodColor.opacity(mood.weekMoods[i]) : Color.black.opacity(0.08))
                        .frame(width: 6, height: 6)
                }
            }.padding(.top, 2)
        }
        .padding(16).frame(width: 150, height: 160)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: isHighlighted ? .purple.opacity(0.15) : .black.opacity(0.06), radius: 12, y: 4))
        .overlay(isHighlighted ? RoundedRectangle(cornerRadius: 20).stroke(.purple.opacity(0.3), lineWidth: 2) : nil)
    }
}

struct InboxBentoCard: View {
    let inbox: InboxItem; var isHighlighted: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: inbox.sourceIcon).font(.system(size: 14, weight: .medium)).foregroundColor(.orange.opacity(0.5))
                Spacer()
                Text(inbox.priority).font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(inbox.priority == "High" ? .red : .orange))
            }
            Spacer()
            Text(inbox.source).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
            Text("\(inbox.actionItems.count) items").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
            // Completion dots
            HStack(spacing: 4) {
                ForEach(0..<inbox.actionItems.count, id: \.self) { i in
                    Circle().fill(inbox.actionItems[i].isCompleted ? Color.green : Color.black.opacity(0.08)).frame(width: 6, height: 6)
                }
            }.padding(.top, 2)
        }
        .padding(16).frame(width: 150, height: 160)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: isHighlighted ? .orange.opacity(0.15) : .black.opacity(0.06), radius: 12, y: 4))
        .overlay(isHighlighted ? RoundedRectangle(cornerRadius: 20).stroke(.orange.opacity(0.3), lineWidth: 2) : nil)
    }
}

struct ScheduleBentoCard: View {
    let block: ScheduleBlock; var isHighlighted: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: block.icon).font(.system(size: 14, weight: .medium)).foregroundColor(block.color.opacity(0.6))
                Spacer()
                Text(block.duration).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(block.color)
                    .padding(.horizontal, 6).padding(.vertical, 3).background(Capsule().fill(block.color.opacity(0.12)))
            }
            Spacer()
            Text(block.startTime).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
            Text(block.title).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
            RoundedRectangle(cornerRadius: 2).fill(block.color).frame(height: 4).padding(.top, 4)
        }
        .padding(16).frame(width: 150, height: 160)
        .background(RoundedRectangle(cornerRadius: 20).fill(.white).shadow(color: isHighlighted ? block.color.opacity(0.15) : .black.opacity(0.06), radius: 12, y: 4))
        .overlay(isHighlighted ? RoundedRectangle(cornerRadius: 20).stroke(block.color.opacity(0.3), lineWidth: 2) : nil)
    }
}

// MARK: - Hero Widgets

struct LargeAnalogClock: View {
    @State private var currentTime = Date()
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - 16
            ZStack {
                Circle().stroke(.black.opacity(0.08), lineWidth: 2)
                ForEach(0..<12, id: \.self) { tick in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.black.opacity(tick % 3 == 0 ? 0.6 : 0.2))
                        .frame(width: tick % 3 == 0 ? 2.5 : 1.5, height: tick % 3 == 0 ? 16 : 10)
                        .offset(y: -radius + (tick % 3 == 0 ? 8 : 5))
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                ForEach(0..<60, id: \.self) { tick in
                    if tick % 5 != 0 {
                        Rectangle().fill(.black.opacity(0.08)).frame(width: 0.5, height: 5)
                            .offset(y: -radius + 2.5).rotationEffect(.degrees(Double(tick) * 6))
                    }
                }
                RoundedRectangle(cornerRadius: 2).fill(.black).frame(width: 3, height: radius * 0.45)
                    .offset(y: -radius * 0.225).rotationEffect(hourAngle)
                RoundedRectangle(cornerRadius: 1.5).fill(.black.opacity(0.7)).frame(width: 2, height: radius * 0.65)
                    .offset(y: -radius * 0.325).rotationEffect(minuteAngle)
                Circle().fill(.black).frame(width: 36, height: 36)
                    .overlay(Image(systemName: "bell.fill").font(.system(size: 16, weight: .medium)).foregroundColor(.white))
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in currentTime = t }
    }
    private var minuteAngle: Angle {
        let c = Calendar.current
        return .degrees(Double(c.component(.minute, from: currentTime)) * 6 + Double(c.component(.second, from: currentTime)) * 0.1)
    }
    private var hourAngle: Angle {
        let c = Calendar.current
        return .degrees(Double(c.component(.hour, from: currentTime) % 12) * 30 + Double(c.component(.minute, from: currentTime)) * 0.5)
    }
}

struct CalendarMiniWidget: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("February 2026").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.black.opacity(0.4))
            let days = ["M", "T", "W", "T", "F", "S", "S"]
            let dates = [10, 11, 12, 13, 14, 15, 16]
            let today = Calendar.current.component(.day, from: Date())
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    VStack(spacing: 4) {
                        Text(day).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.3))
                        ZStack {
                            if dates[i] == 14 {
                                Circle().fill(.blue).frame(width: 28, height: 28)
                            } else if dates[i] == today {
                                Circle().stroke(.black.opacity(0.2), lineWidth: 1).frame(width: 28, height: 28)
                            }
                            Text("\(dates[i])").font(.system(size: 13, weight: dates[i] == 14 ? .bold : .medium, design: .rounded))
                                .foregroundColor(dates[i] == 14 ? .white : .black.opacity(0.6))
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                Circle().fill(.blue).frame(width: 6, height: 6)
                Text("Interview").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.05), radius: 12, y: 4))
    }
}

struct MoodRingWidget: View {
    let moods: [MoodEntry]

    var body: some View {
        let weekData: [Double] = {
            guard let latest = moods.first else { return Array(repeating: 0, count: 7) }
            return Array(latest.weekMoods.prefix(7)) + Array(repeating: 0, count: max(0, 7 - latest.weekMoods.count))
        }()

        ZStack {
            ForEach(0..<7, id: \.self) { i in
                let start = Double(i) / 7.0
                let end = Double(i) / 7.0 + 1.0 / 7.0 - 0.01
                Circle()
                    .trim(from: start, to: end)
                    .stroke(moodColor(weekData[i]), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Image(systemName: moods.first?.moodIcon ?? "heart.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(moods.first?.moodColor ?? .purple)
                Text(moods.first?.mood ?? "—")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.black.opacity(0.5))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.05), radius: 12, y: 4))
    }

    private func moodColor(_ level: Double) -> Color {
        if level <= 0 { return Color.black.opacity(0.06) }
        if level >= 0.7 { return .green }
        if level >= 0.5 { return .yellow }
        if level >= 0.3 { return .orange }
        return .red
    }
}

struct InboxRingWidget: View {
    let items: [InboxItem]
    var body: some View {
        let total = items.reduce(0) { $0 + $1.actionItems.count }
        let done = items.reduce(0) { $0 + $1.completedCount }
        let progress = total > 0 ? Double(done) / Double(total) : 0

        ZStack {
            Circle().stroke(.black.opacity(0.06), lineWidth: 14).frame(width: 140, height: 140)
            Circle().trim(from: 0, to: progress)
                .stroke(.orange, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 140, height: 140).rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(done)/\(total)").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
                Text("done").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.05), radius: 12, y: 4))
    }
}

struct DayRingWidget: View {
    let blocks: [ScheduleBlock]
    var body: some View {
        let count = max(blocks.count, 1)
        ZStack {
            ForEach(Array(blocks.enumerated()), id: \.element.id) { i, block in
                let start = Double(i) / Double(count)
                let end = Double(i + 1) / Double(count) - 0.015
                Circle()
                    .trim(from: start, to: end)
                    .stroke(block.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 2) {
                Text("\(blocks.count)").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.black)
                Text("blocks").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 24).fill(.white).shadow(color: .black.opacity(0.05), radius: 12, y: 4))
    }
}

// MARK: - Detail Sheets

struct DetailSheet: View {
    let item: DashboardSelection
    var body: some View {
        switch item {
        case .alarm(let a): AlarmDetailSheet(alarm: a)
        case .meeting(let m): MeetingDetailSheet(meeting: m)
        case .mood(let m): MoodDetailSheet(mood: m)
        case .inbox(let i): InboxDetailSheet(inbox: i)
        }
    }
}

struct AlarmDetailSheet: View {
    let alarm: AlarmItem
    @State private var routineSteps: [RoutineStep]
    init(alarm: AlarmItem) { self.alarm = alarm; self._routineSteps = State(initialValue: alarm.routine) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Capsule().fill(.black.opacity(0.15)).frame(width: 36, height: 5).padding(.top, 12)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: alarm.icon).font(.system(size: 20, weight: .medium)).foregroundColor(.black.opacity(0.5))
                            Text(alarm.label).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.black)
                        }
                        Text(alarm.time + " AM").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                    }
                    Spacer()
                    if alarm.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill").font(.system(size: 14)).foregroundColor(.orange)
                            Text("\(alarm.streak)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.orange)
                        }.padding(.horizontal, 10).padding(.vertical, 6).background(Capsule().fill(.orange.opacity(0.12)))
                    }
                }.padding(.horizontal, 24)

                HStack(spacing: 12) {
                    StatCard(value: "\(alarm.streak)", label: "Streak", icon: "flame.fill", color: .orange)
                    StatCard(value: "\(alarm.bestStreak)", label: "Best", icon: "trophy.fill", color: .yellow)
                    StatCard(value: "\(Int(alarm.completionRate * 100))%", label: "Rate", icon: "chart.bar.fill", color: .green)
                }.padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("INSIGHTS").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.black.opacity(0.3))
                    InsightRow(icon: "clock.arrow.circlepath", label: "Avg wake time",
                        value: alarm.avgWakeDeviation < 0 ? "\(abs(alarm.avgWakeDeviation)) min early" : alarm.avgWakeDeviation == 0 ? "On time" : "\(alarm.avgWakeDeviation) min late",
                        color: alarm.avgWakeDeviation <= 0 ? .green : (alarm.avgWakeDeviation <= 5 ? .orange : .red))
                    InsightRow(icon: "zzz", label: "Snooze rate", value: "\(Int(alarm.snoozeRate * 100))%",
                        color: alarm.snoozeRate < 0.15 ? .green : (alarm.snoozeRate < 0.3 ? .orange : .red))
                    InsightRow(icon: "checkmark.circle", label: "Total completions", value: "\(alarm.totalCompletions) days", color: .blue)
                }.padding(20).background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2)).padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("THIS MONTH").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.black.opacity(0.3))
                    MonthHeatmap(history: alarm.monthHistory)
                }.padding(20).background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2)).padding(.horizontal, 24)

                if !routineSteps.isEmpty {
                    ChecklistSection(title: "ROUTINE", steps: $routineSteps)
                        .padding(.horizontal, 24)
                }
                Spacer().frame(height: 20)
            }
        }.background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }
}

struct MeetingDetailSheet: View {
    let meeting: MeetingItem
    @State private var steps: [RoutineStep]
    init(meeting: MeetingItem) { self.meeting = meeting; self._steps = State(initialValue: meeting.checklist) }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Capsule().fill(.black.opacity(0.15)).frame(width: 36, height: 5).padding(.top, 12)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: meeting.icon).font(.system(size: 20, weight: .medium)).foregroundColor(.blue.opacity(0.5))
                            Text(meeting.title).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.black)
                        }
                        Text("\(meeting.date) · \(meeting.time)").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                    }
                    Spacer()
                }.padding(.horizontal, 24)

                if !meeting.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTES").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.black.opacity(0.3))
                        Text(meeting.notes).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.6))
                    }.padding(20).background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2)).padding(.horizontal, 24)
                }

                if !steps.isEmpty {
                    ChecklistSection(title: "PREP CHECKLIST", steps: $steps).padding(.horizontal, 24)
                }
                Spacer().frame(height: 20)
            }
        }.background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }
}

struct MoodDetailSheet: View {
    let mood: MoodEntry
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Capsule().fill(.black.opacity(0.15)).frame(width: 36, height: 5).padding(.top, 12)
                HStack {
                    Image(systemName: mood.moodIcon).font(.system(size: 32, weight: .medium)).foregroundColor(mood.moodColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mood.mood).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.black)
                        Text("Level: \(Int(mood.level * 100))%").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                    }
                    Spacer()
                }.padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("DETAILS").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.black.opacity(0.3))
                    InsightRow(icon: "exclamationmark.triangle", label: "Trigger", value: mood.trigger, color: .orange)
                    InsightRow(icon: "lightbulb.fill", label: "Suggestion", value: mood.suggestion, color: .green)
                }.padding(20).background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2)).padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("THIS WEEK").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.black.opacity(0.3))
                    HStack(spacing: 12) {
                        let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
                        ForEach(Array(dayLabels.enumerated()), id: \.offset) { i, day in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(i < mood.weekMoods.count && mood.weekMoods[i] > 0 ? mood.moodColor.opacity(mood.weekMoods[i]) : Color.black.opacity(0.05))
                                    .frame(width: 28, height: 28)
                                Text(day).font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.3))
                            }
                        }
                    }
                }.padding(20).background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2)).padding(.horizontal, 24)

                Spacer().frame(height: 20)
            }
        }.background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }
}

struct InboxDetailSheet: View {
    let inbox: InboxItem
    @State private var steps: [RoutineStep]
    init(inbox: InboxItem) { self.inbox = inbox; self._steps = State(initialValue: inbox.actionItems) }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Capsule().fill(.black.opacity(0.15)).frame(width: 36, height: 5).padding(.top, 12)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: inbox.sourceIcon).font(.system(size: 20, weight: .medium)).foregroundColor(.orange.opacity(0.5))
                            Text(inbox.source).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.black)
                        }
                        Text("Priority: \(inbox.priority)").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
                    }
                    Spacer()
                }.padding(.horizontal, 24)

                if !steps.isEmpty {
                    ChecklistSection(title: "ACTION ITEMS", steps: $steps).padding(.horizontal, 24)
                }
                Spacer().frame(height: 20)
            }
        }.background(Color(red: 0.96, green: 0.96, blue: 0.97))
    }
}

// MARK: - Shared Components

struct ChecklistSection: View {
    let title: String
    @Binding var steps: [RoutineStep]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundColor(.black.opacity(0.3))
                Spacer()
                let done = steps.filter(\.isCompleted).count
                Text("\(done)/\(steps.count)").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.black.opacity(0.3))
            }
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { steps[index].isCompleted.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: step.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20)).foregroundColor(step.isCompleted ? .green : .black.opacity(0.2))
                        Image(systemName: step.icon).font(.system(size: 14, weight: .medium)).foregroundColor(.black.opacity(0.4)).frame(width: 24)
                        Text(step.title).font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(step.isCompleted ? .black.opacity(0.3) : .black).strikethrough(step.isCompleted)
                        Spacer()
                        Text(step.duration).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.3))
                    }.padding(.vertical, 8)
                }
                if index < steps.count - 1 { Divider().opacity(0.3) }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
    }
}

struct StatCard: View {
    let value: String; let label: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 16)).foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundColor(.black)
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.4))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white).shadow(color: .black.opacity(0.04), radius: 8, y: 2))
    }
}

struct InsightRow: View {
    let icon: String; let label: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(color).frame(width: 24)
            Text(label).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.6))
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(color)
        }
    }
}

struct MonthHeatmap: View {
    let history: [Double]
    var body: some View {
        let cols = 7; let rows = Int(ceil(Double(max(history.count, 1)) / Double(cols)))
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                let days = ["M", "T", "W", "T", "F", "S", "S"]
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    Text(day).font(.system(size: 9, weight: .medium, design: .rounded)).foregroundColor(.black.opacity(0.3)).frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<cols, id: \.self) { col in
                        let index = row * cols + col
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index < history.count ? heatColor(history[index]) : .clear)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
    private func heatColor(_ value: Double) -> Color {
        if value >= 0.9 { return Color.green.opacity(0.7) }
        if value >= 0.5 { return Color.green.opacity(0.35) }
        if value > 0 { return Color.green.opacity(0.15) }
        return Color.black.opacity(0.05)
    }
}

struct DotMatrixTime: View {
    let time: String
    static let digitPatterns: [Character: [[Bool]]] = [
        "0": [[false,true,true,true,false],[true,false,false,false,true],[true,false,false,true,true],[true,false,true,false,true],[true,true,false,false,true],[true,false,false,false,true],[false,true,true,true,false]],
        "1": [[false,false,true,false,false],[false,true,true,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,true,true,true,false]],
        "2": [[false,true,true,true,false],[true,false,false,false,true],[false,false,false,false,true],[false,false,true,true,false],[false,true,false,false,false],[true,false,false,false,false],[true,true,true,true,true]],
        "3": [[false,true,true,true,false],[true,false,false,false,true],[false,false,false,false,true],[false,false,true,true,false],[false,false,false,false,true],[true,false,false,false,true],[false,true,true,true,false]],
        "4": [[false,false,false,true,false],[false,false,true,true,false],[false,true,false,true,false],[true,false,false,true,false],[true,true,true,true,true],[false,false,false,true,false],[false,false,false,true,false]],
        "5": [[true,true,true,true,true],[true,false,false,false,false],[true,true,true,true,false],[false,false,false,false,true],[false,false,false,false,true],[true,false,false,false,true],[false,true,true,true,false]],
        "6": [[false,true,true,true,false],[true,false,false,false,false],[true,false,false,false,false],[true,true,true,true,false],[true,false,false,false,true],[true,false,false,false,true],[false,true,true,true,false]],
        "7": [[true,true,true,true,true],[false,false,false,false,true],[false,false,false,true,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,true,false,false]],
        "8": [[false,true,true,true,false],[true,false,false,false,true],[true,false,false,false,true],[false,true,true,true,false],[true,false,false,false,true],[true,false,false,false,true],[false,true,true,true,false]],
        "9": [[false,true,true,true,false],[true,false,false,false,true],[true,false,false,false,true],[false,true,true,true,true],[false,false,false,false,true],[false,false,false,false,true],[false,true,true,true,false]],
        ":": [[false,false,false,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,false,false,false],[false,false,true,false,false],[false,false,true,false,false],[false,false,false,false,false]],
    ]
    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 5; let dotSpacing: CGFloat = 9; let charGap: CGFloat = 14
            let chars = Array(time)
            let totalWidth = CGFloat(chars.count) * (5 * dotSpacing + charGap) - charGap
            var offsetX = (size.width - totalWidth) / 2
            for char in chars {
                guard let pattern = Self.digitPatterns[char] else { offsetX += 3 * dotSpacing + charGap; continue }
                for (row, rowData) in pattern.enumerated() {
                    for (col, isOn) in rowData.enumerated() {
                        if isOn {
                            let rect = CGRect(x: offsetX + CGFloat(col) * dotSpacing - dotSize / 2, y: CGFloat(row) * dotSpacing, width: dotSize, height: dotSize)
                            context.fill(RoundedRectangle(cornerRadius: 1.5).path(in: rect), with: .color(.black.opacity(0.06)))
                        }
                    }
                }
                offsetX += 5 * dotSpacing + charGap
            }
        }.frame(height: 7 * 9)
    }
}

// MARK: - Previews

#Preview("Full App") {
    ContentView()
}
