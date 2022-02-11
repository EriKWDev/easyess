import easyess

comp:
  type
    Position = object
      x: float
      y: float

    Velocity = object
      dx: float
      dy: float


sys [Position, Velocity], "systems":
  func moveSystem(item: Item) =
    let
      (ecs, entity) = item
      oldPosition = position

    position.y += velocity.dy
    item.position.x += item.velocity.dx

    when not defined(release):
      debugEcho "Moved " & ecs.inspect(entity) & " from ", oldPosition, " to ", position


createECS(ECSConfig(maxEntities: 100))

when isMainModule:
  let
    ecs = newECS()
    entity1 = ecs.registerEntity("Entity 1"): (
      Position(x: 0.0, y: 0.0),
      Velocity(dx: 10.0, dy: -10.0)
    )
    # entity2 = ecs.newEntity("Entity 2")

  # (ecs, entity2).addComponent(Position(x: 0.0, y: 0.0))
  # (ecs, entity2).addVelocity(Velocity(dx: -10.0, dy: 10.0))

  # for i in 1 .. 10:
  #   ecs.runSystems()
