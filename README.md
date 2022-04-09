<h1 align="center">Easyess</h1>
<p align="center">"An easy to use ECS... <i>EasyEss</i>?" - Erik</p>
<p align="center">
  <img src="https://github.com/EriKWDev/easyess/actions/workflows/unittests.yaml/badge.svg">
  <img src="https://github.com/EriKWDev/easyess/actions/workflows/unittests_devel.yaml/badge.svg">
</p>

## About
First and foremost, if you really want an ECS with great performance
and lots of thought put into it, this might not be for you. I instead point
you to the amazing [polymorph](https://github.com/rlipsc/polymorph) which has
has great documentation and great performance from own experience.

Easyess started as a learning project for myself after having used polymorph
and being amazed by its performance. I had never really gotten into writing
 `macros` and `templates` in Nim before this, and after having had that
experience I began investigaring them more.

## Features
- [X] Components of any kind (int, enum, object, tuple, case object ..)
- [X] Systems with ability to name components whatever `(vel: Velocity, pos: Position)`
- [X] Good enough performance for simple games IMO
- [X] Ability to group systems and run groups
- [X] Entity IDs are assigned using a Slottable datastructure thanks to @planetis-im
  - [X] All systems can be run individually as well

## Example
Here is what could be called a tutorial example of `easyess` utilizing as much of it as possible. Checkout the `examples/` directory and the documentation further down in this README for more examples and API information. This example is from `examples/minimal.nim`

```nim
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

  ecs.newEntity() do (item: Item):
    item.addPosition(Vector2(x: 0.0, y: 0.0))
    item.addComponent(velocity = Velocity(x: 10.0, y: 10.0))

  for i in 1..5:
    echo "\nRound ", i, ":"
    ecs.runLogicSystems(drag = 0.9)

```

## Defining Components
Components are not 'wrapped' in anything internally, so components can be of any valid nim type without generics.
Case objects work.

```nim
type
  Position {.comp.} = object
    x: float
    y: float

  Vector2 = tuple[x, y: float] # Won't be a component

  Velocity {.comp.} = Vector2

  EnumComp {.comp.} = enum
    ecOne, ecTwo

  IntComp {.comp.} = uint8

  ObjectKind = enum # Won't be a component
    objectKind1, objectKind2

  CaseObjectComp {.comp.} = object
    name: string

    case kind: ObjectKind
    of objectKind1:
      data1: int
    of objectKind2:
      data2: bool
```

## Defining Systems
There are a couple of different ways to create systems. You primarily create a proc/func whose first
parameter has to be of type `ECS` (named whatever you want) and with the `{.sys: <components>.}` pragma.
The pragma takes as an argument a component definition which is simply a tuple of Components and their names as such:

```nim
# ... assuming `Position` and `Velocity` components have ben created

proc positionSystem(ecs: ECS): {.sys: (pos: Position, Velocity).} =
  for entity in ecs.queryAll(signature):
    entity.pos += entity.velocity
```

A sytem group can also be specified using the `{.group: "groupName".}` pragma as such:
```nim
proc positionSystem(ecs: ECS): {.sys: (pos: Position, Velocity)
                                 group: "logicSystems".} =
  # ... implementation
```

## Creating the ECS
Once all systems and components have been defined, you must "commit" to them using `makeECS()`

```nim
# ... comopnent and system definitions

makeECS()

# After this point we can use things like newEntity(), addPosition() and much more!
```

## Creating Entities and Adding Components to Them
Once components and systems have been definied and the ECS commited using `makeECS()`, we can create an ECS "world" and add entities to it.

```nim
# ... comopnent and system definitions

makeECS()

var
  ecs = newECS()
  entity = ecs.newEntity()

(esc, entity).addPosition()
# or ecs.addPosition(entity)
```

A tuple of and ECS and an Entity is called an `Item` in `easyess` and is what one will be working with most often.
```nim
makeECS()

var
  ecs = newECS()
  item = ecs.newItem()

item.addPosition()
# or item.addComponent(position=Position(x: 0.0, y: 0.0))
# or item.position = Position(x: 0.0, y: 0.0)
```

Another way to create entities is using `do` notation like such:

```nim
makeECS()

var ecs = newECS()

discard ecs.newEntity() do (item: Item):
  item.position = Position(x: 0.0, y: 0.0)

discard ecs.newItem() do (item: Item):
  item.addPosition(Position(x: 0.0, y: 0.0))
```

## Accessing Components
`easyess` supports many different valid ways to access the components of entities:

```nim
type Position {.comp.} = object

var
  ecs = newECS()
  item = ecs.newItem() do (item: Item): item.addPosition()
  entity = item.entity


(ecs, entity).position
item.position
ecs.positionsContainer[entity.idx]

when false: # The follownig only works inside systems
  entity.position

when false: # The following only works inside systems marked with {.all.}
  position
```

```nim
# All of those expand at compile time to the following through templates:
assert ckPosition in ecs.signatures[entity]
ecs.positionsContainer[entity.idx]
```

## Running Systems and System Groups
Systems can be run individually using their normal proc-name or by calling `run<GroupName>` if it has been added to a group using the `{.group: "<groupName>".}` pragma.
```nim
var ecs = newECS()

# ... assuming `positionSystem` has been defined with or without a group
ecs.positionSystem()

# ... if `positionSystem` is inside the `logicSystems` group
ecs.runLogicSystems()
```

## Removing Entities and Components
To remove a component, you simply call `remove<ComponentName>()` on an item. This will remove the component from the netity's signature and the entity will therefore no longer be said to have it. Note that the component is still stored inside the containers at it's location untill a new component is created and inserted into the contain at the previously removed container's location which can only occur once the original entity also ahs been remove.

To remove entities, you cann call `ecs.removeEntity(entity)` or `item.removeItem()`. 

**WARNING**: Note that removing entities while iterating over them (as you usually do within systems) will cause an error since you are modifying the set of entities over which you are iterating. To facilitate this, you can instead call `ecs.scheduleRemove(entity)` (or `item.scheduleRemove()`) and later call `ecs.removeScheduled()` to clean up all entities that needed to be removed. For example:

```nim
for item in ecs.queryAllItems({ckPosition, ckVelocity}):
  if item.velocity.x < 0.5:
    item.scheduleRemove()

ecs.removeScheduled()
```

## Notes on Compile Options and Memory
`easyess` supports some compile-flags to change how components are stored. By default, heap arrays are used and allocated when you call `newECS()`, but depending on the number of and size of your components, as well as the number of entities you plan on creating, this might not be a very feasable solution.

The max number of entities for the heap array approach is dependant on the entity id type. By default, this type is `uint32` to support a bunch of entities. This does mean, however, that wether you intend to have that many entities or not, an array of that size will still have to be allocated for every component you have defined. This can cause problems if any single component is much larger than others since that array will be huge.

If you know you won't need that many entities, you can compile using `-d:ecsSmallSlots` to instead use `uint16` as the type. This might still cause problems if your components are large enough.

To solve for that, you can compile with `-d:ecsSecTables` to swap out the component storage to instead use packed sets which will dynamically grow as entities are created and more components are required. This comes at the cost of some performance and in my limited testing around a x0.6 performance decrease in looping over large amounts of entities, but it allows for larger components to be dynamically created without having to allocate all that space at startup.

## TODO
- [ ] Ability to pause and unpause systems
- [ ] Ability to clear ecs worlds easily
- [ ] Host documentation (available locally with `nimble docgen`!)
- [ ] Publish sample game using `easyess`

# Legal
## Easyess license
`easyess` is released under the MIT license.

## Goodluck project's License

`src/easyess/slottables.nim`, `src/easyess/sectables.nim` and `src/easyess/heaparrays.nim` are taken from the [nim goodluck project](https://github.com/planetis-m/goodluck) and are used with permission under the MIT license. They have been modified slightly to fit this project. Here is the MIT license from the Goodluck project as of April 5:th 2022

```
MIT License

Copyright (c) 2019-2020 Contributors to the Goodluck project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```