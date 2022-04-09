import unittest, easyess, intsets, common

type
  DataFlag {.comp.} = enum
    dfOne,
    dfTwo,
    dfThree

  DataComponent {.comp.} = tuple
    data1: int

  ObjectComponent {.comp.} = object
    data1: int

  ObjectComponent2 {.comp.} = object
    data3: DataFlag
    data4: float

  Position {.comp.} = object
    x: float
    y: float

  Pos {.comp.} = tuple[x, y: float]

  Vel {.comp.} = tuple[x, y: float]

  Sprite {.comp.} = uint16


createECS()

suite "Entities: " & suiteName:
  test "Can create entity":
    var
      ecs = newECS()
      entity = ecs.newEntity()

    check entity.idx == 0
    check (ecs, entity).signature == {}

  test "Can remove enetity":
    var
      ecs = newECS()
      entity = ecs.newEntity()

    check entity.idx == 0
    check entity.version == 1
    ecs.removeEntity(entity)
    let ent2 = ecs.newEntity()
    check ent2.idx == 0 and ent2.version > 1

  test "Subsequent entities have unique IDs":
    var
      ecs = newECS()
      ids: IntSet

    for i in 0 ..< 400:
      let currentID = ecs.newEntity().idx
      check currentID notin ids
      ids.incl(currentID)

  test "Can create entity by adding components":
    var
      ecs = newECS()
      player = ecs.newEntity()
      item: Item = (ecs, player)

    item.addPos((50.0, 50.0))
    item.addComponent(vel = (10.0, 10.0))
    item.sprite = 42

    check ecs.signatures[player] == {ckPos, ckVel, ckSprite}

    check ecs.posContainer[player.idx].x == 50.0
    check ecs.velContainer[player.idx].x == 10.0
    check ecs.spriteContainer[player.idx] == 42

  test "Can create entity using createIt template":
    var
      ecs = newECS()
      player = ecs.createIt():
        it.addPos((50.0, 50.0))
        it.addComponent(vel = (10.0, 10.0))
        it.sprite = 42

    check ecs.signatures[player.entity] == {ckPos, ckVel, ckSprite}

    check ecs.posContainer[player.entity.idx].x == 50.0
    check ecs.velContainer[player.entity.idx].x == 10.0
    check ecs.spriteContainer[player.entity.idx] == 42

  test "Can create entity using do notation":
    var
      ecs = newECS()
      player = ecs.newItem() do (item: Item):
        item.addPos((50.0, 50.0))
        item.sprite = 42

    check ecs.signatures[player.entity] == {ckPos, ckSprite}

    check ecs.posContainer[player.entity.idx].x == 50.0
    check ecs.spriteContainer[player.entity.idx] == 42
