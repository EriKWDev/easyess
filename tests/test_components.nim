import unittest, easyess

comp:
  type
    ObjectComponent = object
      data1: int
      data2: string

const numberOfComponents = 1

createECS()

const suiteName = when defined(release): "release" else: "debug"

suite "Components: " & suiteName:
  test "ckExists is a valid ComponentKind":
    check declared(ckExists)
    check ckExists in {low(ECSComponentKind) .. high(ECSComponentKind)}
    check ord(ckExists) == 0

  test "All components have corresponding ComponentKind enums":
    check declared(ckObjectComponent)

    check len(low(ECSComponentKind) .. high(ECSComponentKind)) ==
        numberOfComponents + 1 # ckExists...

    check ord(ckObjectComponent) == 1

  test "Can define object component":
    var a: ObjectComponent = ObjectComponent(data1: 1, data2: "Hello, World!")
    check declared(a)
