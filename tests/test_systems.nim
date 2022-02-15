
import easyess, unittest


type
  Data = int

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

    Health = int

    Die = bool

    ToBeRemoved = bool

    ComponentWithVeryLongNameThatIsCumbersome = object
      value: int


const
  systemsGroup = "systems"
  renderingGroup = "rendering"


sys [Position, Velocity], systemsGroup:
  func moveSystem(item: Item) =
    let (ecs, entity) = item

    let oldPosition = position

    position.x += velocity.dx
    position.y += velocity.dy

sys [Die], systemsGroup:
  func isDeadSystem(item: Item) =
    discard

sys [CustomFlag], systemsGroup:
  func customFlagSystem(item: Item) =
    case customFlag:
      of cfTest: customFlag = cfPotato
      else: customFlag = cfTest


sys [Sprite], renderingGroup:
  var oneGlobalValue = 0

  proc renderSpriteSystem(item: Item, data: var Data) =
    inc oneGlobalValue
    inc data
    sprite = (id: 360)

sys [ToBeRemoved], systemsGroup:
  func toBeRemovedSystem(item: Item) =
    item.removeEntity()

sys [flag: CustomFlag, remove: ToBeRemoved], systemsGroup:
  func customFlagSystem2(item: Item) =
    debugEcho remove

    case flag:
      of cfTest: flag = flag
      else: flag = flag

sys [component: ComponentWithVeryLongNameThatIsCumbersome], "longNames":
  func longNameSystem(item: Item) =
    inc component.value 


createECS(ECSConfig(maxEntities: 100))

const suiteName = when defined(release): "release" else: "debug"

suite "Systems: " & suiteName:
  test "Can use custom names for components in systems":
    let
      ecs = newEcs()
      entity = ecs.createEntity("Entity"): (
        ComponentWithVeryLongNameThatIsCumbersome(value: 0),
      )
      item = (ecs, entity)
    
    check item.componentWithVeryLongNameThatIsCumbersome.value == 0
    for i in 1 .. 10:
      ecs.runLongNameSystem()
    check item.componentWithVeryLongNameThatIsCumbersome.value == 10


  test "Simple system gets executed everytime 'run<SystemGroup>()' is called":
    let
      ecs = newEcs()
      entity = ecs.createEntity("Entity"): (
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
      entity = ecs.createEntity("Entity"): (
        Position(x: 0.0, y: 0.0),
        Velocity(dx: 10.0, dy: -10.0),
        [Sprite](id: 10),
        [CustomFlag]cfTest
      )
    
    var data = 20

    check ecs.positionContainer[entity.idx].x == 0.0
    check ecs.positionContainer[entity.idx].y == 0.0
    check ecs.customFlagContainer[entity.idx] == cfTest
    check ecs.spriteContainer[entity.idx].id == 10
    check data == 20

    ecs.runSystems()
    check ecs.positionContainer[entity.idx].x == 10.0
    check ecs.positionContainer[entity.idx].y == -10.0
    check ecs.customFlagContainer[entity.idx] == cfPotato
    check ecs.spriteContainer[entity.idx].id == 10
    check data == 20

    ecs.runRendering(data)
    check ecs.spriteContainer[entity.idx].id == 360
    check ecs.positionContainer[entity.idx].x == 10.0
    check ecs.customFlagContainer[entity.idx] == cfPotato
    check ecs.positionContainer[entity.idx].y == -10.0
    check data == 21
  
  test "A System can remove an entity":
    let
      ecs = newECS()
      entity1 = ecs.createEntity("test"): ([Name]"potato",[Health](100))
    
    check (ecs, entity1).health == 100

    ecs.runSystems()
    for i in 0 .. 100:
      check (ecs, entity1).health == 100
    
    expect(AssertionDefect):
      discard (ecs, entity1).toBeRemoved 

    (ecs, entity1).addComponent(toBeRemoved=true)
    check (ecs, entity1).toBeRemoved == true

    ecs.runSystems()
    expect(AssertionDefect):
      discard (ecs, entity1).health
  
    check ckExists notin (ecs, entity1).getSignature()
  
  test "More in-depth entity removal test":
    let
      ecs = newECS()
      entity0 = ecs.createEntity("Entity"): ([Name]"potato",[Health](100))
      item0 = (ecs, entity0)
      entity1 = ecs.createEntity("Entity"): ([Name]"potato",[Health](100))
      item1 = (ecs, entity1)
      entity2 = ecs.createEntity("Entity"): ([Name]"potato",[Health](100))
      item2 = (ecs, entity2)
      entity3 = ecs.createEntity("Entity"): ([Name]"potato",[Health](100))
      item3 = (ecs, entity3)
      items = [item0, item1, item2, item3]
      items12 = [item1, item2]
      items03 = [item0, item3]

    for i in 0 .. 10:
      ecs.runSystems()
    
    for item in items:
      check item.name == "potato"
      check ckExists in item.getSignature()
    
    for item in items12:
      item.addToBeRemoved(true)

    ecs.runSystems()

    for item in items12:
      expect(AssertionDefect):
        discard item.name
      check ckExists notin item.getSignature()
    
    check ecs.nextID == 1.Entity
    check ecs.highestID == 3.Entity

    for item in items03:
      check item.name == "potato"
      check ckExists in item.getSignature()
    
    item0.addToBeRemoved(true)
    ecs.runSystems()
    expect(AssertionDefect):
      discard item0.name
    check ckExists notin item0.getSignature()

    check ecs.nextID == 0.Entity
    check ecs.highestID == 3.Entity

    item3.addToBeRemoved(true)
    ecs.runSystems()
    expect(AssertionDefect):
      discard item3.name
    check ckExists notin item3.getSignature()

    check ecs.nextID == 0.Entity
    check ecs.highestID == 0.Entity
  
  test "Can run systems individually, regardless of group":
    let
      ecs = newEcs()
      entity = ecs.createEntity("Entity"): (
        Position(x: 0.0, y: 0.0),
        Velocity(dx: 10.0, dy: -10.0),
        [Sprite](id: 10),
        [CustomFlag]cfTest
      )
      item = (ecs, entity)
    
    var data = 20
    check item.position.x == 0.0
    check item.position.y == 0.0
    check item.customFlag == cfTest
    check item.sprite.id == 10
    check data == 20
  
    for theEntity in ecs.queryAll({ckPosition, ckVelocity}):
      let theItem = (ecs, theEntity)
      moveSystem(theItem)

    check item.position.x == 10.0
    check item.position.y == -10.0
    check item.customFlag == cfTest
    check item.sprite.id == 10
    check data == 20
  
    ecs.runCustomFlagSystem()
    check item.position.x == 10.0
    check item.position.y == -10.0
    check item.customFlag == cfPotato
    check item.sprite.id == 10
    check data == 20

    ecs.runRenderSpriteSystem(data)
    check item.position.x == 10.0
    check item.position.y == -10.0
    check item.customFlag == cfPotato
    check item.sprite.id == 360
    check data == 21
