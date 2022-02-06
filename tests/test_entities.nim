import unittest, easyess, intsets, strutils, sets

comp:
  type
    DataFlag = enum
      dfOne,
      dfTwo,
      dfThree

    DataComponent = tuple
      data1: int
      data2: string

    ObjectComponent = object
      data1: int
      data2: string

    ObjectComponent2 = object
      data3: DataFlag
      data4: float

    Position = object
      x: float
      y: float


createECS()

const suiteName = when defined(release): "release" else: "debug"

suite "Entities: " & suiteName:
  test "Can create entity":
    let
      ecs = newEcs()
      entity = ecs.newEntity("Potato")

    check entity.idx == 0

  test "Subsequent entities have unique IDs":
    let ecs = newEcs()
    var ids: IntSet

    for i in 0 .. high(ecs.entities):
      let currentID = ecs.newEntity("Potato").idx
      check currentID notin ids
      ids.incl(currentID)

  test "Error when last entity ID used":
    let ecs = newEcs()

    for i in 0 .. high(ecs.entities):
      let currentID = ecs.newEntity("Potato").idx

    expect(IndexDefect):
      let a = ecs.newEntity("Potato").idx

  when not defined(release):
    test "Debug label always unique for subsequent entities with same label":
      let
        ecs = newEcs()
        label = "Debug Entity"

      var labels: HashSet[string]

      for i in 0 .. 10:
        let
          entity = ecs.newEntity(label)
          actualLabel = ecs.inspect(entity)

        check actualLabel notin labels and label in actualLabel
        labels.incl(actualLabel)

    test "Debug label present in debug mode":
      let
        ecs = newEcs()
        label = "Debug Entity"
        entity = ecs.newEntity(label)

      check label in ecs.inspect(entity)
  else:
    test "Debug label contains ID in release mode":
      let
        ecs = newEcs()
        label = "Release Entity"

      var labels: HashSet[string]

      for i in 0 .. 10:
        let
          entity = ecs.newEntity(label)
          actualLabel = ecs.inspect(entity)
        check actualLabel notin labels and $entity.idx in actualLabel and
            label notin actualLabel

        labels.incl(actualLabel)

    test "Debug label not present release mode":
      let
        ecs = newEcs()
        label = "Release Entity"
        entity = ecs.newEntity(label)

      check label notin ecs.inspect(entity)

  test "Can register empty entity using template":
    let
      ecs = newEcs()
      entity = ecs.registerEntity("Entity"): ()

    check ecs.entities[entity.idx] == {ckExists}

  test "Can register empty entity manually":
    let
      ecs = newEcs()
      entity = ecs.newEntity("Entity")
    ecs.register(entity, {})

    check ecs.entities[entity.idx] == {ckExists}

  test "Can register entity with only one component using template":
    let
      ecs = newEcs()
      entity = ecs.registerEntity("Entity"): (
        Position(x: 42.0, y: 0.0)
      )
      entity2 = ecs.registerEntity("Entity"): (
        Position(x: 69.0, y: 0.0),
      )

    check ecs.positionContainer[entity.idx].x == 42.0
    check ecs.positionContainer[entity2.idx].x == 69.0

  test "Can register entity using template with non-object components":
    let
      ecs = newEcs()
      entity = ecs.registerEntity("Entity"): (
        [DataFlag]dfThree,
        [DataComponent](data1: 42, data2: "test")
      )

    check ecs.entities[entity.idx] == {ckExists, ckDataFlag, ckDataComponent}
    check ecs.dataFlagContainer[entity.idx] == dfThree
    check ecs.dataComponentContainer[entity.idx].data1 == 42

  test "Can register entity using template with object component":
    let
      ecs = newEcs()
      entity = ecs.registerEntity("Entity"): (
        ObjectComponent(data1: 69, data2: "hello"),
        ObjectComponent2(data3: dfTwo, data4: 3.141592),
        [DataFlag]dfThree,
        [DataComponent](data1: 42, data2: "test")
      )

    check ecs.entities[entity.idx] ==
      {ckExists, ckDataFlag, ckDataComponent, ckObjectComponent, ckObjectComponent2}

    check ecs.objectComponentContainer[entity.idx].data1 == 69
    check ecs.objectComponent2Container[entity.idx].data3 == dfTwo
    check ecs.objectComponent2Container[entity.idx].data4 == 3.141592
    check ecs.dataFlagContainer[entity.idx] == dfThree
    check ecs.dataComponentContainer[entity.idx].data1 == 42
