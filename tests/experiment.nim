

type
  TestKind = enum
    tkTest
    tkPotato

  InputCommand = enum
    icUp
    icDown
    icLeft
    icRight

  Position = object
    x: int

  ECS = ref object
    container: array[10, TestKind]
    containerX: array[10, Position]

  Entity = int

  Item = tuple[ecs: ECS, entity: Entity]


template kind: untyped =
  item.ecs.container[item.entity]

template position(item: Item): untyped =
  item.ecs.containerX[item.entity]

func testSystem(item: Item) =
  kind = tkPotato
  inc item.position.x

var ecs: ECS
new(ecs)

testSystem((
  ecs: ecs,
  entity: 0
))

type
  MyObject = object
    x: int

  MyTuple = tuple
    x: int

var
  a: MyObject
  b: MyTuple
sdf
echo sizeof(a)
echo sizeof(b)

# echo ecs.container
# echo ecs.containerX
