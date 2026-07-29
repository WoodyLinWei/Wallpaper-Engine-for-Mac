//
//  WESpriteScene.swift
//  Open Wallpaper Engine
//
//  SpriteKit scene that advances native Wallpaper Engine layer adapters.
//

import SpriteKit

final class WESpriteScene: SKScene {
    private final class MobBinding {
        weak var node: SKSpriteNode?
        let textures: [SKTexture]
        let controller: MobController
        let baseScale: CGFloat

        init(
            node: SKSpriteNode,
            textures: [SKTexture],
            controller: MobController,
            baseScale: CGFloat
        ) {
            self.node = node
            self.textures = textures
            self.controller = controller
            self.baseScale = baseScale
        }
    }

    private final class TimedAnimationBinding {
        weak var node: SKSpriteNode?
        let textures: [SKTexture]
        let durations: [TimeInterval]
        var frameIndex = 0
        var elapsed = 0.0

        init(node: SKSpriteNode, textures: [SKTexture], durations: [TimeInterval]) {
            self.node = node
            self.textures = textures
            self.durations = durations
        }
    }

    private var mobBindings: [MobBinding] = []
    private var timedAnimations: [TimedAnimationBinding] = []
    private var lastUpdateTime: TimeInterval?

    static func zPosition(forObjectIndex index: Int) -> CGFloat {
        CGFloat(index)
    }

    static func horizontalScale(baseScale: CGFloat, direction: Int) -> CGFloat {
        abs(baseScale) * (direction < 0 ? -1 : 1)
    }

    func bindMob(
        node: SKSpriteNode,
        textures: [SKTexture],
        controller: MobController,
        baseScale: CGFloat
    ) {
        let binding = MobBinding(
            node: node,
            textures: textures,
            controller: controller,
            baseScale: baseScale
        )
        mobBindings.append(binding)
        apply(controller.state, to: binding)
    }

    func bindTimedAnimation(
        node: SKSpriteNode,
        textures: [SKTexture],
        durations: [TimeInterval]
    ) {
        guard textures.count > 1 else { return }
        let normalizedDurations = textures.indices.map { index -> TimeInterval in
            guard durations.indices.contains(index), durations[index] > 0 else {
                return 1.0 / 30.0
            }
            return durations[index]
        }
        timedAnimations.append(
            TimedAnimationBinding(
                node: node,
                textures: textures,
                durations: normalizedDurations
            )
        )
        node.texture = textures[0]
    }

    override func update(_ currentTime: TimeInterval) {
        defer { lastUpdateTime = currentTime }
        guard let lastUpdateTime else { return }

        let deltaTime = max(0, min(currentTime - lastUpdateTime, 0.25))
        guard deltaTime > 0 else { return }

        mobBindings.removeAll { binding in
            guard binding.node != nil else { return true }
            let state = binding.controller.update(deltaTime: deltaTime)
            apply(state, to: binding)
            return false
        }

        timedAnimations.removeAll { binding in
            guard let node = binding.node else { return true }
            binding.elapsed += deltaTime

            while binding.elapsed >= binding.durations[binding.frameIndex] {
                binding.elapsed -= binding.durations[binding.frameIndex]
                binding.frameIndex = (binding.frameIndex + 1) % binding.textures.count
            }
            node.texture = binding.textures[binding.frameIndex]
            return false
        }
    }

    private func apply(_ state: MobControllerState, to binding: MobBinding) {
        guard let node = binding.node else { return }
        node.position.x = state.x
        node.xScale = Self.horizontalScale(
            baseScale: binding.baseScale,
            direction: state.direction
        )

        guard !binding.textures.isEmpty else { return }
        let frameIndex = min(max(state.frame, 0), binding.textures.count - 1)
        node.texture = binding.textures[frameIndex]
    }
}
