import unittest, easyess, common

type
  ObjectComponent {.comp.} = object
    data1: int
    data2: string

  TestComponent {.comp.} = tuple[a, b: int]

const numberOfComponents = 2

createECS()

suite "Components: " & suiteName:
  test "ComponentKind is declared":
    check declared(ComponentKind)

  test "Number of declared ComponentKind enums matches the number of declared components":
    check declared(ckObjectComponent)
    check declared(ckTestComponent)

    check len(low(ComponentKind) .. high(ComponentKind)) == numberOfComponents

    check ord(ckObjectComponent) == 0
    check ord(ckTestComponent) == 1

  test "Can define object component":
    var a: ObjectComponent = ObjectComponent(data1: 1, data2: "Hello, World!")
    check declared(a)

  test "addComponent and removeComponent declared":
    check declared(addObjectComponent)
    check declared(removeObjectComponent)
    check declared(addTestComponent)
    check declared(removeTestComponent)
