import Foundation

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

if failures > 0 {
    print("\n\(failures) test(s) failed")
    exit(1)
}

print("\nAll scene runtime tests passed")
