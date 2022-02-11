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

    Pos = tuple[x, y: float]

    Vel = tuple[x, y: float]

    Sprite = uint16

    Name = string


createECS()

const suiteName = when defined(release): "release" else: "debug"

suite "Entities: " & suiteName:
  test "Can create entity":
    let
      ecs = newEcs()
      entity = ecs.newEntity("Potato")

    check entity.idx == 0

  test "Can remove enetity":
    let
      ecs = newEcs()
      entity = ecs.newEntity()

    check entity.idx == 0
    check ecs.nextID.idx == 1
    check ecs.highestID.idx == 0

    ecs.removeEntity(entity)

    check ecs.nextID.idx == 0
    check ecs.highestID.idx == 0
    check ckExists notin ecs.signatureContainer[entity.idx]
  
  test "Can remove enetity (more)":
    let
      ecs = newEcs()
      entity0 = ecs.newEntity()
      entity1 = ecs.newEntity()
      entity2 = ecs.newEntity()
      entity3 = ecs.newEntity()

    ecs.removeEntity(entity1)
    ecs.removeEntity(entity2)

    check ecs.nextID.idx == 1
    check ecs.highestID.idx == 3
    
    ecs.removeEntity(entity0)

    check ecs.nextID.idx == 0
    check ecs.highestID.idx == 3

    ecs.removeEntity(entity3)

    check ecs.nextID.idx == 0
    check ecs.highestID.idx == 0

  
  test "Cannot remove entity that doesn't exist":
    let
      ecs = newEcs()
    
    expect(AssertionDefect):
      ecs.removeEntity(Entity(12))


  test "ECS nextID and highestID gets updated correctly":
    let ecs = newEcs()
    
    check ecs.nextID.idx == 0
    check ecs.highestID.idx == 0

    let entity00 = ecs.newEntity()

    check ecs.nextID.idx == 1
    check ecs.highestID.idx == 0

    ecs.removeEntity(entity00)

    check ecs.nextID.idx == 0
    check ecs.highestID.idx == 0

    let
      entity10 = ecs.newEntity()
      entity11 = ecs.newEntity()
      entity12 = ecs.newEntity()
      entity13 = ecs.newEntity()
  
    check ecs.nextID.idx == 4
    check ecs.highestID.idx == 3

    (ecs, entity11).removeEntity() # can be called as `Item` as well...

    check ecs.nextID.idx == 1
    check ecs.highestID.idx == 3

    ecs.removeEntity(entity12)

    check ecs.nextID.idx == 1
    check ecs.highestID.idx == 3

    ecs.removeEntity(entity13)

    check ecs.nextID.idx == 1
    check ecs.highestID.idx == 0


  test "Subsequent entities have unique IDs":
    let ecs = newEcs()
    var ids: IntSet

    for i in 0 .. high(ecs.signatureContainer):
      let currentID = ecs.newEntity("Potato").idx
      check currentID notin ids
      ids.incl(currentID)

  test "Error when last entity ID used":
    let ecs = newEcs()

    for i in 0 .. high(ecs.signatureContainer):
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
      entity = ecs.createEntity("Entity"): ()

    check ecs.signatureContainer[entity.idx] == {ckExists}

  test "Can register empty entity manually":
    let
      ecs = newEcs()
      entity = ecs.newEntity("Entity")

    check ecs.signatureContainer[entity.idx] == {ckExists}

  test "Can register entity with only one component using template":
    let
      ecs = newEcs()
      entity = ecs.createEntity("Entity"): (
        Position(x: 42.0, y: 0.0)
      )
      entity2 = ecs.createEntity("Entity"): (
        Position(x: 69.0, y: 0.0),
      )
      entity3 = ecs.createEntity("Entity"): ([Name]"test")
      entity4 = ecs.createEntity("Entity"): ([Name]"test",)
      entity5 = ecs.createEntity("Entity"): (
        [Name]"test"
      )
      entity6 = ecs.createEntity("Entity"): ([DataComponent](data1: 10, data2: "test"))
      entity7 = ecs.createEntity("Entity"): ([DataComponent](data1: 10, data2: "test"),)

    check ecs.positionContainer[entity.idx].x == 42.0
    check ecs.positionContainer[entity2.idx].x == 69.0
    check (ecs, entity3).name == "test"
    check (ecs, entity4).name == "test"
    check (ecs, entity5).name == "test"
    check (ecs, entity6).dataComponent.data1 == 10
    check (ecs, entity7).dataComponent.data1 == 10

  test "Can register entity using template with non-object components":
    let
      ecs = newEcs()
      entity = ecs.createEntity("Entity"): (
        [DataFlag]dfThree,
        [DataComponent](data1: 42, data2: "test")
      )

    check ecs.signatureContainer[entity.idx] == {ckExists, ckDataFlag, ckDataComponent}
    check ecs.dataFlagContainer[entity.idx] == dfThree
    check ecs.dataComponentContainer[entity.idx].data1 == 42

  test "Can register entity using template with object component":
    let
      ecs = newEcs()
      entity = ecs.createEntity("Entity"): (
        ObjectComponent(data1: 69, data2: "hello"),
        ObjectComponent2(data3: dfTwo, data4: 3.141592),
        [DataFlag]dfThree,
        [DataComponent](data1: 42, data2: "test")
      )

    check ecs.signatureContainer[entity.idx] ==
      {ckExists, ckDataFlag, ckDataComponent, ckObjectComponent, ckObjectComponent2}

    check ecs.objectComponentContainer[entity.idx].data1 == 69
    check ecs.objectComponent2Container[entity.idx].data3 == dfTwo
    check ecs.objectComponent2Container[entity.idx].data4 == 3.141592
    check ecs.dataFlagContainer[entity.idx] == dfThree
    check ecs.dataComponentContainer[entity.idx].data1 == 42

  test "Can create entity by adding components using functions":
    let
      ecs = newEcs()

      player = ecs.newEntity("Player")
      item = (ecs, player)

    item.addPos((50.0, 50.0))
    item.addVel((10.0, 10.0))
    item.addSprite(42)

    check ecs.posContainer[player.idx].x == 50.0
    check ecs.velContainer[player.idx].x == 10.0
    check ecs.spriteContainer[player.idx] == 42

    check item.pos.x == ecs.posContainer[player.idx].x
    check item.vel.x == ecs.velContainer[player.idx].x
    check item.sprite == ecs.spriteContainer[player.idx]

  test "Add components to entity using addComponet and add<ComponentName>":
    for i in 1 .. 2:
      let
        ecs = newECS()
        entity = ecs.createEntity("Entity"): (
          ObjectComponent(data1: 123, data2: "123")
        )

      check ecs.signatureContainer[entity.idx] == {ckExists, ckObjectComponent}
      check ecs.objectComponentContainer[entity.idx].data1 == 123
      check ecs.positionContainer[entity.idx].x == 0.0

      # ecs.addComponent(entity, Position(x: 10.0, y: 10.0))
      case i:
        of 1: (ecs, entity).addComponent(Position(x: 10.0, y: 10.0))
        of 2: (ecs, entity).addPosition(Position(x: 10.0, y: 10.0))
        else: discard

      check ecs.signatureContainer[entity.idx] == {ckExists, ckObjectComponent, ckPosition}
      check ecs.positionContainer[entity.idx].x == 10.0

  test "Remove components from entity using removeComponent and remove<ComponentName>":
    for i in 1 .. 2:
      let
        ecs = newECS()
        entity = ecs.createEntity("Entity"): (
          ObjectComponent(data1: 123, data2: "123"),
          Position(x: 10.0, y: 10.0)
        )

      check ecs.signatureContainer[entity.idx] == {ckExists, ckObjectComponent, ckPosition}
      check ecs.objectComponentContainer[entity.idx].data1 == 123
      check ecs.positionContainer[entity.idx].x == 10.0

      case i:
      of 1: (ecs, entity).removeComponent(Position)
      of 2: (ecs, entity).removePosition()
      else: discard

      check ecs.signatureContainer[entity.idx] == {ckExists, ckObjectComponent}

  test "Cannot add component that already exists":
    let
      ecs = newECS()
      entity = ecs.createEntity("Entity"): (
        ObjectComponent(data1: 123, data2: "123"),
      )

    expect(AssertionDefect):
      (ecs, entity).addObjectComponent(ObjectComponent(data1: 456, data2: "456"))
    (ecs, entity).addPosition(Position(x: 10.0, y: 10.0))

  test "Cannot remove component that doesn't exists":
    let
      ecs = newECS()
      entity = ecs.createEntity("Entity"): (
        ObjectComponent(data1: 123, data2: "123"),
      )

    expect(AssertionDefect):
      (ecs, entity).removePosition()
    (ecs, entity).removeObjectComponent()

  test "Cannot access component that doesn't exists":
    let
      ecs = newECS()
      entity = ecs.createEntity("Entity"): (
        ObjectComponent(data1: 123, data2: "123"),
      )

    expect(AssertionDefect):
      discard (ecs, entity).position

    discard (ecs, entity).objectComponent
