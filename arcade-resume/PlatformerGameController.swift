import CoreGraphics
import Foundation
import Observation

struct GameInput: Equatable {
    var isMovingLeft = false
    var isMovingRight = false
    var jumpRequested = false
}

struct ResumePlayer: Equatable {
    var position: CGPoint
    var velocity: CGVector = .zero
    let size = CGSize(width: 34, height: 44)
    var isFacingRight = true
    var isGrounded = false

    var rect: CGRect {
        CGRect(
            x: position.x - size.width / 2,
            y: position.y - size.height,
            width: size.width,
            height: size.height
        )
    }
}

struct QuestionBlock: Identifiable, Equatable {
    let id: ResumeExperience.ID
    let experience: ResumeExperience
    let x: CGFloat
    var isRevealed: Bool
}

@Observable
final class PlatformerGameController {
    private(set) var player = ResumePlayer(position: CGPoint(x: 72, y: 0))
    private(set) var blocks: [QuestionBlock]
    private(set) var activeExperience: ResumeExperience?
    private(set) var cameraX: CGFloat = 0
    private(set) var score = 0

    let worldWidth: CGFloat
    let groundHeight: CGFloat = 86

    private let gravity: CGFloat = 1_850
    private let moveSpeed: CGFloat = 245
    private let jumpVelocity: CGFloat = -650
    private let floorFriction: CGFloat = 0.82

    init(experiences: [ResumeExperience] = ResumeExperience.all) {
        self.worldWidth = max(900, CGFloat(experiences.count) * 260 + 220)
        self.blocks = experiences.enumerated().map { index, experience in
            QuestionBlock(
                id: experience.id,
                experience: experience,
                x: 190 + CGFloat(index) * 260,
                isRevealed: false
            )
        }
        reset()
    }

    var revealedCount: Int {
        blocks.filter(\.isRevealed).count
    }

    var completionProgress: Double {
        guard !blocks.isEmpty else { return 1 }
        return Double(revealedCount) / Double(blocks.count)
    }

    func reset() {
        player = ResumePlayer(position: CGPoint(x: 72, y: groundY(for: .zero)))
        blocks = blocks.map { block in
            QuestionBlock(id: block.id, experience: block.experience, x: block.x, isRevealed: false)
        }
        activeExperience = nil
        cameraX = 0
        score = 0
    }

    func selectExperience(_ experience: ResumeExperience?) {
        activeExperience = experience
    }

    func step(input: GameInput, viewport: CGSize, deltaTime: TimeInterval) {
        let clampedDelta = min(max(CGFloat(deltaTime), 0), 1 / 30)
        var nextPlayer = player

        if input.isMovingLeft == input.isMovingRight {
            nextPlayer.velocity.dx *= nextPlayer.isGrounded ? floorFriction : 0.96
        } else if input.isMovingLeft {
            nextPlayer.velocity.dx = -moveSpeed
            nextPlayer.isFacingRight = false
        } else if input.isMovingRight {
            nextPlayer.velocity.dx = moveSpeed
            nextPlayer.isFacingRight = true
        }

        if input.jumpRequested && nextPlayer.isGrounded {
            nextPlayer.velocity.dy = jumpVelocity
            nextPlayer.isGrounded = false
        }

        nextPlayer.velocity.dy += gravity * clampedDelta
        nextPlayer.position.x += nextPlayer.velocity.dx * clampedDelta
        nextPlayer.position.y += nextPlayer.velocity.dy * clampedDelta

        let floorY = groundY(for: viewport)
        if nextPlayer.position.y >= floorY {
            nextPlayer.position.y = floorY
            nextPlayer.velocity.dy = 0
            nextPlayer.isGrounded = true
        }

        nextPlayer.position.x = min(max(nextPlayer.position.x, nextPlayer.size.width / 2), worldWidth - nextPlayer.size.width / 2)

        player = nextPlayer
        resolveBlockHits(viewport: viewport)
        updateCamera(viewport: viewport)
    }

    func groundY(for viewport: CGSize) -> CGFloat {
        max(300, viewport.height - groundHeight)
    }

    private func updateCamera(viewport: CGSize) {
        let target = player.position.x - viewport.width * 0.38
        cameraX = min(max(0, target), max(0, worldWidth - viewport.width))
    }

    func rect(for block: QuestionBlock, viewport: CGSize) -> CGRect {
        CGRect(x: block.x, y: groundY(for: viewport) - 196, width: 48, height: 48)
    }

    private func resolveBlockHits(viewport: CGSize) {
        guard player.velocity.dy < 0 else { return }

        let playerRect = player.rect
        guard let hitIndex = blocks.firstIndex(where: { block in
            let blockRect = rect(for: block, viewport: viewport)
            return !block.isRevealed
                && playerRect.intersects(blockRect)
                && playerRect.minY <= blockRect.maxY
                && playerRect.minY >= blockRect.midY
        }) else { return }

        blocks[hitIndex].isRevealed = true
        activeExperience = blocks[hitIndex].experience
        score += 100
        player.velocity.dy = 160
    }
}
