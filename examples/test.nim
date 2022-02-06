
import easyess


# Define components using the `comp` macro.

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

    Value = distinct int

    IsDead = bool


# Define systems using the `sys` macro.
# Specify which components are needed using `[Component1, Component2]` and
# the 'group' that this system belongs to using a string.
# The system should be a `proc` or `func` that takes an item with a unique name
# of your chosing
const
  systemsGroup = "systems"
  renderingGroup = "rendering"

sys [Position, Velocity], systemsGroup:
  func moveSystem(item: MoveItem) =
    let (ecs, entity) = item

    let oldPosition = position
    position.x += velocity.dx
    position.y += velocity.dy

    debugEcho "Moved " & ecs.inspect(entity) & " from ", oldPosition, " to ", position


# Systems can have side-effects when marked
# as `proc` and access variables either outside
# the entire `sys` macro. Variables can also be defined
# within the `sys` block, but will still be considered
# global.

var oneGlobalValue = 1

sys [Sprite], renderingGroup:
  var secondGlobalValue = "Renderingwindow"

  proc renderSpriteSystem(item: SpriteItem) =
    echo secondGlobalValue, ": Rendering sprite #", sprite.id
    inc oneGlobalValue


sys [IsDead], systemsGroup:
  proc isDeadSystem(item: DeadItem) =
    echo isDead

sys [CustomFlag], systemsGroup:
  proc customFlagSystem(item: CustomFlagItem) =
    echo customFlag

    case customFlag:
      of ckTest: echo "Hello, World"
      else: echo "Unsupported type: " & $customFlag

# Once all components and systems have been defined or
# imported, call `createECS` with a `ECSConfig`. The order
# matters here and `createECS` has to be called AFTER component
# and system definitions.
createECS(ECSConfig(maxEntities: 100))

when isMainModule:
  # The ecs state can be instantiated using `newECS` (created by `createECS`)
  let ecs = newECS()

  # Entities can be instantiated either manually (cumbersome, see below)
  # or using the template `registerEntity` which takes a debug label that
  # will be ignored `when defined(release)`, as well as a list of Components

  let entity = ecs.registerEntity("Player"): (
    Position(x: 10.0, y: 0.0),
    Velocity(dx: 1.0, dy: -1.0),

    [Sprite](id: 42, potato: 12),
    [CustomFlag]ckTest,
    [Name]"Player",
    [Value]10,
    [IsDead]false
  )

  # The Entity object is simply an integer ID
  echo entity

  # You can inspect it using `ecs.inspect` which will
  # return a useful string for debugging in debug mode
  # and simply the ID in release mode.
  when not defined(release):
    echo ecs.inspect(entity)

  # Will run all systems in the "systems" group 10 times
  for i in 0 ..< 10:
    ecs.runSystems()

  # Will run all systems in the "rendering" group once
  ecs.runRendering()
