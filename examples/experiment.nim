import easyess

import macros, strutils, strformat, tables
export macros, tables

type
  BaseIDType* = distinct uint16 ## \
  ## The integer kind used for IDs. Currently `uint16` is used which
  ## allows for 65 535 entities alive simultaniously. If more are
  ## required (or less), change this type manually within your project.

  Entity* = distinct BaseIDType ## \
  ## Entities are simply distinct IDs without any behaviour
  ## or data attached. Data is added using Components and
  ## behaviour is added using Systems. See `comp` and `sys` macro
  ## for more details on those.

  ECSConfig* = object
    ## A configureation that can be specified statically to
    ## `createECS <easyess.html#createECS.m,static[ECSConfig]>`_ to determine the settings of the `ECS <easyess.html#ECS>`_
    maxEntities*: int

  ComponentDefinition = tuple
    ## Internal
    name: NimNode
    body: NimNode

  SystemDefinition = tuple
    ## Internal
    name: NimNode
    signature: NimNode
    components: NimNode
    entireSystem: NimNode
    dataType: NimNode
    itemName: NimNode


template declareOps(typ: typedesc) =
  proc `inc`*(x: var typ) {.borrow.}
  proc `dec`*(x: var typ) {.borrow.}

  proc `+` *(x, y: typ): typ {.borrow.}
  proc `-` *(x, y: typ): typ {.borrow.}

  proc `<`*(x, y: typ): bool {.borrow.}
  proc `<=`*(x, y: typ): bool {.borrow.}
  proc `==`*(x, y: typ): bool {.borrow.}

declareOps(BaseIDType)
declareOps(Entity)

const ecsDebugMacros = false or defined(ecsDebugMacros)

func firstLetterLower(word: string): string =
  word[0..0].toLower() & word[1..^1]

func firstLetterUpper(word: string): string =
  word[0..0].toUpper() & word[1..^1]

func toComponentKindName(word: string): string =
  "ck" & firstLetterUpper(word)

func toContainerName(word: string): string =
  firstLetterLower(word) & "Container"

type
  Position = object
    x: float
    y: float

  Velocity = object
    dx: float
    dy: float


template idx*(entity: Entity): int =
  ## Get the ID of `entity`
  entity.int

func `$`*(entity: Entity): string =
  ## Get a string representation of `entity`. Note that this representation cannot
    ## include the `entity`'s label since it is stored within the `ECS <easyess.html#ECS>`_.
    ## See `inspect <easyess.html#inspect,ECS,Entity>`_ for a string representation
    ## with the label included.
  result = $entity.idx

type
  ComponentKind* = enum
    ckExists, ckPosition, ckVelocity
  Signature* = set[ComponentKind] ## \
                                  ## The bitset that identifies what Components each entity has.
                                  ## For each entity, a Signature is stored within the
                                  ## `ECS.signatureContainer` array.
type
  ECS* = ref object
    nextID*: Entity
    highestID*: Entity
    when not defined(release):
      usedLabels: Table[string, bool]
      ecsInspectLabelContainer: array[100, string]

    signatureContainer*: array[100, Signature]
    positionContainer*: array[100, Position]
    velocityContainer*: array[100, Velocity]

type
  Item* = tuple[ecs: ECS, entity: Entity] ## \
                                          ## An `Item` is a capsule of the `ECS <easyess.html#ECS>`_ and an `Entity <easyess.html#Entity>`_. Most functions and
                                          ## templates that follow the pattern `ecs.<function>(entity, <...>)` can
                                          ## also be called using `(ecs, entity).<function>(<...>)`. This becomes
                                          ## especially useful within systems since an item of this type is provided.
                                          ##
                                          ## Components can therefore be accessed using `item.<componentName>`
                                          ## within systems. See `sys` macro for more details.
func newECS*(): ECS =
  ## Create an `ECS <easyess.html#ECS>`_ instance. The `ECS <easyess.html#ECS>`_ contains arrays of containers
    ## for every component on every entity. It also contains every `Signature`
    ## of every entity. The `ECS <easyess.html#ECS>`_ is used to create entities, register them
    ## as well as to modify their components.
  new(result)

func getSignature*(ecs: ECS; entity: Entity): Signature =
  ## Get the set of `ComponentKind <easyess.html#ComponentKind>`_ that represents `entity`
  result = ecs.signatureContainer[entity.idx]

func getSignature*(item: (ECS, Entity)): Signature =
  result = item[0].signatureContainer[item[1].idx]

func inspect*(ecs: ECS; entity: Entity): string =
  ## Get a string representation of `entity` including its debug-label.
    ## When `release` is defined, only the entity id is returned as a string.
  when not defined(release):
    result = ecs.ecsInspectLabelContainer[entity.idx] & "["
    result &= $entity.idx
    result &= "]"
  else:
    result = $entity

func inspect*(item: Item): string =
  ## same as `ecs.inspect(entity)`
  item[0].inspect(item[1])

func `$`*(item: Item): string =
  ## Same as `item.inspect()` and in turn `ecs.inspect(entity)`
  result = item[0].inspect(item[1])

func newEntity*(ecs: ECS; label: string = "Entity"): Entity =
  ## Create an empty entity. This function creates an entity with a
    ## unique ID without any components added. Components can be added
    ## either using `addComponent()` (recommmended) or manually using
    ## `ecs.<componentName>Container[entity.idx] = <Component>`. If components
    ## are added manually, don't forget to manually manage the entity's signature
    ## by manipulating `ecs.signatureContainer[entity.idx]` through including
    ## and excluding `ck<ComponentName>`
  when not defined(release):
    var
      n = 0
      actualName = label
    while actualName in ecs.usedLabels:
      inc n
      actualName = label & " (" & $n & ")"
    ecs.usedLabels[actualName] = true
  var newId = -1
  for id in ecs.nextID.idx .. high(ecs.signatureContainer):
    if ckExists notin ecs.signatureContainer[id]:
      newId = id
      break
  debugEcho newId
  if newId < 0:
    raise newException(IndexDefect, "Tried to instantiate Entity \'" &
        label &
        "\' but ran out of ID:s. You can increase the number of supported entities by supplying \'ECSConfig(maxEntities: <int>)\' to \'createECS()\'")
  result = newId.Entity
  inc ecs.nextID
  ecs.highestID = max(result, ecs.highestID)
  ecs.signatureContainer[newId].incl(ckExists)
  when not defined(release):
    ecs.ecsInspectLabelContainer[newId] = actualName

func removeEntity*(ecs: ECS; entity: Entity) =
  doAssert ckExists in ecs.signatureContainer[entity.idx],
           "Tried to remove Entity that doesn\'t exist."
  ecs.signatureContainer[entity.idx] = {}
  ecs.nextID = min(ecs.nextID, entity)
  if ecs.highestID == entity:
    var i = ecs.highestID.idx
    while ckExists notin ecs.signatureContainer[i]:
      dec i
    ecs.highestID = Entity(i)

func setSignature*(ecs: ECS; entity: Entity; signature: Signature = {}) =
  ## Set the signature of an entity to the specified set of `ComponentKind`.
    ## It is not adviced to use this function since other functions keep track
    ## of and manage the entity's signature. For example, `addComponent()` ensures
    ## that the added component is included in the signature and vice versa for
    ## `removeComponent()`.
  ecs.signatureContainer[entity.idx] = signature
  ecs.signatureContainer[entity.idx].incl(ckExists)

func setSignature*(item: (ECS, Entity); signature: Signature): Signature =
  let (ecs, entity) = item
  ecs.setSignature(entity, signature)

func extractComponents*(root: NimNode): seq[NimNode] {.compileTime.} =
  ## Internal
  root.expectKind(nnkStmtList)
  for c1 in root:
    case c1.kind
    of nnkTupleConstr:
      for c2 in c1:
        result.add(c2)
    of nnkPar:
      for c2 in c1:
        return @[c2]
    else:
      error("Could not extract component of kind \'" & $root.kind &
          "\'", root)

func extractComponentName*(component: NimNode): string {.compileTime.} =
  ## Internal
  case component.kind
  of nnkObjConstr:
    for c1 in component:
      case c1.kind
      of nnkIdent:
        return $c1
      of nnkBracket:
        for c2 in c1:
          return $c2
      else:
        discard
  of nnkCommand:
    for c1 in component:
      c1.expectKind(nnkBracket)
      for c2 in c1:
        return $c2
  else:
    discard

macro defineSignature*(components: untyped) =
  ## Internal
  let curly = newNimNode(nnkCurly)
  curly.add(ident(toComponentKindName("exists")))
  for component in extractComponents(components):
    let componentName = extractComponentName(component)
    curly.add(ident(toComponentKindName(componentName)))
  return nnkStmtList.newTree(nnkLetSection.newTree(nnkIdentDefs.newTree(
      ident("signature"), ident("Signature"), curly)))

func toProperComponent*(component: NimNode): NimNode {.compileTime.} =
  ## Internal
  case component.kind
  of nnkObjConstr:
    for c1 in component:
      if c1.kind == nnkIdent:
        return component
      break
    result = newNimNode(nnkTupleConstr)
    var
      isFirst = true
      componentIdent: NimNode
    for c1 in component:
      if isFirst:
        isFirst = false
        c1.expectKind(nnkBracket)
        for c2 in c1:
          componentIdent = c2
          break
        continue
      result.add(c1)
    result = nnkDotExpr.newTree(result, componentIdent)
    return result
  of nnkCommand:
    var componentIdent: NimNode
    for c1 in component:
      if c1.kind == nnkBracket:
        for c2 in c1:
          componentIdent = c2
          break
        continue
      return nnkDotExpr.newTree(c1, componentIdent)
  else:
    error("Component " & repr(component) &
        " can currently not be interpreted", component)

template position*(item: (ECS, Entity)): Position =
  ## Expands to `ecs.positionContainer[entity.idx]`
  doAssert ckPosition in item.getSignature(), "Entity \'" & $item &
      "\' Does not have a component of type \'" &
      "Position" &
      "\'"
  item[0].positionContainer[item[1].idx]

func addComponent*(item: (ECS, Entity); position: Position) =
  ## Add `Position <easyess.html#Position>`_ to `entity` and update its signature by including `ckPosition <easyess.html#ComponentKind>`_
  doAssert ckPosition notin item.getSignature(), "Entity \'" & $item &
      "\' Already has a component of type \'" &
      "Position" &
      "\'"
  let (ecs, entity) = item
  ecs.positionContainer[entity.idx] = position
  ecs.signatureContainer[entity.idx].incl(ckPosition)

func addPosition*(item: (ECS, Entity); position: Position) =
  ## Add `Position <easyess.html#Position>`_ to `entity` and update its signature by including `ckPosition <easyess.html#ComponentKind>`_
  doAssert ckPosition notin item.getSignature(), "Entity \'" & $item &
      "\' Already has a component of type \'" &
      "Position" &
      "\'"
  let (ecs, entity) = item
  ecs.positionContainer[entity.idx] = position
  ecs.signatureContainer[entity.idx].incl(ckPosition)

func removeComponent*[T: Position](item: (ECS, Entity);
                                   t: typedesc[T] = Position) =
  ## Remove `Position <easyess.html#Position>`_ from `entity` and update its signature by excluding `ckPosition <easyess.html#ComponentKind>`_
  doAssert ckPosition in item.getSignature(), "Entity \'" & $item &
      "\' Does not have a component of type \'" &
      "Position" &
      "\'"
  item[0].signatureContainer[item[1].idx].excl(ckPosition)

func removePosition*(item: (ECS, Entity)) =
  ## Remove `Position <easyess.html#Position>`_ from `entity` and update its signature by excluding `ckPosition <easyess.html#ComponentKind>`_
  doAssert ckPosition in item.getSignature(), "Entity \'" & $item &
      "\' Does not have a component of type \'" &
      "Position" &
      "\'"
  item[0].signatureContainer[item[1].idx].excl(ckPosition)

template velocity*(item: (ECS, Entity)): Velocity =
  ## Expands to `ecs.velocityContainer[entity.idx]`
  doAssert ckVelocity in item.getSignature(), "Entity \'" & $item &
      "\' Does not have a component of type \'" &
      "Velocity" &
      "\'"
  item[0].velocityContainer[item[1].idx]

func addComponent*(item: (ECS, Entity); velocity: Velocity) =
  ## Add `Velocity <easyess.html#Velocity>`_ to `entity` and update its signature by including `ckVelocity <easyess.html#ComponentKind>`_
  doAssert ckVelocity notin item.getSignature(), "Entity \'" & $item &
      "\' Already has a component of type \'" &
      "Velocity" &
      "\'"
  let (ecs, entity) = item
  ecs.velocityContainer[entity.idx] = velocity
  ecs.signatureContainer[entity.idx].incl(ckVelocity)

func addVelocity*(item: (ECS, Entity); velocity: Velocity) =
  ## Add `Velocity <easyess.html#Velocity>`_ to `entity` and update its signature by including `ckVelocity <easyess.html#ComponentKind>`_
  doAssert ckVelocity notin item.getSignature(), "Entity \'" & $item &
      "\' Already has a component of type \'" &
      "Velocity" &
      "\'"
  let (ecs, entity) = item
  ecs.velocityContainer[entity.idx] = velocity
  ecs.signatureContainer[entity.idx].incl(ckVelocity)

func removeComponent*[T: Velocity](item: (ECS, Entity);
                                   t: typedesc[T] = Velocity) =
  ## Remove `Velocity <easyess.html#Velocity>`_ from `entity` and update its signature by excluding `ckVelocity <easyess.html#ComponentKind>`_
  doAssert ckVelocity in item.getSignature(), "Entity \'" & $item &
      "\' Does not have a component of type \'" &
      "Velocity" &
      "\'"
  item[0].signatureContainer[item[1].idx].excl(ckVelocity)

func removeVelocity*(item: (ECS, Entity)) =
  ## Remove `Velocity <easyess.html#Velocity>`_ from `entity` and update its signature by excluding `ckVelocity <easyess.html#ComponentKind>`_
  doAssert ckVelocity in item.getSignature(), "Entity \'" & $item &
      "\' Does not have a component of type \'" &
      "Velocity" &
      "\'"
  item[0].signatureContainer[item[1].idx].excl(ckVelocity)

macro defineComponentAssignments*(ecs: ECS; entity: untyped;
                                  components: untyped) =
  ## Internal.
  result = newStmtList()
  for component in extractComponents(components):
    let
      componentName = extractComponentName(component)
      containerIdent = ident(firstLetterLower(componentName) &
          "Container")
    let a = nnkStmtList.newTree(nnkAsgn.newTree(nnkBracketExpr.newTree(
        nnkDotExpr.newTree(ecs, containerIdent),
        nnkDotExpr.newTree(entity, ident("idx"))),
        toProperComponent(component)))
    result.add a

template registerEntity*(ecs: ECS; label: string;
                         components: untyped): Entity =
  ## Create an entity with a label and components. This template
    ## makes it very easy to instantiate an entity with predefined
    ## components. See `newEntity` to create an entity without components
  var entity: Entity
  block:
    defineSignature(components)
    entity = ecs.newEntity(label)
    ecs.setSignature(entity, signature)
    ecs.defineComponentAssignments(entity, components)
  entity

iterator queryAll*(ecs: ECS; query: Signature = {ckExists}): Entity =
  ## Query and iterate over entities matching the query specified. The
    ## query must be a set of `ComponentKind` and all entities that have
    ## a signature that a superset of the query will be returned.
    ##
    ## **Example**
    ##
    ## .. code-block:: nim
    ##    # assuming `Position` and `Velocity` components have been defined
    ##    # and `createECS()` has been called..
    ##
    ##    for entity in ecs.queryAll({ckPosition, ckVelocity}):
    ##       echo ecs.inspect(entity)
  var actualQuery = query
  actualQuery.incl(ckExists)
  for id in 0 .. ecs.highestID.idx:
    if ecs.signatureContainer[id] >= actualQuery:
      yield id.Entity

func moveSystem*(item: Item) =
  template position(): Position =
    ## Expands to `ecs.positionContainer[entity.idx]`
    item.ecs.positionContainer[item.entity.idx]

  template velocity(): Velocity =
    ## Expands to `ecs.velocityContainer[entity.idx]`
    item.ecs.velocityContainer[item.entity.idx]

  let
    (ecs, entity) = item
    oldPosition = position
  position.y += velocity.dy
  item.position.x += item.velocity.dx
  when not defined(release):
    debugEcho "Moved " & ecs.inspect(entity) & " from ", oldPosition, " to ",
              position

proc runSystems*(ecs: ECS) =
  for item in ecs.queryAll({ckPosition, ckVelocity}):
    let item: Item = (ecs, item)
    moveSystem(item)

