import SwiftUI

struct ContentView: View {
    @State private var controller = PlatformerGameController()
    @State private var input = GameInput()
    @State private var feedback = ArcadeFeedbackController()
    @State private var lastFrameDate = Date()
    @State private var lastScore = 0
    @FocusState private var gameHasFocus: Bool

    var body: some View {
        GeometryReader { proxy in
            let viewport = proxy.size

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [Color(red: 0.45, green: 0.76, blue: 1), Color(red: 0.82, green: 0.94, blue: 1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                GameWorldView(controller: controller, viewport: viewport)

                TouchInputCaptureView(input: $input, onJump: requestJump)

                VStack(spacing: 0) {
                    HUDView(
                        score: controller.score,
                        revealedCount: controller.revealedCount,
                        totalCount: controller.blocks.count,
                        progress: controller.completionProgress,
                        onReset: resetGame
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()

                    ControlPadView(input: $input) {
                        requestJump()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                if let experience = controller.activeExperience {
                    ZStack {
                        Color.black.opacity(0.34)
                            .ignoresSafeArea()

                        ExperienceDetailView(experience: experience, viewport: viewport) {
                            closeActiveExperience(playFeedback: true)
                        }
                        .position(x: viewport.width / 2, y: viewport.height / 2)
                    }
                    .frame(width: viewport.width, height: viewport.height)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                closeActiveExperience(playFeedback: true)
                            }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .focusable(true)
            .focused($gameHasFocus)
            .onAppear {
                gameHasFocus = true
                feedback.startBackgroundMusic()
                lastScore = controller.score
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow], phases: .all) { keyPress in
                handleKeyPress(keyPress)
            }
            .task(id: viewport) {
                lastFrameDate = Date()

                while !Task.isCancelled {
                    let now = Date()
                    let delta = now.timeIntervalSince(lastFrameDate)
                    lastFrameDate = now
                    let wasGroundedBeforeStep = controller.player.isGrounded
                    controller.step(input: input, viewport: viewport, deltaTime: delta)
                    playRevealFeedbackIfNeeded()
                    playLandingFeedbackIfNeeded(wasGroundedBeforeStep: wasGroundedBeforeStep)
                    input.jumpRequested = false

                    try? await Task.sleep(for: .milliseconds(16))
                }
            }
            .animation(.snappy(duration: 0.24), value: controller.activeExperience)
        }
    }

    private func requestJump() {
        guard playerCanJump else { return }
        input.jumpRequested = true
        feedback.playJump()
    }

    private func resetGame() {
        controller.reset()
        lastScore = controller.score
        feedback.playReset()
    }

    private func closeActiveExperience(playFeedback: Bool) {
        guard controller.activeExperience != nil else { return }
        controller.selectExperience(nil)
        if playFeedback {
            feedback.playClose()
        }
    }

    private func playRevealFeedbackIfNeeded() {
        guard controller.score != lastScore else { return }
        lastScore = controller.score
        feedback.playBlockReveal()
    }

    private func playLandingFeedbackIfNeeded(wasGroundedBeforeStep: Bool) {
        let isGroundedAfterStep = controller.player.isGrounded
        guard !wasGroundedBeforeStep && isGroundedAfterStep else { return }
        feedback.playLanding()
    }

    private var playerCanJump: Bool {
        controller.player.isGrounded
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .leftArrow:
            if keyPress.phase == .down {
                closeActiveExperience(playFeedback: true)
            }
            input.isMovingLeft = keyPress.phase != .up
            return .handled
        case .rightArrow:
            if keyPress.phase == .down {
                closeActiveExperience(playFeedback: true)
            }
            input.isMovingRight = keyPress.phase != .up
            return .handled
        case .upArrow:
            if keyPress.phase == .down {
                closeActiveExperience(playFeedback: true)
                requestJump()
            }
            return .handled
        default:
            return .ignored
        }
    }

}

private struct GameWorldView: View {
    let controller: PlatformerGameController
    let viewport: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            decorativeCloud(x: 72, y: 62, scale: 0.9)
            decorativeCloud(x: 430, y: 92, scale: 1.1)
            decorativeCloud(x: 960, y: 54, scale: 0.85)

            ForEach(controller.blocks) { block in
                QuestionBlockView(block: block)
                    .frame(width: 48, height: 48)
                    .position(
                        x: controller.rect(for: block, viewport: viewport).midX,
                        y: controller.rect(for: block, viewport: viewport).midY
                    )
                    .onTapGesture {
                        guard block.isRevealed else { return }
                        controller.selectExperience(block.experience)
                    }
            }

            PlayerView(player: controller.player)
                .frame(width: controller.player.size.width, height: controller.player.size.height)
                .position(x: controller.player.position.x, y: controller.player.position.y - controller.player.size.height / 2)

            ground
                .frame(width: controller.worldWidth, height: controller.groundHeight)
                .position(x: controller.worldWidth / 2, y: controller.groundY(for: viewport) + controller.groundHeight / 2)
        }
        .frame(width: controller.worldWidth, height: viewport.height, alignment: .topLeading)
        .offset(x: -controller.cameraX)
        .clipped()
    }

    private var ground: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.16, green: 0.57, blue: 0.29))
                .frame(height: 18)
            Rectangle()
                .fill(Color(red: 0.56, green: 0.34, blue: 0.18))
                .overlay(alignment: .top) {
                    HStack(spacing: 14) {
                        ForEach(0..<80, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(index.isMultiple(of: 2) ? Color(red: 0.45, green: 0.25, blue: 0.12) : Color(red: 0.66, green: 0.43, blue: 0.24))
                                .frame(width: 28, height: 10)
                        }
                    }
                    .padding(.top, 14)
                }
        }
    }

    private func decorativeCloud(x: CGFloat, y: CGFloat, scale: CGFloat) -> some View {
        ZStack {
            Capsule().fill(.white.opacity(0.92)).frame(width: 74, height: 28)
            Circle().fill(.white.opacity(0.94)).frame(width: 32, height: 32).offset(x: -18, y: -8)
            Circle().fill(.white.opacity(0.94)).frame(width: 42, height: 42).offset(x: 10, y: -12)
        }
        .scaleEffect(scale)
        .position(x: x, y: y)
    }
}

private struct QuestionBlockView: View {
    let block: QuestionBlock

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(block.isRevealed ? Color(red: 0.72, green: 0.58, blue: 0.37) : Color(red: 1, green: 0.73, blue: 0.17))
                .shadow(color: .black.opacity(0.25), radius: 0, x: 0, y: 4)

            RoundedRectangle(cornerRadius: 4)
                .stroke(.white.opacity(0.55), lineWidth: 2)
                .padding(5)

            Text(block.isRevealed ? "✓" : "?")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(block.isRevealed ? block.experience.title : "Question block")
    }
}

private struct PlayerView: View {
    let player: ResumePlayer

    private let idleFrames = ["HeroIdle0", "HeroIdle1", "HeroIdle2", "HeroIdle3"]
    private let walkFrames = ["HeroWalk0", "HeroWalk1", "HeroWalk2", "HeroWalk3", "HeroWalk4", "HeroWalk5"]

    private var isMoving: Bool {
        abs(player.velocity.dx) > 12
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let timestamp = timeline.date.timeIntervalSinceReferenceDate
            let frameName = currentFrameName(at: timestamp)
            let groundBounce = isMoving && player.isGrounded ? sin(timestamp * 18) * 1.5 : 0

            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(.black.opacity(player.isGrounded ? 0.24 : 0.12))
                    .frame(width: 44, height: 9)
                    .offset(y: 4)

                Image(frameName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .scaleEffect(x: player.isFacingRight ? 1 : -1, y: 1)
                    .offset(y: -7 + groundBounce)
            }
            .frame(width: 88, height: 88, alignment: .bottom)
            .accessibilityLabel("Player character")
        }
    }

    private func currentFrameName(at timestamp: TimeInterval) -> String {
        if !player.isGrounded && abs(player.velocity.dy) > 1 {
            return player.velocity.dy < 0 ? "HeroJump0" : "HeroFall0"
        }

        if isMoving {
            return walkFrames[Int(timestamp * 12) % walkFrames.count]
        }

        return idleFrames[Int(timestamp * 4) % idleFrames.count]
    }
}

private struct HUDView: View {
    let score: Int
    let revealedCount: Int
    let totalCount: Int
    let progress: Double
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            stat(title: "Score", value: "\(score)")
            stat(title: "Jobs", value: "\(revealedCount)/\(totalCount)")

            ProgressView(value: progress)
                .tint(Color(red: 0.1, green: 0.5, blue: 0.28))
                .frame(maxWidth: 160)
                .accessibilityLabel("Resume progress")

            Spacer(minLength: 8)

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.13, green: 0.2, blue: 0.34))
            .accessibilityLabel("Reset")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func stat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
        }
        .frame(minWidth: 54, alignment: .leading)
    }
}

private struct ExperienceDetailView: View {
    let experience: ResumeExperience
    let viewport: CGSize
    let onClose: () -> Void

    private var sheetWidth: CGFloat {
        min(max(viewport.width - 48, 280), 340)
    }

    private var sheetHeight: CGFloat {
        let availableHeight = max(260, viewport.height - 96)
        let preferredHeight = max(viewport.height * 0.66, 340)
        return min(min(preferredHeight, availableHeight), 540)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Job Description")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.1, green: 0.52, blue: 0.33), in: Capsule())

                    Text(experience.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.13, blue: 0.2))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(experience.organization)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.35, blue: 0.66))

                    Text("\(experience.location) • \(experience.period)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.37, green: 0.44, blue: 0.54))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(red: 0.08, green: 0.13, blue: 0.2))
                        .frame(width: 34, height: 34)
                        .background(Color(red: 0.92, green: 0.95, blue: 0.98), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close job description")
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(experience.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.24))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(experience.responsibilities, id: \.self) { responsibility in
                            Label {
                                Text(responsibility)
                                    .font(.caption.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color(red: 0.1, green: 0.52, blue: 0.33))
                            }
                            .foregroundStyle(Color(red: 0.12, green: 0.16, blue: 0.24))
                        }
                    }

                    FlowLayout(spacing: 7) {
                        ForEach(experience.skills, id: \.self) { skill in
                            Text(skill)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(red: 0.08, green: 0.22, blue: 0.38))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.88, green: 0.94, blue: 1), in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Button(action: onClose) {
                Text("Close")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.12, green: 0.22, blue: 0.36))
            .accessibilityLabel("Close job description")
        }
        .padding(18)
        .frame(width: sheetWidth, height: sheetHeight, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.78, green: 0.86, blue: 0.94), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 14)
    }
}

private struct TouchInputCaptureView: View {
    @Binding var input: GameInput
    let onJump: () -> Void
    @State private var didRequestJumpDuringGesture = false

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateInput(for: value.location, in: proxy.size)
                        }
                        .onEnded { _ in
                            input.isMovingLeft = false
                            input.isMovingRight = false
                            didRequestJumpDuringGesture = false
                        }
                )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func updateInput(for location: CGPoint, in size: CGSize) {
        requestJumpOnce()

        let leftBoundary = size.width * 0.34
        let rightBoundary = size.width * 0.66

        if location.x < leftBoundary {
            input.isMovingLeft = true
            input.isMovingRight = false
        } else if location.x > rightBoundary {
            input.isMovingLeft = false
            input.isMovingRight = true
        } else {
            input.isMovingLeft = false
            input.isMovingRight = false
            requestJumpOnce()
        }
    }

    private func requestJumpOnce() {
        guard !didRequestJumpDuringGesture else { return }
        onJump()
        didRequestJumpDuringGesture = true
    }
}

private struct ControlPadView: View {
    @Binding var input: GameInput
    let onJump: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 10) {
                holdButton(systemName: "arrow.left", accessibilityLabel: "Move left") { isPressed in
                    input.isMovingLeft = isPressed
                }
                holdButton(systemName: "arrow.right", accessibilityLabel: "Move right") { isPressed in
                    input.isMovingRight = isPressed
                }
            }

            Spacer()

            Button(action: onJump) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 24, weight: .black))
                    .frame(width: 64, height: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.9, green: 0.2, blue: 0.2))
            .accessibilityLabel("Jump")
        }
    }

    private func holdButton(systemName: String, accessibilityLabel: String, onPressChanged: @escaping (Bool) -> Void) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 24, weight: .black))
            .frame(width: 64, height: 54)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.45), lineWidth: 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPressChanged(true) }
                    .onEnded { _ in onPressChanged(false) }
            )
            .accessibilityLabel(accessibilityLabel)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for item in layout(in: bounds.width, subviews: subviews).items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + item.frame.minY),
                proposal: ProposedViewSize(item.frame.size)
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (items: [(index: Int, frame: CGRect)], size: CGSize) {
        var items: [(index: Int, frame: CGRect)] = []
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if origin.x > 0 && origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += lineHeight + spacing
                lineHeight = 0
            }

            let frame = CGRect(origin: origin, size: size)
            items.append((index, frame))
            usedWidth = max(usedWidth, frame.maxX)
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return (items, CGSize(width: usedWidth, height: origin.y + lineHeight))
    }
}

#Preview {
    ContentView()
}
