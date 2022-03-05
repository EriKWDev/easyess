
import easyess


type
  Game = object
    value: int

comp:
  type
    Position = object
      x: float
      y: float

    Velocity = object
      dx: float
      dy: float

    Sprite = tuple
      id: int
      potato: int

    TupleComponent = tuple
      test: string

    CustomFlag = enum
      ckTest
      ckPotato

    Name = string

    Value = int

    DistinctValue = distinct int

    IsDead = bool

const
  systemsGroup = "systems"
  renderingGroup = "rendering"

sys [Position, Velocity], systemsGroup:
  func moveSystem(item: Item) =
    let
      (ecs, entity) = item
      oldPosition = position
    position.x += velocity.dx

    item.position.y += item.velocity.dy
    when not defined(release):
      debugEcho "Moved " & ecs.inspect(entity) & " from ", oldPosition, " to ", position


var oneGlobalValue = 1

sys [Sprite], renderingGroup:
  var secondGlobalValue = "Renderingwindow"

  proc renderSpriteSystem(item: Item, game: var Game) =
    echo secondGlobalValue, ": Rendering sprite #", sprite.id
    inc oneGlobalValue
    inc game.value

sys [dead: IsDead], systemsGroup:
  proc isDeadSystem(item: Item) =
    echo dead

sys [CustomFlag], systemsGroup:
  proc customFlagSystem(item: Item) =
    echo customFlag

    case customFlag:
      of ckTest: customFlag = ckPotato
      of ckPotato: customFlag = ckTest

createECS(ECSConfig(maxEntities: 100))

when isMainModule:
  let ecs = newECS()
  var game = Game(value: 0)

  let entity1 = ecs.createEntity("Entity 1"): (
    Position(x: 10.0, y: 0.0),
    Velocity(dx: 1.0, dy: -1.0),

    [Sprite](id: 42, potato: 12),
    [CustomFlag]ckTest,
    [Name]"SomeNiceName",
    [Value]10,
    [DistinctValue]20,
    [IsDead]true
  )

  let entity2 = ecs.newEntity("Entity 2")
  (ecs, entity2).addComponent(Position(x: 10.0, y: 10.0))
  (ecs, entity2).addVelocity(Velocity(dx: 1.0, dy: -1.0))

  let item = (ecs, entity2)
  item.addComponent(sprite = (id: 42, potato: 12))

  item.addCustomFlag(ckTest)
  item.addName("SomeNiceName")
  item.addValue(10)
  item.addDistinctValue(20.DistinctValue)
  item.addIsDead(true)

  item.removeComponent(IsDead)
  (ecs, entity1).removeIsDead()

  item.position.x += 20.0
  when false:
    item.isDead

  echo " == Components of entity2 == "
  echo item.position
  echo item.velocity
  echo item.sprite
  echo item.customFlag
  echo "..."

  echo "\n == ID of entity1 == "
  echo entity1
  echo typeof(entity1)

  when not defined(release):
    echo "\n == ecs.inspect(entity1) == "
    echo ecs.inspect(entity1)

  echo "\n == Running \"systems\" group 10 times == "
  for i in 0 ..< 10:
    ecs.runSystems()

  echo "\n == Running \"moveSystem\" alone 10 times == "
  for i in 0 ..< 10:
    ecs.runMoveSystem()

  echo "\n == Running \"rendering\" group once == "
  doAssert game.value == 0
  ecs.runRendering(game)
  doAssert game.value == 1

  echo "\n == Querying {ckPosition} entities == "
  for entity in ecs.queryAll({ckPosition}):
    echo ecs.inspect(entity)

  (ecs, entity1).removePosition()
  echo "\n == Querying {ckPosition} entities after removing Position from entity1 == "
  for entity in ecs.queryAll({ckPosition}):
    echo ecs.inspect(entity)

  echo "\n == Querying {ckExists} entities == "
  for entity in ecs.queryAll({ckExists}):
    echo ecs.inspect(entity)

  echo (ecs, entity1).getSignature()

  echo "\n == Querying entities that have all of entity1's components or more == "
  for entity in ecs.queryAll((ecs, entity1).getSignature()):
    echo ecs.inspect(entity)
