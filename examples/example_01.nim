
import easyess


type
  Game = object
    value: int

# Define components using the `comp` macro. Components can have any type
# that doesn't use generics.
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

# Define systems using the `sys` macro.
# Specify which components are needed using `[Component1, Component2]` and
# the 'group' that this system belongs to using a string.
# The system should be a `proc` or `func` that takes an argument of type `Item`
# The `Item` type is a `tuple[ecs: ECS, entity: Entity]`.
const
  systemsGroup = "systems"
  renderingGroup = "rendering"

sys [Position, Velocity], systemsGroup:
  func moveSystem(item: Item) =
    let
      (ecs, entity) = item
      oldPosition = position
    # Inside your system, templates are defined corresponging to
    # the Components that you have requested. `Position` nad `Velocity`
    # were requested here, so now 'position' and 'velocity' are available
    position.x += velocity.dx

    # You can also do `item.position` explicitly, but it is also a template
    item.position.y += item.velocity.dy
    when not defined(release):
      debugEcho "Moved " & ecs.inspect(entity) & " from ", oldPosition, " to ", position


# Systems can have side-effects when marked
# as `proc` and access variables either outside
# the entire `sys` macro or 'within' it, but those
# defined on the inside will still be considered global.

# You can also pass an extra 'Data' parameter to a system
# by specifying it after the `Item`. You must later provide
# a variable of that same type when you call the system's group!

var oneGlobalValue = 1

sys [Sprite], renderingGroup:
  var secondGlobalValue = "Renderingwindow"

  proc renderSpriteSystem(item: Item, game: var Game) =
    # Note that we request `var Game` here -------^^^^^^^^
    # That means that when we later call `ecs.runRendering()`,
    # we will have to supply an extra argument of the same type!
    # like so: `ecs.runRendering(game)`

    echo secondGlobalValue, ": Rendering sprite #", sprite.id
    inc oneGlobalValue
    inc game.value


sys [IsDead], systemsGroup:
  proc isDeadSystem(item: Item) =
    echo isDead

sys [CustomFlag], systemsGroup:
  proc customFlagSystem(item: Item) =
    echo customFlag

    # State machines can be implemented using a single enum as the component!
    case customFlag:
      of ckTest: customFlag = ckPotato
      of ckPotato: customFlag = ckTest

# Once all components and systems have been defined or
# imported, call `createECS` with a `ECSConfig`. The order
# matters here and `createECS` has to be called AFTER component
# and system definitions.
createECS(ECSConfig(maxEntities: 100))

when isMainModule:
  # The ecs state can be instantiated using `newECS` (created by `createECS`)
  let ecs = newECS()
  var game =  Game(value: 0)

  # Entities can be instantiated either manually  or using the template
  # `registerEntity` which takes a debug label that will be ignored
  # `when defined(release)`, as well as a tuple of Components
  # For the template to work with non-object components, the type
  # has to be specified within brackets as `[<ComponentName>]<instantiation>`
  let entity1 = ecs.registerEntity("Entity 1"): (
    Position(x: 10.0, y: 0.0),
    Velocity(dx: 1.0, dy: -1.0),

    [Sprite](id: 42, potato: 12),
    [CustomFlag]ckTest,
    [Name]"SomeNiceName",
    [Value]10,
    [DistinctValue]20,
    [IsDead]true
  )

  # Entities can also be instantiated manually as such
  let entity2 = ecs.newEntity("Entity 2")
  # To add components, use `item.addComponent(component)` or using
  # `item`.add<ComponentName>()`. `item` is simply a tuple containing
  # the ecs and the entity in question.
  (ecs, entity2).addComponent(Position(x: 10.0, y: 10.0))
  (ecs, entity2).addVelocity(Velocity(dx: 1.0, dy: -1.0))

  let item = (ecs, entity2)
  # if the call could be ambiguous (such as when using tuples)
  # the `<componentName>` can be explicitly assigned to
  item.addComponent(sprite = (id: 42, potato: 12))
  # or just use `item.addSprite((id: 42, potato: 12))`

  item.addCustomFlag(ckTest)
  item.addName("SomeNiceName")
  item.addValue(10)
  item.addDistinctValue(20.DistinctValue)
  item.addIsDead(true)

  # Components can be removed as well
  item.removeComponent(IsDead)
  # item.removeIsDead()
  (ecs, entity1).removeIsDead()

  # To access an entity's component, you can call `item.<componentName>`
  item.position.x += 20.0
  # If you try to access a component that hasn't been adde to the entity,
  # an AssertionDefect will be thrown.
  # Since all entities that enters a system has all the components by definition,
  # this shouldn't happen unless the component has been removed within the system
  # itself and then accessed again after the removal statement.
  when false:
    item.isDead # would throw exception since it was removed above^

  echo " == Components of entity2 == "
  echo item.position
  echo item.velocity
  echo item.sprite
  echo item.customFlag
  echo "..."

  echo "\n == ID of entity1 == "
  # The Entity type is simply an integer ID
  echo entity1
  echo typeof(entity1)

  # You can inspect entities using `ecs.inspect` which will
  # return a useful string for debugging when not in release
  # mode. The string will contain the label from when the entity
  # was instantiated. In release mode, just the ID will be return.
  # labels are not saved in release mode in order to save memory
  when not defined(release):
    echo "\n == ecs.inspect(entity1) == "
    echo ecs.inspect(entity1)

  # You call your system groups using `ecs.run<GroupName>()`
  echo "\n == Running \"systems\" group 10 times == "
  for i in 0 ..< 10: # You would probably use an infinite game loop instead of a for loop..
    ecs.runSystems()

  echo "\n == Running \"rendering\" group once == "
  # Note that we have to pass `game: var Game` here!
  # Check `renderSpriteSystem` above for details on why ^

  # `game` currently only has a value, but a more useful
  # usage would be to perhaps have a reference to your
  # window and/or renderer in the case of a game. That way
  # you can still write your rendering logic within a System
  doAssert game.value == 0
  ecs.runRendering(game)
  doAssert game.value == 1

  # You can also query entities using the iterator `queryAll`.
  # The following will yield all entities with a `Position` component.
  # ckPosition (ck<ComponentName>) is a member of a generated enum `ComponentKind`.
  echo "\n == Querying {ckPosition} entities == "
  for entity in ecs.queryAll({ckPosition}):
    echo ecs.inspect(entity)

  (ecs, entity1).removePosition()
  echo "\n == Querying {ckPosition} entities after removing Position from entity1 == "
  for entity in ecs.queryAll({ckPosition}):
    echo ecs.inspect(entity)

  # To get all entities, use the special ComponentKind called `ckExists`
  # `ckExists` is added to all entities that have been instantiated
  echo "\n == Querying {ckExists} entities == "
  for entity in ecs.queryAll({ckExists}): # This is also the default when calling `ecs.queryAll()` or `ecs.queryAll({})`
    echo ecs.inspect(entity)

  # The 'query' above is actually known as the entity's `Signature`
  # which can be accessed using `entity.getSignature(ecs)` (or `item.getSignature`)
  echo (ecs, entity1).getSignature() # {ckExists, ckPosition, ckVelocity, ckSprite, ...}

  # So you can query all entities like another one as such shown below.
  # Note that this will, of course, include entity1.
  echo "\n == Querying entities that have all of entity1's components or more == "
  for entity in ecs.queryAll((ecs, entity1).getSignature()):
    echo ecs.inspect(entity)

  # That's all for this example! Generate documentation using `nimble docgen` from the root
  # of easyess to get a bit more tecchnical documentation for each and every function and
  # template!

  # Try to compile this using `-d:danger` or `-d:release` and notice the difference!
