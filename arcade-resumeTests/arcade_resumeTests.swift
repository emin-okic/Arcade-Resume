import CoreGraphics
import Testing
@testable import arcade_resume

struct arcade_resumeTests {
    @Test func resumeExperiencesRepresentCareerHistory() {
        #expect(ResumeExperience.all.count == 5)
        #expect(ResumeExperience.all.first?.title == "Freelance Software Engineer")
        #expect(ResumeExperience.all.contains { $0.organization == "Ames National Laboratory" })
    }

    @Test func controllerMovesPlayerAndTracksProgress() {
        let controller = PlatformerGameController()
        let startX = controller.player.position.x

        controller.step(
            input: GameInput(isMovingRight: true),
            viewport: CGSize(width: 600, height: 500),
            deltaTime: 0.2
        )

        #expect(controller.player.position.x > startX)
        #expect(controller.revealedCount == 0)
        #expect(controller.completionProgress == 0)
    }

    @Test func resetClearsScoreAndActiveExperience() {
        let controller = PlatformerGameController()

        controller.selectExperience(ResumeExperience.all[0])
        controller.reset()

        #expect(controller.score == 0)
        #expect(controller.activeExperience == nil)
        #expect(controller.revealedCount == 0)
    }
}
