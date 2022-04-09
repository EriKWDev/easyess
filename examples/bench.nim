import easyess

type
  Vector2 = object
    x: float
    y: float

  Position {.comp.} = Vector2

  Velocity {.comp.} = Vector2

proc positionVelocitySystem(ecs: ECS) {.sys: (pos: Position, vel: Velocity), group: "logicSystems", inline.} =
  for item in ecs.queryAllItems(signature):
    item.pos.x += item.vel.x
    item.pos.y += item.vel.y

proc dampingSystem(ecs: ECS) {.sys: (vel: Velocity), group: "logicSystems", all, inline.} =
  vel.x *= 0.9
  vel.y *= 0.9

makeECS()

const
  numberOfEntities = 500_000
  numberOfRounds = 100

proc initWorld(ecs: ECS) =
  var f = 0.0

  for i in 0..<numberOfEntities:
    ecs.newItem() do (item: Item):
      item.position = Vector2(x: 0.0, y: 0.0)
      item.velocity = Vector2(x: f, y: f)

    f += 0.8

proc main() =
  for i in 0..<5:
    var ecs = newEcs()
    ecs.initWorld()
    for _ in 0..<numberOfRounds:
      ecs.runLogicSystems()

when isMainModule:
  main()

# Compile using -d:ecsSecTables to use SecTable implementation.
# Also try:
# -d:danger
# --passC:"-flto -ffast-math" --passL:"-flto"
