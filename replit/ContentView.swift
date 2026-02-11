//
//  ContentView.swift
//  replit
//
//  Arc Search / Unified Interface Prototype
//  Minimalist, monochrome, dot-matrix aesthetic
//

import SwiftUI
import Combine

// MARK: - Data Models

enum AppPhase: Equatable {
    case voiceInput
    case processing
    case dashboard
}

// MARK: - App State

class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .voiceInput
    @Published var transcriptionProgress: Int = 0
    @Published var isPaused: Bool = false

    let transcriptionWords = ["Create", "Alarm", "to", "9:45", "AM", "Today"]

    private var transcriptionTimer: Timer?
    private var phaseTimer: Timer?

    func startDemo() {
        transcriptionProgress = 0
        phase = .voiceInput
        isPaused = false
        startTranscription()
    }

    func startTranscription() {
        transcriptionTimer?.invalidate()
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] timer in
            guard let self = self, !self.isPaused else { return }
            if self.transcriptionProgress < self.transcriptionWords.count {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.transcriptionProgress += 1
                }
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.phase = .processing
                    }
                    self.scheduleTransitionToDashboard()
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
        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .voiceInput
            transcriptionProgress = 0
            isPaused = false
        }
    }

    private func scheduleTransitionToDashboard() {
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.8)) {
                self?.phase = .dashboard
            }
        }
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @Namespace private var heroAnimation

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            DotGridBackground()

            switch viewModel.phase {
            case .voiceInput:
                VoiceInputPhase(viewModel: viewModel, namespace: heroAnimation)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

            case .processing:
                ASCIIRunnerPhase(namespace: heroAnimation)
                    .transition(.opacity)

            case .dashboard:
                DashboardPhase(namespace: heroAnimation)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .preferredColorScheme(.dark)
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
            let color = Color.gray.opacity(0.2)

            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let rect = CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Circle().path(in: rect), with: .color(color))
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
    var namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Matched geometry container with consistent sizing
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.clear)
                .frame(height: 80)
                .overlay {
                    TranscriptionText(
                        words: viewModel.transcriptionWords,
                        progress: viewModel.transcriptionProgress
                    )
                }
                .matchedGeometryEffect(id: "card", in: namespace)
                .padding(.horizontal, 30)

            Spacer()

            // Audio waveform
            WaveformView(isActive: !viewModel.isPaused)
                .frame(height: 60)
                .padding(.horizontal, 30)
                .padding(.bottom, 20)

            // Control bar
            ControlBar(viewModel: viewModel)
                .padding(.bottom, 40)
        }
    }
}

struct TranscriptionText: View {
    let words: [String]
    let progress: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<words.count, id: \.self) { index in
                if index < progress {
                    Text(words[index])
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .transition(.opacity.combined(with: .scale(scale: 0.7)))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
    }
}

// MARK: - Waveform

struct WaveformBarConfig: Identifiable {
    let id: Int
    let speed: Double
    let baseHeight: CGFloat
    let maxHeight: CGFloat
}

struct WaveformView: View {
    let isActive: Bool

    @State private var bars: [WaveformBarConfig] = (0..<24).map { i in
        WaveformBarConfig(
            id: i,
            speed: Double.random(in: 0.3...0.7),
            baseHeight: CGFloat.random(in: 8...20),
            maxHeight: CGFloat.random(in: 30...55)
        )
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(bars) { bar in
                WaveformBar(
                    isActive: isActive,
                    speed: bar.speed,
                    baseHeight: bar.baseHeight,
                    maxHeight: bar.maxHeight
                )
            }
        }
    }
}

struct WaveformBar: View {
    let isActive: Bool
    let speed: Double
    let baseHeight: CGFloat
    let maxHeight: CGFloat

    @State private var animating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.6))
            .frame(width: 4, height: animating && isActive ? maxHeight : baseHeight)
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .easeInOut(duration: speed)
                    .repeatForever(autoreverses: true)
                ) {
                    animating = true
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(
                        .easeInOut(duration: speed)
                        .repeatForever(autoreverses: true)
                    ) {
                        animating = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        animating = false
                    }
                }
            }
    }
}

struct ControlBar: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.togglePause() }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.yellow)
                .clipShape(Capsule())
            }

            Button(action: { viewModel.stopAndReset() }) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("Stop")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Phase 2: ASCII Runner

struct ASCIIRunnerPhase: View {
    var namespace: Namespace.ID
    @State private var startDate = Date()
    @State private var pulsingDots = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Processing...")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 20)

            ASCIIRunnerCanvas(startDate: startDate)
                .frame(height: 200)
                .matchedGeometryEffect(id: "card", in: namespace)
                .padding(.horizontal, 30)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulsingDots ? 1.4 : 0.6)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: pulsingDots
                        )
                }
            }
            .padding(.bottom, 60)
            .onAppear { pulsingDots = true }
        }
    }
}

struct ASCIIRunnerCanvas: View {
    let startDate: Date

    static let runFrames: [[String]] = [
        ["   O   ", "  /|\\  ", "  / \\  ", " /   \\ "],
        ["   O   ", "  \\|/  ", "   |   ", "  / \\  "],
        ["   O   ", "   |\\  ", "  /|   ", "  | \\  "],
        ["   O   ", "  /|   ", "   |\\  ", "  / |  "],
        ["   O   ", "  \\|\\  ", "   |   ", "  / \\  "],
        ["   O   ", "  /|/  ", "   |   ", "  / \\  "],
    ]

    static let asciiChars: [String] = ["$", "#", ":", ".", "@", "%", "&", "*", "~"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
            Canvas { context, size in
                drawRunner(context: &context, size: size, date: timeline.date)
            }
        }
    }

    private func drawRunner(context: inout GraphicsContext, size: CGSize, date: Date) {
        let elapsed: Double = date.timeIntervalSince(startDate)
        let charSize: CGFloat = 16
        let charWidth: CGFloat = charSize * 0.65
        let charHeight: CGFloat = charSize * 1.1
        let centerX: CGFloat = size.width / 2
        let centerY: CGFloat = size.height / 2

        // Pre-resolve main characters
        let resolvedMain: [String: GraphicsContext.ResolvedText] = resolveChars(
            context: &context, size: charSize, weight: .bold, opacity: 1.0
        )

        // Draw main runner
        let frameIndex: Int = Int(elapsed * 8) % Self.runFrames.count
        let frame: [String] = Self.runFrames[frameIndex]
        drawFrame(
            context: &context, frame: frame, resolved: resolvedMain,
            elapsed: elapsed, centerX: centerX, centerY: centerY,
            charWidth: charWidth, charHeight: charHeight,
            offsetX: 0, jitter: 0, charIndexOffset: 0, useMainIndex: true
        )

        // Draw ghost trail
        let trailCharSize: CGFloat = charSize * 0.8
        let trailCount: Int = 20
        for i in 0..<trailCount {
            let fade: Double = max(0, 1.0 - Double(i) / Double(trailCount)) * 0.4
            let resolvedTrail: [String: GraphicsContext.ResolvedText] = resolveChars(
                context: &context, size: trailCharSize, weight: .regular, opacity: fade
            )
            let age: Double = elapsed + Double(i) * 0.15
            let trailFrameIndex: Int = Int(age * 8) % Self.runFrames.count
            let trailFrame: [String] = Self.runFrames[trailFrameIndex]
            let jitter: Double = sin(age * 3 + Double(i)) * 3
            drawFrame(
                context: &context, frame: trailFrame, resolved: resolvedTrail,
                elapsed: elapsed, centerX: centerX, centerY: centerY,
                charWidth: charWidth, charHeight: charHeight,
                offsetX: CGFloat(i) * -12, jitter: CGFloat(jitter),
                charIndexOffset: i, useMainIndex: false
            )
        }
    }

    private func resolveChars(
        context: inout GraphicsContext, size: CGFloat, weight: Font.Weight, opacity: Double
    ) -> [String: GraphicsContext.ResolvedText] {
        var result: [String: GraphicsContext.ResolvedText] = [:]
        for ch in Self.asciiChars {
            let text = Text(ch)
                .font(.system(size: size, weight: weight, design: .monospaced))
                .foregroundColor(.white.opacity(opacity))
            result[ch] = context.resolve(text)
        }
        return result
    }

    private func drawFrame(
        context: inout GraphicsContext,
        frame: [String],
        resolved: [String: GraphicsContext.ResolvedText],
        elapsed: Double,
        centerX: CGFloat,
        centerY: CGFloat,
        charWidth: CGFloat,
        charHeight: CGFloat,
        offsetX: CGFloat,
        jitter: CGFloat,
        charIndexOffset: Int,
        useMainIndex: Bool
    ) {
        for (row, line) in frame.enumerated() {
            for (col, char) in line.enumerated() {
                guard char != " " else { continue }
                let charIdx: Int
                if useMainIndex {
                    charIdx = (Int(elapsed * 15) + row * 7 + col * 3) % Self.asciiChars.count
                } else {
                    charIdx = (charIndexOffset + row * 5 + col * 2) % Self.asciiChars.count
                }
                let displayChar: String = Self.asciiChars[charIdx]
                if let r = resolved[displayChar] {
                    let x: CGFloat = centerX + CGFloat(col - 3) * charWidth + offsetX
                    let y: CGFloat = centerY + CGFloat(row - 2) * charHeight + jitter
                    context.draw(r, at: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - Phase 3: Dashboard

struct DashboardPhase: View {
    var namespace: Namespace.ID
    @State private var alarmOn = true

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 60)

            DotMatrixTime(time: "06:42")
                .padding(.top, 10)

            AnalogClock()
                .frame(width: 200, height: 200)
                .padding(.top, -40)

            Spacer()
                .frame(height: 30)

            AlarmCard(isOn: $alarmOn)
                .matchedGeometryEffect(id: "card", in: namespace)
                .padding(.horizontal, 30)

            Spacer()

            AIDock()
                .padding(.bottom, 40)
        }
    }
}

struct AlarmCard: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Run")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.gray)

                Text("09:45")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.yellow)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
    }
}

struct AnalogClock: View {
    @State private var currentTime = Date()

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = size / 2 - 10

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)

                ForEach(0..<12, id: \.self) { tick in
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1.5, height: tick % 3 == 0 ? 12 : 6)
                        .offset(y: -radius + (tick % 3 == 0 ? 6 : 3))
                        .rotationEffect(.degrees(Double(tick) * 30))
                }

                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 1.5, height: radius * 0.7)
                    .offset(y: -radius * 0.35)
                    .rotationEffect(minuteAngle)

                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: radius * 0.5)
                    .offset(y: -radius * 0.25)
                    .rotationEffect(hourAngle)

                TriangleShape()
                    .fill(Color.yellow)
                    .frame(width: 14, height: 16)
            }
            .frame(width: size, height: size)
            .position(center)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { time in
            currentTime = time
        }
    }

    private var minuteAngle: Angle {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: currentTime)
        let second = calendar.component(.second, from: currentTime)
        return .degrees(Double(minute) * 6 + Double(second) * 0.1)
    }

    private var hourAngle: Angle {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime) % 12
        let minute = calendar.component(.minute, from: currentTime)
        return .degrees(Double(hour) * 30 + Double(minute) * 0.5)
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dot Matrix Time

struct DotMatrixTime: View {
    let time: String

    static let digitPatterns: [Character: [[Bool]]] = [
        "0": [
            [false, true, true, true, false],
            [true, false, false, false, true],
            [true, false, false, true, true],
            [true, false, true, false, true],
            [true, true, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, false],
        ],
        "1": [
            [false, false, true, false, false],
            [false, true, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, true, true, true, false],
        ],
        "2": [
            [false, true, true, true, false],
            [true, false, false, false, true],
            [false, false, false, false, true],
            [false, false, true, true, false],
            [false, true, false, false, false],
            [true, false, false, false, false],
            [true, true, true, true, true],
        ],
        "3": [
            [false, true, true, true, false],
            [true, false, false, false, true],
            [false, false, false, false, true],
            [false, false, true, true, false],
            [false, false, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, false],
        ],
        "4": [
            [false, false, false, true, false],
            [false, false, true, true, false],
            [false, true, false, true, false],
            [true, false, false, true, false],
            [true, true, true, true, true],
            [false, false, false, true, false],
            [false, false, false, true, false],
        ],
        "5": [
            [true, true, true, true, true],
            [true, false, false, false, false],
            [true, true, true, true, false],
            [false, false, false, false, true],
            [false, false, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, false],
        ],
        "6": [
            [false, true, true, true, false],
            [true, false, false, false, false],
            [true, false, false, false, false],
            [true, true, true, true, false],
            [true, false, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, false],
        ],
        "7": [
            [true, true, true, true, true],
            [false, false, false, false, true],
            [false, false, false, true, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
        ],
        "8": [
            [false, true, true, true, false],
            [true, false, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, false],
            [true, false, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, false],
        ],
        "9": [
            [false, true, true, true, false],
            [true, false, false, false, true],
            [true, false, false, false, true],
            [false, true, true, true, true],
            [false, false, false, false, true],
            [false, false, false, false, true],
            [false, true, true, true, false],
        ],
        ":": [
            [false, false, false, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, false, false, false],
            [false, false, true, false, false],
            [false, false, true, false, false],
            [false, false, false, false, false],
        ],
    ]

    var body: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 4
            let dotSpacing: CGFloat = 7
            let charGap: CGFloat = 10

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
                                width: dotSize,
                                height: dotSize
                            )
                            context.fill(
                                RoundedRectangle(cornerRadius: 1).path(in: rect),
                                with: .color(.white.opacity(0.08))
                            )
                        }
                    }
                }

                offsetX += 5 * dotSpacing + charGap
            }
        }
        .frame(height: 7 * 7)
    }
}

// MARK: - AI Dock

struct AIDock: View {
    var body: some View {
        HStack(spacing: 20) {
            DockIcon {
                Circle()
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    .frame(width: 20, height: 20)
            }

            DockIcon {
                Image(systemName: "sparkle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            DockIcon {
                Image(systemName: "asterisk")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            DockIcon {
                Image(systemName: "brain")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            DockIcon {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
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
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .white.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Previews

#Preview("Full App") {
    ContentView()
}

#Preview("Dot Grid") {
    ZStack {
        Color.black.ignoresSafeArea()
        DotGridBackground()
    }
}

struct DashboardPreviewWrapper: View {
    @Namespace private var ns
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            DotGridBackground()
            DashboardPhase(namespace: ns)
        }
    }
}

#Preview("Dashboard") {
    DashboardPreviewWrapper()
}
