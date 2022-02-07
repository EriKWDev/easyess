import unittest, easyess

comp:
  type
    ObjectComponent = object
      data1: int
      data2: string

    TestComponent = tuple[a, b: int]

const numberOfComponents = 2

createECS()

const suiteName = when defined(release): "release" else: "debug"

suite "Components: " & suiteName:
  test "ComponentKind is declared":
    check declared(ComponentKind)

  test "ckExists is a declared":
    check declared(ckExists)
    check ckExists in {low(ComponentKind) .. high(ComponentKind)}
    check ord(ckExists) == 0

  test "Number of declared ComponentKind enums matches the number of declared components":
    check declared(ckObjectComponent)
    check declared(ckTestComponent)

    check len(low(ComponentKind) .. high(ComponentKind)) ==
        numberOfComponents + 1 # ckExists...

    check ord(ckObjectComponent) == 1
    check ord(ckTestComponent) == 2

  test "Can define object component":
    var a: ObjectComponent = ObjectComponent(data1: 1, data2: "Hello, World!")
    check declared(a)

  test "addComponent and removeComponent declared":
    check declared(addObjectComponent)
    check declared(removeObjectComponent)
    check declared(addTestComponent)
    check declared(removeTestComponent)
