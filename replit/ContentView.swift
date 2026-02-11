//
//  ContentView.swift
//  replit
//
//  Arc Search / Unified Interface Prototype
//  Light theme, dot-matrix aesthetic matching reference video
//

import SwiftUI
import Combine

// MARK: - Data Models

enum AppPhase: Equatable {
    case voiceInput
    case processing
    case feedback
    case alarmManagement
    case unifiedChat
}

struct AlarmItem: Identifiable {
    let id = UUID()
    let label: String
    let time: String
    var isOn: Bool
    let icon: String
}

// MARK: - App State

class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .voiceInput
    @Published var transcriptionProgress: Int = 0
    @Published var isPaused: Bool = false
    @Published var processingProgress: Double = 0

    let transcriptionWords = ["Create", "Alarm", "to", "9:45", "AM", "Today"]

    var alarms: [AlarmItem] = [
        AlarmItem(label: "Walking the dog", time: "07:30", isOn: false, icon: "figure.walk"),
        AlarmItem(label: "Morning Run", time: "09:45", isOn: true, icon: "figure.run"),
        AlarmItem(label: "Team standup", time: "10:00", isOn: true, icon: "person.3.fill"),
        AlarmItem(label: "Lunch break", time: "12:30", isOn: false, icon: "fork.knife"),
    ]

    private var transcriptionTimer: Timer?
    private var phaseTimer: Timer?
    private var processingTimer: Timer?

    func startDemo() {
        transcriptionProgress = 0
        phase = .voiceInput
        isPaused = false
        processingProgress = 0
        startTranscription()
    }

    func startTranscription() {
        transcriptionTimer?.invalidate()
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] timer in
            guard let self = self, !self.isPaused else { return }
            if self.transcriptionProgress < self.transcriptionWords.count {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.transcriptionProgress += 1
                }
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        self.phase = .processing
                    }
                    self.startProcessing()
                }
            }
        }
    }

    func startProcessing() {
        processingProgress = 0
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            self.processingProgress += 0.01
            if self.processingProgress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                        self.phase = .feedback
                    }
                    self.scheduleAlarmManagement()
                }
            }
        }
    }

    func togglePause() {
        isPaused.toggle()
    }

    func stopAndReset() {
        transcriptionTimer?.invalidate()
        phaseTimer?.invalidate()
        processingTimer?.invalidate()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            phase = .voiceInput
            transcriptionProgress = 0
            isPaused = false
            processingProgress = 0
        }
    }

    private func scheduleAlarmManagement() {
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                self?.phase = .alarmManagement
            }
            self?.scheduleUnifiedChat()
        }
    }

    private func scheduleUnifiedChat() {
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
                self?.phase = .unifiedChat
            }
        }
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Namespace private var hero

    var body: some View {
        ZStack {
            // Light background
            Color(red: 0.96, green: 0.96, blue: 0.97)
                .ignoresSafeArea()

            DotGridBackground()

            switch viewModel.phase {
            case .voiceInput:
                VoiceInputPhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .processing:
                ProcessingPhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity)

            case .feedback:
                FeedbackPhase(viewModel: viewModel, ns: hero)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .alarmManagement:
                AlarmManagementPhase(viewModel: viewModel, ns: hero)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 30)),
                        removal: .opacity
                    ))

            case .unifiedChat:
                UnifiedChatPhase(ns: hero)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            viewModel.startDemo()
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
                    let rect = CGRect(
                        x: x - dotRadius, y: y - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.black.opacity(0.12))
                    )
                    y += spacing
                }
                x += spacing
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Phase 1: Voice Input

struct VoiceInputPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Transcription text - left aligned, large, bold
            VStack(alignment: .leading, spacing: 0) {
                TranscriptionText(
                    words: viewModel.transcriptionWords,
                    progress: viewModel.transcriptionProgress
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 140)
            .matchedGeometryEffect(id: "card", in: ns)
            .padding(.horizontal, 28)

            Spacer()

            // Waveform visualizer
            BarWaveform(isActive: !viewModel.isPaused)
                .frame(height: 60)
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            Spacer().frame(height: 20)

            // Control bar: red stop, yellow pause, camera
            ControlBar(viewModel: viewModel)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

            Spacer().frame(height: 40)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

// MARK: - Transcription Text (blur-to-clear reveal)

struct TranscriptionText: View {
    let words: [String]
    let progress: Int

    private var visibleText: String {
        words.prefix(progress).joined(separator: " ")
    }

    var body: some View {
        Text(visibleText)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundColor(.black)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: progress)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bar Waveform (vertical bars, like audio timeline)

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
                    context.fill(
                        RoundedRectangle(cornerRadius: barWidth / 2).path(in: rect),
                        with: .color(.black.opacity(0.7))
                    )
                }
            }
        }
    }
}

// MARK: - Control Bar (red stop, yellow pause, camera)

struct ControlBar: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Red stop button (left)
            Button(action: { viewModel.stopAndReset() }) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 14, height: 14)
                    )
            }

            Spacer()

            // Yellow pause pill (center)
            Button(action: { viewModel.togglePause() }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.yellow))
            }

            Spacer()

            // Camera icon (right)
            Button(action: {}) {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                    )
            }
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Phase 2: Processing (ASCII Runner)

struct ProcessingPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var startDate = Date()
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // "Creating Alarm" top-left
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Creating Alarm")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("Processing...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            // Large ASCII runner - fills available space
            ASCIIRunnerCanvas(startDate: startDate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .matchedGeometryEffect(id: "card", in: ns)
                .padding(.horizontal, 10)

            // Grey pause pill during processing
            HStack(spacing: 6) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Pause")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.black.opacity(0.5))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.06)))
            .padding(.bottom, 50)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.3), value: appeared)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

// MARK: - ASCII Runner Canvas (SF Symbol mask + character grid)

struct ASCIIRunnerCanvas: View {
    let startDate: Date

    @ViewBuilder
    private func trailLayer(index: Int, elapsed: Double, bounce: Double) -> some View {
        let i = CGFloat(index)
        CharacterGrid(elapsed: elapsed - Double(index) * 0.06)
            .frame(width: 200, height: 380)
            .mask {
                Image(systemName: "figure.run")
                    .font(.system(size: 300, weight: .black))
                    .foregroundColor(.black)
            }
            .offset(x: -i * 14, y: CGFloat(bounce) + i * 2)
            .opacity(0.12 * Double(4 - index) / 3.0)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 8.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let bounce = sin(elapsed * 8) * 3

            ZStack {
                // Trail ghosts
                trailLayer(index: 1, elapsed: elapsed, bounce: bounce)
                trailLayer(index: 2, elapsed: elapsed, bounce: bounce)

                // Main figure
                CharacterGrid(elapsed: elapsed)
                    .frame(width: 200, height: 380)
                    .mask {
                        Image(systemName: "figure.run")
                            .font(.system(size: 300, weight: .black))
                            .foregroundColor(.black)
                    }
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
            let cellW: CGFloat = 8
            let cellH: CGFloat = 12
            let fontSize: CGFloat = 11
            let cols = Int(size.width / cellW) + 1
            let rows = Int(size.height / cellH) + 1

            var resolved: [GraphicsContext.ResolvedText] = []
            for ch in Self.chars {
                resolved.append(context.resolve(
                    Text(ch)
                        .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                ))
            }

            let seed = Int(elapsed * 12)
            for row in 0..<rows {
                for col in 0..<cols {
                    let idx = (seed + row * 7 + col * 3) % Self.chars.count
                    context.draw(resolved[idx], at: CGPoint(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH))
                }
            }
        }
    }
}

// MARK: - Phase 3: Feedback (Alarm Card appears from runner)

struct FeedbackPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false
    @State private var alarmOn = true

    var body: some View {
        VStack(spacing: 0) {
            // "Creating Alarm" header persists
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Alarm Created")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("Ready")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)

            Spacer()

            // Alarm card - white, clean
            FeedbackAlarmCard(isOn: $alarmOn)
                .matchedGeometryEffect(id: "card", in: ns)
                .padding(.horizontal, 28)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1), value: appeared)

            Spacer()
            Spacer()
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

struct FeedbackAlarmCard: View {
    @Binding var isOn: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    // ON badge
                    Text("ON")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black))

                    // Alarm icon
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.black.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Run")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.5))

                Text("09:45")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.white)
                .shadow(color: .black.opacity(0.08), radius: 20, y: 8)
        )
    }
}

// MARK: - Phase 4: Alarm Management (Bento Grid)

struct AlarmManagementPhase: View {
    @ObservedObject var viewModel: AppViewModel
    var ns: Namespace.ID
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text("Alarm")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black.opacity(0.3))
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: appeared)

            Spacer().frame(height: 24)

            // Large analog clock with bell center
            LargeAnalogClock()
                .frame(width: 240, height: 240)
                .matchedGeometryEffect(id: "card", in: ns)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

            Spacer().frame(height: 24)

            // Dot matrix time behind
            DotMatrixTime(time: "06:42")
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

            Spacer().frame(height: 24)

            // Bento grid alarm cards - horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.alarms.enumerated()), id: \.element.id) { index, alarm in
                        AlarmBentoCard(alarm: alarm)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(0.2 + Double(index) * 0.08),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, 28)
            }

            Spacer()

            // AI Dock at bottom
            AIDock()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: appeared)
                .padding(.bottom, 40)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

// MARK: - Alarm Bento Card

struct AlarmBentoCard: View {
    let alarm: AlarmItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: alarm.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
                Spacer()
                Text(alarm.isOn ? "ON" : "OFF")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(alarm.isOn ? .white : .black.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(alarm.isOn ? .black : .black.opacity(0.08))
                    )
            }

            Spacer()

            Text(alarm.label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.black.opacity(0.5))
                .lineLimit(1)

            Text(alarm.time)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.black)
        }
        .padding(16)
        .frame(width: 150, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }
}

// MARK: - Large Analog Clock (with bell center)

struct LargeAnalogClock: View {
    @State private var currentTime = Date()

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size / 2 - 16

            ZStack {
                // Outer circle
                Circle()
                    .stroke(.black.opacity(0.08), lineWidth: 2)

                // Hour ticks
                ForEach(0..<12, id: \.self) { tick in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(.black.opacity(tick % 3 == 0 ? 0.6 : 0.2))
                        .frame(width: tick % 3 == 0 ? 2.5 : 1.5, height: tick % 3 == 0 ? 16 : 10)
                        .offset(y: -radius + (tick % 3 == 0 ? 8 : 5))
                        .rotationEffect(.degrees(Double(tick) * 30))
                }

                // Minute ticks
                ForEach(0..<60, id: \.self) { tick in
                    if tick % 5 != 0 {
                        Rectangle()
                            .fill(.black.opacity(0.08))
                            .frame(width: 0.5, height: 5)
                            .offset(y: -radius + 2.5)
                            .rotationEffect(.degrees(Double(tick) * 6))
                    }
                }

                // Hour hand
                RoundedRectangle(cornerRadius: 2)
                    .fill(.black)
                    .frame(width: 3, height: radius * 0.45)
                    .offset(y: -radius * 0.225)
                    .rotationEffect(hourAngle)

                // Minute hand
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.black.opacity(0.7))
                    .frame(width: 2, height: radius * 0.65)
                    .offset(y: -radius * 0.325)
                    .rotationEffect(minuteAngle)

                // Center: Bell icon in black circle
                Circle()
                    .fill(.black)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in
            currentTime = t
        }
    }

    private var minuteAngle: Angle {
        let c = Calendar.current
        return .degrees(Double(c.component(.minute, from: currentTime)) * 6 +
                        Double(c.component(.second, from: currentTime)) * 0.1)
    }

    private var hourAngle: Angle {
        let c = Calendar.current
        return .degrees(Double(c.component(.hour, from: currentTime) % 12) * 30 +
                        Double(c.component(.minute, from: currentTime)) * 0.5)
    }
}

// MARK: - Phase 5: Unified Chat Interface

struct UnifiedChatPhase: View {
    var ns: Namespace.ID
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("Unified Chat\nInterface")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 15)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: appeared)

                Text("All your AI models in one place")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.4))
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)
            }
            .matchedGeometryEffect(id: "card", in: ns)

            Spacer().frame(height: 50)

            // AI model icons grid
            HStack(spacing: 20) {
                AIModelIcon(icon: "circle", label: "GPT")
                AIModelIcon(icon: "sparkle", label: "Gemini")
                AIModelIcon(icon: "brain.head.profile", label: "Claude")
                AIModelIcon(icon: "asterisk", label: "Grok")
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

            Spacer().frame(height: 30)

            HStack(spacing: 20) {
                AIModelIcon(icon: "waveform", label: "Whisper")
                AIModelIcon(icon: "eye.fill", label: "Vision")
                AIModelIcon(icon: "text.bubble.fill", label: "LLaMA")
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)

            Spacer()

            // Search bar at bottom
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.black.opacity(0.3))
                Text("Ask anything...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.3))
                Spacer()
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

struct AIModelIcon: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.white)
                .frame(width: 56, height: 56)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black.opacity(0.6))
                )
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.black.opacity(0.4))
        }
    }
}

// MARK: - Dot Matrix Time

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
            let dotSize: CGFloat = 5
            let dotSpacing: CGFloat = 9
            let charGap: CGFloat = 14
            let chars = Array(time)
            let totalWidth = CGFloat(chars.count) * (5 * dotSpacing + charGap) - charGap
            var offsetX = (size.width - totalWidth) / 2

            for char in chars {
                guard let pattern = Self.digitPatterns[char] else {
                    offsetX += 3 * dotSpacing + charGap
                    continue
                }
                for (row, rowData) in pattern.enumerated() {
                    for (col, isOn) in rowData.enumerated() {
                        if isOn {
                            let rect = CGRect(
                                x: offsetX + CGFloat(col) * dotSpacing - dotSize / 2,
                                y: CGFloat(row) * dotSpacing,
                                width: dotSize, height: dotSize
                            )
                            context.fill(
                                RoundedRectangle(cornerRadius: 1.5).path(in: rect),
                                with: .color(.black.opacity(0.06))
                            )
                        }
                    }
                }
                offsetX += 5 * dotSpacing + charGap
            }
        }
        .frame(height: 7 * 9)
    }
}

// MARK: - AI Dock

struct AIDock: View {
    var body: some View {
        HStack(spacing: 16) {
            DockIcon {
                Circle()
                    .stroke(.black.opacity(0.3), lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
            DockIcon {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
            }
            DockIcon {
                Image(systemName: "asterisk")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
            }
            DockIcon {
                Image(systemName: "brain")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
            }
            DockIcon {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black.opacity(0.4))
            }
        }
    }
}

struct DockIcon<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .frame(width: 48, height: 48)
            .background(
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            )
    }
}

// MARK: - Previews

#Preview("Full App") {
    ContentView()
}

struct DashboardPreviewWrapper: View {
    @Namespace private var ns
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97).ignoresSafeArea()
            DotGridBackground()
            AlarmManagementPhase(viewModel: AppViewModel(), ns: ns)
        }
    }
}

#Preview("Alarm Management") {
    DashboardPreviewWrapper()
}
