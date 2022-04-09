import easyess


## === Components ===

type
  Vector2 = object
    x: float
    y: float

  Position {.comp.} = Vector2

  Velocity {.comp.} = Vector2

## === Systems ===

proc positionSystem*(ecs: ECS) {.sys: (pos: Position, Velocity),
                                 group: "logicSystems".} =
  for entity in ecs.queryAll(signature):
    entity.pos.x += entity.velocity.x
    entity.pos.y += entity.velocity.y

proc velocitySystem*(ecs: ECS, drag: float) {.sys: (vel: Velocity),
                                              group: "logicSystems",
                                              all.} =
  vel.x *= drag
  vel.y *= drag

proc debugSystem(ecs: ECS) {.sys: (), group: "logicSystems".} =
  for item in ecs.queryAllItems(signature):
    echo "[debug]\n", inspect(item)


## === Main ===

when isMainModule:
  makeECS()

  var
    ecs = newECS()

  discard ecs.createIt():
    it.addPosition(Vector2(x: 0.0, y: 0.0))
    it.addComponent(velocity = Velocity(x: 10.0, y: 10.0))

  for i in 1..5:
    echo "\nRound ", i, ":"
    ecs.runLogicSystems(drag = 0.9)
