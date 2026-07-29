import Foundation
import Compression

private var failures = 0

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    if condition() {
        print("PASS: \(message)")
    } else {
        failures += 1
        print("FAIL: \(message) (\(file):\(line))")
    }
}

private func expectEqual<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: T,
    _ message: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let value = actual()
    expect(value == expected, "\(message) — expected \(expected), got \(value)", file: file, line: line)
}

let vector = "1 2 3".parseVector3()
expectEqual(vector.0, 1, "test harness compiles production parsing code")
expectEqual(vector.1, 2, "vector parser returns Y")
expectEqual(vector.2, 3, "vector parser returns Z")

private func decodeObject(_ json: String) throws -> WESceneObject {
    try JSONDecoder().decode(WESceneObject.self, from: Data(json.utf8))
}

do {
    let plain = try decodeObject(
        """
        {
          "id": 1,
          "name": "plain",
          "origin": "960 540 0",
          "scale": "1 1 1",
          "visible": true,
          "alpha": 0.75
        }
        """
    )
    expectEqual(plain.origin, "960 540 0", "plain origin is preserved")
    expectEqual(plain.originScript, nil, "plain origin has no script")
    expectEqual(plain.scale, "1 1 1", "plain scale is preserved")
    expectEqual(plain.visible, true, "plain visibility is preserved")
    expectEqual(plain.alpha, 0.75, "plain alpha is preserved")

    let scripted = try decodeObject(
        """
        {
          "id": 2,
          "name": "scripted",
          "origin": {
            "value": "1000 673 0",
            "script": "mob = new shared.Mob({ range: [480, 1440] })"
          },
          "scale": {
            "value": "1 1 1",
            "script": "value.x = thisLayer.direction"
          },
          "visible": {
            "value": true,
            "script": "return show"
          },
          "alpha": {
            "value": 0.5,
            "script": "return value"
          }
        }
        """
    )
    expectEqual(scripted.origin, "1000 673 0", "scripted origin fallback is preserved")
    expect(
        scripted.originScript?.contains("new shared.Mob") == true,
        "scripted origin source is preserved"
    )
    expectEqual(scripted.scale, "1 1 1", "scripted scale fallback is preserved")
    expect(
        scripted.scaleScript?.contains("thisLayer.direction") == true,
        "scripted scale source is preserved"
    )
    expectEqual(scripted.visible, true, "scripted visibility fallback is preserved")
    expectEqual(scripted.visibleScript, "return show", "scripted visibility source is preserved")
    expectEqual(scripted.alpha, 0.5, "scripted alpha fallback is preserved")
    expectEqual(scripted.alphaScript, "return value", "scripted alpha source is preserved")

    let sound = try decodeObject(
        """
        {
          "id": 65,
          "name": "CavaBien.mp3",
          "sound": ["sounds/CavaBien.mp3"]
        }
        """
    )
    expectEqual(sound.sound, ["sounds/CavaBien.mp3"], "scene sound paths are decoded")

    let cloud = try decodeObject(
        """
        {
          "id": 51,
          "image": "models/cloud.json",
          "effects": [{
            "file": "effects/scroll/effect.json",
            "visible": true,
            "passes": [{
              "constantshadervalues": {
                "repeat": "1 1",
                "speedx": 0.15000001,
                "speedy": 0
              }
            }]
          }]
        }
        """
    )
    let scroll = cloud.effects?.first?.passes?.first?.constantShaderValues
    expectEqual(scroll?.repeatValue, "1 1", "scroll repeat is decoded")
    expectEqual(scroll?.speedX, 0.15000001, "scroll X speed is decoded")
    expectEqual(scroll?.speedY, 0, "scroll Y speed is decoded")
} catch {
    failures += 1
    print("FAIL: flexible scene decoding threw \(error)")
}

private func appendUInt32(_ value: UInt32, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

private func appendFloat(_ value: Float, to data: inout Data) {
    appendUInt32(value.bitPattern, to: &data)
}

private func appendMagic(_ value: String, to data: inout Data) {
    data.append(contentsOf: value.utf8)
    data.append(0)
}

private func makeSyntheticAnimatedTexture() throws -> Data {
    let rgba: [UInt8] = [
        255, 0, 0, 255,
        0, 255, 0, 255
    ]
    var compressed = [UInt8](repeating: 0, count: 128)
    let compressedCount = rgba.withUnsafeBytes { source in
        compressed.withUnsafeMutableBytes { destination in
            compression_encode_buffer(
                destination.bindMemory(to: UInt8.self).baseAddress!,
                destination.count,
                source.bindMemory(to: UInt8.self).baseAddress!,
                source.count,
                nil,
                COMPRESSION_LZ4_RAW
            )
        }
    }
    guard compressedCount > 0 else {
        throw NSError(domain: "SceneRuntimeTests", code: 1)
    }

    var data = Data()
    appendMagic("TEXV0005", to: &data)
    appendMagic("TEXI0001", to: &data)
    appendUInt32(0, to: &data) // RGBA8888
    appendUInt32(4, to: &data) // animated
    appendUInt32(2, to: &data) // texture width
    appendUInt32(1, to: &data) // texture height
    appendUInt32(2, to: &data) // real width
    appendUInt32(1, to: &data) // real height
    appendUInt32(0, to: &data) // unknown

    appendMagic("TEXB0003", to: &data)
    appendUInt32(1, to: &data) // image count
    appendUInt32(UInt32.max, to: &data) // raw pixels, no FreeImage format
    appendUInt32(1, to: &data) // mipmap count
    appendUInt32(2, to: &data)
    appendUInt32(1, to: &data)
    appendUInt32(1, to: &data) // LZ4 compression
    appendUInt32(UInt32(rgba.count), to: &data)
    appendUInt32(UInt32(compressedCount), to: &data)
    data.append(contentsOf: compressed.prefix(compressedCount))

    appendMagic("TEXS0003", to: &data)
    appendUInt32(2, to: &data)
    appendUInt32(1, to: &data) // frame width
    appendUInt32(1, to: &data) // frame height

    for x in [Float(0), Float(1)] {
        appendUInt32(0, to: &data)
        appendFloat(0.1, to: &data)
        appendFloat(x, to: &data)
        appendFloat(0, to: &data)
        appendFloat(1, to: &data)
        appendFloat(0, to: &data)
        appendFloat(0, to: &data)
        appendFloat(1, to: &data)
    }
    return data
}

do {
    let textureData = try makeSyntheticAnimatedTexture()
    let decoded = try TEXParser(data: textureData).decodeTexture()
    expectEqual(decoded.metadata.format, 0, "TEX format is decoded")
    expectEqual(decoded.metadata.width, 2, "TEX real width is decoded")
    expectEqual(decoded.metadata.height, 1, "TEX real height is decoded")
    expectEqual(decoded.metadata.textureWidth, 2, "TEX storage width is decoded")
    expectEqual(decoded.metadata.textureHeight, 1, "TEX storage height is decoded")
    expectEqual(decoded.rgbaData, Data([255, 0, 0, 255, 0, 255, 0, 255]), "LZ4 RGBA bytes decode")
    expectEqual(decoded.frames.count, 2, "TEXS frame count is decoded")
    expectEqual(decoded.frames[0].x, 0, "first TEXS frame X is decoded")
    expectEqual(decoded.frames[1].x, 1, "second TEXS frame X is decoded")
    expectEqual(decoded.frames[0].width, 1, "TEXS frame width is decoded")
    expect(abs(decoded.frames[0].duration - 0.1) < 0.0001, "TEXS frame duration is decoded")

    do {
        _ = try TEXParser(data: Data(textureData.prefix(20))).decodeTexture()
        expect(false, "truncated TEX data is rejected")
    } catch {
        expect(true, "truncated TEX data is rejected")
    }
} catch {
    failures += 1
    print("FAIL: TEX decoding threw \(error)")
}

if let wallpaperPath = ProcessInfo.processInfo.environment["WE_MAPLE_WALLPAPER"] {
    do {
        let wallpaperURL = URL(fileURLWithPath: wallpaperPath, isDirectory: true)
        let projectData = try Data(contentsOf: wallpaperURL.appendingPathComponent("project.json"))
        let project = try JSONSerialization.jsonObject(with: projectData) as? [String: Any]
        expectEqual(
            project?["title"] as? String,
            "MapleStory: Henesys Hunting Ground I 冒险岛：射手训练场1",
            "real fixture title matches the selected wallpaper"
        )

        let package = try PKGParser(url: wallpaperURL.appendingPathComponent("scene.pkg"))
        expectEqual(package.fileList.count, 68, "real fixture package entry count")
        expectEqual(
            package.extractFile(named: "sounds/CavaBien.mp3")?.count,
            1_280_000,
            "real fixture audio entry is available"
        )

        guard let targetScene = try package.extractJSON(named: "scene.json", as: WEScene.self) else {
            throw NSError(domain: "SceneRuntimeTests", code: 3)
        }
        let soundPaths = targetScene.objects.flatMap { $0.sound ?? [] }
        expectEqual(soundPaths, ["sounds/CavaBien.mp3"], "real fixture discovers one audio track")
        let targetScrollEffects = targetScene.objects.compactMap {
            WESpriteScene.scrollConfiguration(for: $0.effects)
        }
        expectEqual(targetScrollEffects.count, 2, "real fixture discovers two cloud scroll layers")
        expect(
            targetScrollEffects.allSatisfy {
                abs($0.speedX - 0.15000001) < 0.000001 && $0.speedY == 0
            },
            "real fixture preserves both cloud scroll speeds"
        )

        guard let blueSnailData = package.extractFile(named: "materials/lwn.1.tex") else {
            throw NSError(domain: "SceneRuntimeTests", code: 2)
        }
        let blueSnail = try TEXParser(data: blueSnailData).decodeTexture()
        expectEqual(blueSnail.metadata.width, 88, "blue snail atlas width")
        expectEqual(blueSnail.metadata.height, 68, "blue snail atlas height")
        expectEqual(blueSnail.frames.count, 4, "blue snail animation frame count")
        expectEqual(blueSnail.frames.first?.width, 44, "blue snail frame width")
        expectEqual(blueSnail.frames.first?.height, 34, "blue snail frame height")
    } catch {
        failures += 1
        print("FAIL: real MapleStory fixture validation threw \(error)")
    }
}

let snailScript =
    """
    'use strict';
    export function init(value) {
        mob = new shared.Mob({
            range: [132, 1786],
            moveList: [0, 0.0, 0, 1, 1, 2, 3,],
            standList: [0],
            speed: 1,
        })
        return value;
    }
    """

let slimeScript =
    """
    mob = new shared.Mob({
        range: [400, 1515],
        moveList: [3, 3, 4, 4, 5, 6, 7, 8, 9, 10],
        standList: [0, 0, 1, 1, 2, 2],
        speed: 2.2
    })
    """

if let snail = MobScriptParser.parse(snailScript) {
    expectEqual(snail.lowerBound, 132, "Mob parser reads lower range")
    expectEqual(snail.upperBound, 1786, "Mob parser reads upper range")
    expectEqual(snail.moveFrames, [0, 0, 0, 1, 1, 2, 3], "Mob parser normalizes frame numbers")
    expectEqual(snail.standFrames, [0], "Mob parser reads stand frames")
    expectEqual(snail.speed, 1, "Mob parser reads integer speed")
} else {
    failures += 1
    print("FAIL: Mob parser rejected the snail script")
}

if let slime = MobScriptParser.parse(slimeScript) {
    expectEqual(slime.lowerBound, 400, "Mob parser reads second lower range")
    expectEqual(slime.upperBound, 1515, "Mob parser reads second upper range")
    expectEqual(slime.speed, 2.2, "Mob parser reads decimal speed")
    expectEqual(slime.moveFrames.last, 10, "Mob parser reads longer move sequence")
} else {
    failures += 1
    print("FAIL: Mob parser rejected the slime script")
}

expectEqual(MobScriptParser.parse("return value;"), nil, "non-Mob script is ignored")
expectEqual(
    MobScriptParser.parse("new shared.Mob({ range: [0, 1], moveList: [], standList: [] })"),
    nil,
    "Mob parser rejects empty animation lists"
)

private final class SequenceRandomSource: MobRandomSource {
    private let values: [Double]
    private var index = 0

    init(_ values: [Double]) {
        self.values = values
    }

    func nextUnit() -> Double {
        guard !values.isEmpty else { return 0.5 }
        defer { index += 1 }
        return values[index % values.count]
    }
}

let movementConfiguration = MobBehaviorConfiguration(
    lowerBound: 10,
    upperBound: 12,
    moveFrames: [0, 1],
    standFrames: [2],
    speed: 1,
    jumpFrame: nil
)

let movingController = MobController(
    configuration: movementConfiguration,
    randomSource: SequenceRandomSource([0, 0.9, 0.9, 0.9]),
    initialX: 11,
    initialDirection: 1,
    initiallyMoving: true
)
expect(
    (1...4).contains(movingController.state.remainingStateTime),
    "Mob state duration starts between one and four seconds"
)
let firstMove = movingController.update(deltaTime: 1.0 / 30.0)
expectEqual(firstMove.x, 10, "moving Mob advances at source speed")
expectEqual(firstMove.frame, 0, "moving Mob advances move frame list")
let boundaryMove = movingController.update(deltaTime: 1.0 / 30.0)
expectEqual(boundaryMove.direction, -1, "Mob reverses source direction at lower bound")
expectEqual(boundaryMove.x, 11, "Mob remains inside its movement range")
expectEqual(boundaryMove.frame, 1, "moving Mob cycles to next frame")

_ = movingController.update(deltaTime: 28.0 / 30.0)
expectEqual(movingController.state.activity, .standing, "Mob switches from moving to standing")
let beforeStandX = movingController.state.x
let standing = movingController.update(deltaTime: 1.0 / 30.0)
expectEqual(standing.x, beforeStandX, "standing Mob does not change X")
expectEqual(standing.frame, 2, "standing Mob uses stand frame list")

let randomizedController = MobController(
    configuration: movementConfiguration,
    randomSource: SequenceRandomSource([0.9, 0.9, 0.5, 0]),
    initialX: nil,
    initialDirection: nil,
    initiallyMoving: nil
)
expect(
    (movementConfiguration.lowerBound...movementConfiguration.upperBound)
        .contains(randomizedController.state.x),
    "random Mob initialization remains inside range"
)

let topLeftFrame = WETextureFrame(
    imageIndex: 0,
    duration: 0.1,
    x: 0,
    y: 0,
    width: 44,
    height: 34
)
let normalizedTopLeft = topLeftFrame.normalizedRect(textureWidth: 88, textureHeight: 68)
expectEqual(normalizedTopLeft.origin.x, 0, "top-left TEX frame maps to left texture edge")
expectEqual(normalizedTopLeft.origin.y, 0.5, "top-left TEX frame flips Y for SpriteKit")
expectEqual(normalizedTopLeft.width, 0.5, "TEX frame width is normalized")
expectEqual(normalizedTopLeft.height, 0.5, "TEX frame height is normalized")

expectEqual(WESpriteScene.zPosition(forObjectIndex: 0), 0, "first scene object gets base Z")
expectEqual(WESpriteScene.zPosition(forObjectIndex: 57), 57, "scene order maps to increasing Z")
expectEqual(
    WESpriteScene.horizontalScale(baseScale: 1, direction: -1),
    -1,
    "Mob direction flips a sprite horizontally"
)
expectEqual(
    WESpriteScene.horizontalScale(baseScale: 2, direction: 1),
    2,
    "Mob direction preserves base scale magnitude"
)

let activeAudioState = SceneAudioPlaybackState(
    playRate: 1,
    volume: 0.6,
    isSleeping: false
)
expect(activeAudioState.shouldPlayAudio, "active scene audio should play")
expect(activeAudioState.shouldAnimateScene, "active scene visuals should animate")
expectEqual(activeAudioState.effectivePlayerRate, 1, "scene audio uses the selected playback rate")
expectEqual(activeAudioState.effectiveVolume, 0.6, "scene audio uses the selected volume")

let mutedAudioState = SceneAudioPlaybackState(
    playRate: 1,
    volume: 0,
    isSleeping: false
)
expect(mutedAudioState.shouldPlayAudio, "muting does not pause scene audio timing")
expect(mutedAudioState.shouldAnimateScene, "muting leaves scene visuals active")
expectEqual(mutedAudioState.effectiveVolume, 0, "muting sets scene audio volume to zero")

let pausedAudioState = SceneAudioPlaybackState(
    playRate: 0,
    volume: 1,
    isSleeping: false
)
expect(!pausedAudioState.shouldPlayAudio, "zero playback rate pauses scene audio")
expect(!pausedAudioState.shouldAnimateScene, "zero playback rate pauses scene visuals")

let sleepingAudioState = SceneAudioPlaybackState(
    playRate: 1,
    volume: 1,
    isSleeping: true
)
expect(!sleepingAudioState.shouldPlayAudio, "display sleep pauses scene audio")
expect(!sleepingAudioState.shouldAnimateScene, "display sleep pauses scene visuals")

let missingAudioController = SceneAudioController()
missingAudioController.load(data: nil)
missingAudioController.update(playRate: 1, volume: 1)
expect(!missingAudioController.hasAudio, "missing audio data does not create a player")
expect(
    missingAudioController.playbackState.shouldAnimateScene,
    "missing audio leaves scene visuals active"
)

if failures > 0 {
    print("\n\(failures) test(s) failed")
    exit(1)
}

print("\nAll scene runtime tests passed")
