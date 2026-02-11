//
//  ContentView.swift
//  replit
//
//  Arc Search / Unified Interface Prototype
//  Premium monochrome dot-matrix aesthetic with glow effects
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
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, !self.isPaused else { return }
            if self.transcriptionProgress < self.transcriptionWords.count {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.transcriptionProgress += 1
                }
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            phase = .voiceInput
            transcriptionProgress = 0
            isPaused = false
        }
    }

    private func scheduleTransitionToDashboard() {
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
                self?.phase = .dashboard
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
            // Deep gradient background
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.03, green: 0.03, blue: 0.06), location: 0),
                    .init(color: Color(red: 0.05, green: 0.05, blue: 0.12), location: 0.5),
                    .init(color: Color(red: 0.03, green: 0.03, blue: 0.08), location: 1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            DotGridBackground()

            switch viewModel.phase {
            case .voiceInput:
                VoiceInputPhase(viewModel: viewModel, ns: hero)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                        removal: .opacity.combined(with: .scale(scale: 1.03))
                    ))

            case .processing:
                ASCIIRunnerPhase(ns: hero)
                    .transition(.opacity)

            case .dashboard:
                DashboardPhase(ns: hero)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)).combined(with: .offset(y: 30)),
                        removal: .opacity
                    ))
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
            let spacing: CGFloat = 20
            let dotRadius: CGFloat = 0.8

            var x: CGFloat = spacing / 2
            while x < size.width {
                var y: CGFloat = spacing / 2
                while y < size.height {
                    let distFromCenter = abs(x - size.width / 2) / size.width +
                                         abs(y - size.height / 2) / size.height
                    let opacity = 0.12 + (1.0 - distFromCenter) * 0.08

                    let rect = CGRect(
                        x: x - dotRadius, y: y - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(.white.opacity(opacity))
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

            VStack(spacing: 16) {
                Text("LISTENING")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(3)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appeared)

                TranscriptionText(
                    words: viewModel.transcriptionWords,
                    progress: viewModel.transcriptionProgress
                )
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .matchedGeometryEffect(id: "card", in: ns)
            .padding(.horizontal, 30)

            Spacer()

            OrganicWaveform(isActive: !viewModel.isPaused)
                .frame(height: 80)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: appeared)

            Spacer().frame(height: 24)

            GlassControlBar(viewModel: viewModel)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: appeared)

            Spacer().frame(height: 50)
        }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

struct TranscriptionText: View {
    let words: [String]
    let progress: Int

    private var visibleText: String {
        words.prefix(progress).joined(separator: " ")
    }

    var body: some View {
        Text(visibleText)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(color: .cyan.opacity(0.3), radius: 12)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progress)
    }
}

// MARK: - Organic Waveform

struct OrganicWaveform: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            Canvas { ctx, size in
                guard isActive else {
                    drawIdleLine(ctx: ctx, size: size)
                    return
                }
                drawWaves(ctx: &ctx, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func drawIdleLine(ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        ctx.stroke(path, with: .color(.white.opacity(0.1)), lineWidth: 1)
    }

    private func drawWaves(ctx: inout GraphicsContext, size: CGSize, time: Double) {
        let waves: [(amp: Double, freq: Double, spd: Double, op: Double, w: CGFloat)] = [
            (22, 1.8, 2.5, 0.15, 6),
            (18, 2.2, 3.0, 0.25, 4),
            (14, 2.8, 3.5, 0.4, 3),
            (10, 1.5, 2.0, 0.6, 2),
        ]

        for wave in waves {
            var path = Path()
            let midY = size.height / 2

            for x in stride(from: CGFloat(0), through: size.width, by: 1) {
                let relX = Double(x / size.width)
                let envelope = sin(relX * .pi)
                let n1 = sin(relX * wave.freq * 2 * .pi + time * wave.spd)
                let n2 = sin(relX * wave.freq * 3.7 * .pi + time * wave.spd * 1.3) * 0.4
                let n3 = sin(relX * wave.freq * 0.5 * .pi + time * wave.spd * 0.7) * 0.2
                let y = midY + (n1 + n2 + n3) * wave.amp * envelope

                if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            // Glow layer
            var glowCtx = ctx
            glowCtx.addFilter(.blur(radius: 8))
            glowCtx.stroke(path, with: .color(.cyan.opacity(wave.op * 0.5)), lineWidth: wave.w + 4)

            // Core line
            ctx.stroke(path, with: .color(.cyan.opacity(wave.op)), lineWidth: wave.w)
        }
    }
}

// MARK: - Glass Control Bar

struct GlassControlBar: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var pausePressed = false
    @State private var stopPressed = false

    var body: some View {
        HStack(spacing: 14) {
            Button(action: {
                pausePressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { pausePressed = false }
                viewModel.togglePause()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [Color.yellow, Color.yellow.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: .yellow.opacity(0.3), radius: 12, y: 4)
            }
            .scaleEffect(pausePressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: pausePressed)

            Button(action: {
                stopPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { stopPressed = false }
                viewModel.stopAndReset()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Stop")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Capsule().fill(.white.opacity(0.1)))
            }
            .scaleEffect(stopPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: stopPressed)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().stroke(.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Phase 2: ASCII Runner

struct ASCIIRunnerPhase: View {
    var ns: Namespace.ID
    @State private var startDate = Date()
    @State private var pulsingDots = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Processing")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.cyan.opacity(0.6))
                .tracking(2)
                .shadow(color: .cyan.opacity(0.3), radius: 8)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appeared)
                .padding(.bottom, 24)

            ASCIIRunnerCanvas(startDate: startDate)
                .frame(height: 220)
                .matchedGeometryEffect(id: "card", in: ns)
                .padding(.horizontal, 20)

            Spacer()

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.cyan.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .shadow(color: .cyan.opacity(0.4), radius: 6)
                        .scaleEffect(pulsingDots ? 1.5 : 0.5)
                        .opacity(pulsingDots ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.7)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                            value: pulsingDots
                        )
                }
            }
            .padding(.bottom, 60)
            .onAppear {
                pulsingDots = true
                appeared = true
            }
        }
    }
}

// MARK: - ASCII Runner Canvas

struct ASCIIRunnerCanvas: View {
    let startDate: Date

    static let runFrames: [[String]] = [
        ["     .@@.     ", "    @####@    ", "    @#**#@    ", "     \\##/     ",
         "      ||      ", "    ./||\\     ", "   /  ||  \\   ", "  :   ||   :  ",
         "      /\\      ", "     /  \\     ", "    /    \\    ", "   :      :   "],
        ["     .@@.     ", "    @####@    ", "    @#**#@    ", "     \\##/     ",
         "      ||      ", "   \\  ||      ", "    \\ ||____  ", "     \\||    : ",
         "      ||      ", "     / :      ", "    /         ", "   :          "],
        ["     .@@.     ", "    @####@    ", "    @#**#@    ", "     \\##/     ",
         "     /||\\.    ", "    / || \\    ", "   :  ||  :   ", "  ____||      ",
         "      /\\      ", "     :  :     ", "              ", "              "],
        ["     .@@.     ", "    @####@    ", "    @#**#@    ", "     \\##/     ",
         "  ___/||      ", "     ||\\      ", "     || \\     ", "     ||  :    ",
         "     /\\       ", "    :  :      ", "              ", "              "],
        ["     .@@.     ", "    @####@    ", "    @#**#@    ", "     \\##/     ",
         "      ||\\_____", "      ||      ", "     /||      ", "    : ||      ",
         "      /\\      ", "     :  \\     ", "         \\    ", "          :   "],
        ["     .@@.     ", "    @####@    ", "    @#**#@    ", "     \\##/     ",
         "     \\||/     ", "      ||      ", "     /||\\     ", "    : || :    ",
         "     /  \\     ", "    /    \\    ", "   :      :   ", "              "],
    ]

    static let asciiChars: [String] = ["$", "#", ":", ".", "@", "%", "&", "*", "~", ";"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, size in
                drawScene(context: &context, size: size, date: timeline.date)
            }
        }
    }

    private func drawScene(context: inout GraphicsContext, size: CGSize, date: Date) {
        let elapsed = date.timeIntervalSince(startDate)
        let charSize: CGFloat = 13
        let charWidth: CGFloat = charSize * 0.55
        let charHeight: CGFloat = charSize * 1.0
        let centerX = size.width / 2
        let centerY = size.height / 2

        drawTrail(context: &context, elapsed: elapsed,
                  centerX: centerX, centerY: centerY,
                  charWidth: charWidth, charHeight: charHeight, charSize: charSize)

        drawMainRunner(context: &context, elapsed: elapsed,
                       centerX: centerX, centerY: centerY,
                       charWidth: charWidth, charHeight: charHeight, charSize: charSize)
    }

    private func drawMainRunner(
        context: inout GraphicsContext, elapsed: Double,
        centerX: CGFloat, centerY: CGFloat,
        charWidth: CGFloat, charHeight: CGFloat, charSize: CGFloat
    ) {
        let frameIndex = Int(elapsed * 10) % Self.runFrames.count
        let frame = Self.runFrames[frameIndex]

        var cyanResolved: [String: GraphicsContext.ResolvedText] = [:]
        var whiteResolved: [String: GraphicsContext.ResolvedText] = [:]
        for ch in Self.asciiChars {
            cyanResolved[ch] = context.resolve(
                Text(ch).font(.system(size: charSize, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            )
            whiteResolved[ch] = context.resolve(
                Text(ch).font(.system(size: charSize, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
            )
        }

        // Glow layer
        var glowCtx = context
        glowCtx.addFilter(.blur(radius: 6))
        glowCtx.blendMode = .plusLighter

        for (row, line) in frame.enumerated() {
            for (col, char) in line.enumerated() {
                guard char != " " else { continue }
                let idx = (Int(elapsed * 18) + row * 7 + col * 3) % Self.asciiChars.count
                let ch = Self.asciiChars[idx]
                let x = centerX + CGFloat(col - 7) * charWidth
                let y = centerY + CGFloat(row - 6) * charHeight

                if let r = cyanResolved[ch] {
                    glowCtx.draw(r, at: CGPoint(x: x, y: y))
                }
                if let r = whiteResolved[ch] {
                    context.draw(r, at: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func drawTrail(
        context: inout GraphicsContext, elapsed: Double,
        centerX: CGFloat, centerY: CGFloat,
        charWidth: CGFloat, charHeight: CGFloat, charSize: CGFloat
    ) {
        let trailCount = 15

        for i in 1...trailCount {
            let fade = 1.0 - Double(i) / Double(trailCount)
            let opacity = fade * 0.25

            var trailResolved: [String: GraphicsContext.ResolvedText] = [:]
            for ch in Self.asciiChars {
                trailResolved[ch] = context.resolve(
                    Text(ch)
                        .font(.system(size: charSize * (0.7 + fade * 0.3), design: .monospaced))
                        .foregroundColor(.cyan.opacity(opacity))
                )
            }

            let age = elapsed - Double(i) * 0.06
            let trailFrameIdx = max(0, Int(age * 10) % Self.runFrames.count)
            let trailFrame = Self.runFrames[trailFrameIdx]
            let driftX = CGFloat(i) * -8
            let jitter = sin(elapsed * 2 + Double(i) * 0.5) * Double(i) * 0.8

            var trailGlow = context
            trailGlow.addFilter(.blur(radius: CGFloat(i) * 1.5))
            trailGlow.blendMode = .plusLighter

            for (row, line) in trailFrame.enumerated() {
                for (col, char) in line.enumerated() {
                    guard char != " " else { continue }
                    let idx = (i + row * 5 + col * 2) % Self.asciiChars.count
                    let ch = Self.asciiChars[idx]
                    guard let r = trailResolved[ch] else { continue }

                    let x = centerX + CGFloat(col - 7) * charWidth + driftX
                    let y = centerY + CGFloat(row - 6) * charHeight + CGFloat(jitter)
                    trailGlow.draw(r, at: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

// MARK: - Phase 3: Dashboard

struct DashboardPhase: View {
    var ns: Namespace.ID
    @State private var alarmOn = true
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 70)

            DotMatrixTime(time: "06:42")
                .padding(.top, 10)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(0.3), value: appeared)

            AnalogClock()
                .frame(width: 220, height: 220)
                .padding(.top, -30)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.15), value: appeared)

            Spacer().frame(height: 24)

            GlassAlarmCard(isOn: $alarmOn)
                .matchedGeometryEffect(id: "card", in: ns)
                .padding(.horizontal, 28)

            Spacer()

            AIDock()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: appeared)
                .padding(.bottom, 44)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Glass Alarm Card

struct GlassAlarmCard: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("Morning Run")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                Text("09:45")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .cyan.opacity(0.2), radius: 10)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.cyan)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: .cyan.opacity(0.08), radius: 30, y: 15)
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

// MARK: - Analog Clock

struct AnalogClock: View {
    @State private var currentTime = Date()

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 12

            ZStack {
                Circle()
                    .stroke(.cyan.opacity(0.1), lineWidth: 1)
                    .blur(radius: 4)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.15), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )

                ForEach(0..<12, id: \.self) { tick in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(tick % 3 == 0 ? .white.opacity(0.5) : .white.opacity(0.2))
                        .frame(width: tick % 3 == 0 ? 2 : 1, height: tick % 3 == 0 ? 14 : 8)
                        .offset(y: -radius + (tick % 3 == 0 ? 7 : 4))
                        .rotationEffect(.degrees(Double(tick) * 30))
                }

                RoundedRectangle(cornerRadius: 1)
                    .fill(.white.opacity(0.7))
                    .frame(width: 1.5, height: radius * 0.65)
                    .offset(y: -radius * 0.325)
                    .rotationEffect(minuteAngle)
                    .shadow(color: .white.opacity(0.3), radius: 4)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.white)
                    .frame(width: 2.5, height: radius * 0.45)
                    .offset(y: -radius * 0.225)
                    .rotationEffect(hourAngle)
                    .shadow(color: .white.opacity(0.3), radius: 4)

                Circle()
                    .fill(.cyan)
                    .frame(width: 6, height: 6)
                    .shadow(color: .cyan.opacity(0.6), radius: 6)

                TriangleShape()
                    .fill(.cyan.opacity(0.8))
                    .frame(width: 10, height: 12)
                    .offset(y: 28)
                    .shadow(color: .cyan.opacity(0.4), radius: 6)
            }
            .frame(width: size, height: size)
            .position(center)
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

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
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
            let dotSize: CGFloat = 4.5
            let dotSpacing: CGFloat = 8
            let charGap: CGFloat = 12
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
                            var glowCtx = context
                            glowCtx.addFilter(.blur(radius: 3))
                            glowCtx.fill(
                                Circle().path(in: rect.insetBy(dx: -2, dy: -2)),
                                with: .color(.cyan.opacity(0.06))
                            )
                            context.fill(
                                RoundedRectangle(cornerRadius: 1.5).path(in: rect),
                                with: .color(.white.opacity(0.06))
                            )
                        }
                    }
                }
                offsetX += 5 * dotSpacing + charGap
            }
        }
        .frame(height: 7 * 8)
    }
}

// MARK: - AI Dock

struct AIDock: View {
    var body: some View {
        HStack(spacing: 18) {
            DockIcon(glow: .cyan) {
                Circle()
                    .stroke(.white.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
            DockIcon(glow: .purple) {
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            DockIcon(glow: .cyan) {
                Image(systemName: "asterisk")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            DockIcon(glow: .blue) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            DockIcon(glow: .teal) {
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

struct DockIcon<Content: View>: View {
    let glow: Color
    let content: () -> Content

    init(glow: Color = .cyan, @ViewBuilder content: @escaping () -> Content) {
        self.glow = glow
        self.content = content
    }

    var body: some View {
        content()
            .frame(width: 46, height: 46)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            )
            .shadow(color: glow.opacity(0.1), radius: 12, y: 4)
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
            Color.black.ignoresSafeArea()
            DotGridBackground()
            DashboardPhase(ns: ns)
        }
    }
}

#Preview("Dashboard") {
    DashboardPreviewWrapper()
}
