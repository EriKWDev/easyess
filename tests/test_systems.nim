
import easyess, unittest

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

    TupleComponent = tuple
      test: string

    CustomFlag = enum
      cfTest
      cfPotato

    Name = string

    Health = distinct int

    Die = bool


const
  systemsGroup = "systems"
  renderingGroup = "rendering"


sys [Position, Velocity], systemsGroup:
  func moveSystem(item: MoveItem) =
    let (ecs, entity) = item

    let oldPosition = position

    position.x += velocity.dx
    position.y += velocity.dy

sys [Die], systemsGroup:
  func isDeadSystem(item: DeadItem) =
    discard

sys [CustomFlag], systemsGroup:
  func customFlagSystem(item: CustomFlagItem) =
    case customFlag:
      of cfTest: customFlag = cfPotato
      else: customFlag = cfTest


sys [Sprite], renderingGroup:
  var oneGlobalValue = 0

  proc renderSpriteSystem(item: SpriteItem) =
    inc oneGlobalValue
    sprite = (id: 360)



createECS(ECSConfig(maxEntities: 100))

const suiteName = when defined(release): "release" else: "debug"

suite "Systems: " & suiteName:
  test "Simple system gets executed everytime 'run<SystemGroup>()' is called":
    let
      ecs = newEcs()
      entity = ecs.registerEntity("Entity"): (
        Position(x: 0.0, y: 0.0),
        Velocity(dx: 10.0, dy: -10.0),
      )

    check ecs.positionContainer[entity.idx].x == 0.0
    check ecs.positionContainer[entity.idx].y == 0.0

    for i in 1 .. 10:
      ecs.runSystems()
      check ecs.positionContainer[entity.idx].x == 10.0 * toFloat(i)
      check ecs.positionContainer[entity.idx].y == -10.0 * toFloat(i)

  test "Can run system group without running other group":
    let
      ecs = newEcs()
      entity = ecs.registerEntity("Entity"): (
        Position(x: 0.0, y: 0.0),
        Velocity(dx: 10.0, dy: -10.0),
        [Sprite](id: 10),
        [CustomFlag]cfTest
      )

    check ecs.positionContainer[entity.idx].x == 0.0
    check ecs.positionContainer[entity.idx].y == 0.0
    check ecs.customFlagContainer[entity.idx] == cfTest
    check ecs.spriteContainer[entity.idx].id == 10

    ecs.runSystems()
    check ecs.positionContainer[entity.idx].x == 10.0
    check ecs.positionContainer[entity.idx].y == -10.0
    check ecs.customFlagContainer[entity.idx] == cfPotato
    check ecs.spriteContainer[entity.idx].id == 10

    ecs.runRendering()
    check ecs.spriteContainer[entity.idx].id == 360
    check ecs.positionContainer[entity.idx].x == 10.0
    check ecs.customFlagContainer[entity.idx] == cfPotato
    check ecs.positionContainer[entity.idx].y == -10.0
