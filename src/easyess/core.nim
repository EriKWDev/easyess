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

const ecsDebugMacros = false or defined(ecsDebugMacros)

func firstLetterLower(word: string): string =
  word[0..0].toLower() & word[1..^1]

func firstLetterUpper(word: string): string =
  word[0..0].toUpper() & word[1..^1]

func toComponentKindName(word: string): string =
  "ck" & firstLetterUpper(word)

func toContainerName(word: string): string =
  firstLetterLower(word) & "Container"

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

var
  systemDefinitions {.compileTime.}: Table[string, seq[SystemDefinition]]
  componentDefinitions {.compileTime.}: seq[ComponentDefinition]
  numberOfComponents {.compileTime.} = 0

  entityName {.compileTime.} = ident("entity")
  itemType {.compileTime.} = ident("Item")
  ecsType {.compileTime.} = ident("ECS")
  ecsName {.compileTime.} = ident("ecs")

macro comp*(body: untyped) =
  ## Define one or more components. Components can be of any type, but remember
  ## that the type's mutability will be reflected in the way the component
  ## can be accessed and manipulated within systems.
  ##
  ## **Example**
  ##
  ## .. code-block:: nim
  ##
  ##    import esasyess
  ##
  ##    comp:
  ##      type
  ##        ExampleComponent* = object ## \
  ##          ## Note that in order to export you Components
  ##          ## you, as usual, have to explicitly mark the
  ##          ## type with `*`
  ##          data: int
  ##
  ##        TupleComponent* = tuple
  ##          data: string
  ##          data2: int
  ##
  ##        EnumComponent* = enum
  ##          ecFlagOne
  ##          ecFlagTwo
  ##
  ##        Health* = distinct int
  ##
  ##        InternalUnexportedFlag = distinct bool

  for typeSectionChild in body:
    for typeDefChild in typeSectionChild:
      typeDefChild.expectKind(nnkTypeDef)

      block typeDefLoop:
        for postfixOrIdent in typeDefChild:
          case postfixOrIdent.kind
          of nnkPostfix:
            for identifier in postfixOrIdent:
              if identifier.eqIdent("*"):
                continue

              let componentDefinition: ComponentDefinition = (
                name: identifier,
                body: typeDefChild
              )
              componentDefinitions.add(componentDefinition)
              inc numberOfComponents

              break typeDefLoop

          of nnkIdent:
            let componentDefinition: ComponentDefinition = (
              name: postfixOrIdent,
              body: typeDefChild
            )
            componentDefinitions.add(componentDefinition)
            inc numberOfComponents

            break typeDefLoop

          else:
            error(&"'{postfixOrIdent.kind}' has to be 'Identifier' or 'Postfix NimNodeKind' ", postfixOrIdent)

  result = body
  when ecsDebugMacros: echo repr(result)

macro sys*(components: openArray[untyped];
           group: static[string];
           system: untyped) =
  ## Define a system. Systems are defined by what components they wish to work on.
  ## Components are specified using an openArray of their typedescs, i.e.:
  ## `[<ComponentOne>, <ComponentTwo>]`. The group is a string to which this system
  ## belongs to. Once `createECS <easyess.html#createECS.m,static[ECSConfig]>`_ has been called, a run procedure is generated
  ## for every system group. These groups can then be called using `ecs.run<SystemGroup>()`
  ##
  ## Systems are called using an `item`. The item is a `tuple[ecs: ECS, entity: Entity]`. Inside
  ## each system, templates are generated for accessing the specified components. If a component's
  ## name was `Position`, a template called `template position(): Position` will be generated
  ## inside the system's scope.
  ##
  ## **Example**
  ##
  ## .. code-block:: nim
  ##
  ##    import easyess
  ##    comp:
  ##      type
  ##        Component = object
  ##          data: int
  ##
  ##    sys [Component], "mySystemGroup":
  ##      proc componentSysem(item: Item) =
  ##        let (ecs, entity) = item
  ##        inc component.data
  ##
  ##        when not defined(release):
  ##          debugEcho ecs.inspect(entity) & $component
  ##
  ##    createECS()
  ##    let
  ##      ecs = newEcs()
  ##      entity = ecs.createEntity("Entity"): (Component(data: 42))
  ##    ecs.runMySystemGroup()


  var
    itemName: NimNode = newNilLit()
    dataName: NimNode = newNilLit()
    dataType: NimNode = newNilLit()

    systemName: NimNode
    systemBody: NimNode

  let
    systemsignature = newNimNode(nnkCurly)
    beforeSystem = newNimNode(nnkStmtList)
    tupleDef = newNimNode(nnkTupleTy)
    containerTemplates = newNimNode(nnkStmtList)

  var isFunc = true

  block doneParsing:
    for c1 in system:
      if c1.kind in {nnkProcDef, nnkFuncDef}:
        isFunc = c1.kind == nnkFuncDef
        for c2 in c1:
          case c2.kind
          of nnkIdent:
            systemName = c2

          of nnkFormalParams:
            for c3 in c2:
              if c3.kind == nnkIdentDefs:
                for i, c4 in c3:
                  if i == 0 and itemName.kind == nnkNilLit:
                    itemName = c4
                    break

                  elif i == 0 and dataName.kind == nnkNilLit:
                    dataName = c4

                  elif i == 1 and dataType.kind == nnkNilLit:
                    dataType = c4
                    break

          of nnkStmtList:
            systemBody = c2
            break doneParsing

          else: discard
      else:
        beforeSystem.add(c1)

  for component in components:
    systemsignature.add(ident(toComponentKindName($component)))

    let
      componentLower = ident(firstLetterLower($component))
      cn = toContainerName($component)
      containerName = ident(cn)
      componentIdent = ident($component)
      templateComment = newCommentStmtNode(&"Expands to `ecs.{cn}[entity.idx]`")

    containerTemplates.add quote do:
      template `componentLower`(): `componentIdent` =
        `templateComment`
        `itemName`.`ecsName`.`containerName`[`itemName`.`entityName`.idx]

    let identDefs = newNimNode(nnkIdentDefs).add(
      componentLower,
      componentIdent,
      newNimNode(nnkEmpty)
    )
    tupleDef.add(identDefs)

  let key = $group
  if key notin systemDefinitions:
    systemDefinitions[key] = @[]

  let entireSystem = newNimNode(nnkStmtList)

  entireSystem.add quote do:
    `beforeSystem`

  if isFunc:
    if dataName.kind == nnkNilLit:
      entireSystem.add quote do:
        func `systemName`*(`itemName`: `itemType`) =
          `containerTemplates`
          `systemBody`
    else:
      entireSystem.add quote do:
        func `systemName`*(`itemName`: `itemType`; `dataName`: `dataType`) =
          `containerTemplates`
          `systemBody`
  else:
    if dataName.kind == nnkNilLit:
      entireSystem.add quote do:
        proc `systemName`*(`itemName`: `itemType`) =
          `containerTemplates`
          `systemBody`
    else:
      entireSystem.add quote do:
        proc `systemName`*(`itemName`: `itemType`; `dataName`: `dataType`) =
          `containerTemplates`
          `systemBody`

  let systemDefinition: SystemDefinition = (
    name: systemName,
    signature: systemsignature,
    components: components,
    entireSystem: entireSystem,
    dataType: dataType,
    itemName: itemName
  )
  systemDefinitions[key].add(systemDefinition)

  # when ecsDebugMacros: echo repr(entireSystem)

macro createECS*(config: static[ECSConfig] = ECSConfig(maxEntities: 100)) =
  ## Generate all procedures, functions, templates, types and macros for
  ## all components and systems defined until this point in the code.
  ##
  ## After `createECS <easyess.html#createECS.m,static[ECSConfig]>`_ has been called, it should **NOT** be called again.
  ##
  ## You can statically specify a `ECSConfig` with `maxEntities: int` that
  ## will determine the internal size of all arrays and will be the upper limit
  ## of the number of entities that can be alive at the same time.
  result = newNimNode(nnkStmtList)

  let
    existsComponentKind = ident(toComponentKindName("exists"))

    componentKindType = ident("ComponentKind")
    signatureType = ident("Signature")

    inspectLabelName = ident(toContainerName("ecsInspectLabel"))
    signaturesName = ident(toContainerName("signature"))
    usedLabelsName = ident("usedLabels")
    componentName = ident("component")
    highestIDName = ident("highestID")
    releaseName = ident("release")
    nextIDName = ident("nextID")
    queryName = ident("query")
    itemName = ident("item")
    kindName = ident("kind")
    idName = ident("id")

    maxEntities = config.maxEntities
    enumType = newNimNode(nnkEnumTy).add(newEmptyNode())
    setBasedOnComponent = newStmtList()
    containerDefs = newNimNode(nnkRecList)

    toStringName = nnkAccQuoted.newTree(
      newIdentNode("$")
    )

  result.add quote do:
    template idx*(`entityName`: Entity): int =
      ## Get the ID of `entity`
      `entityName`.int

    func `toStringName`*(`entityName`: Entity): string =
      ## Get a string representation of `entity`. Note that this representation cannot
      ## include the `entity`'s label since it is stored within the `ECS <easyess.html#ECS>`_.
      ## See `inspect <easyess.html#inspect,ECS,Entity>`_ for a string representation
      ## with the label included.
      result = $`entityName`.idx

  containerDefs.add nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), nextIDName),
    ident("Entity"),
    newEmptyNode())

  containerDefs.add nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), highestIDName),
    ident("Entity"),
    newEmptyNode())

  containerDefs.add nnkRecWhen.newTree(
    nnkElifBranch.newTree(
      nnkPrefix.newTree(
        ident("not"),
        nnkCall.newTree(
          ident("defined"),
          releaseName)),
      nnkRecList.newTree(
        nnkIdentDefs.newTree(
          usedLabelsName,
          nnkBracketExpr.newTree(
            ident("Table"),
            ident("string"),
            ident("bool")), newEmptyNode()),
        nnkIdentDefs.newTree(
          inspectLabelName,
          nnkBracketExpr.newTree(
            ident("array"),
            newIntLitNode(maxEntities),
            ident("string")), newEmptyNode()))))

  containerDefs.add nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), signaturesName),
    nnkBracketExpr.newTree(
      ident("array"),
      newIntLitNode(maxEntities),
      signatureType), newEmptyNode())

  enumType.add(existsComponentKind)

  for component in componentDefinitions:
    let
      componentKindName = ident(toComponentKindName($component.name))
      componentObjectName = component.name

    enumType.add(componentKindName)

    let containerName = ident(toContainerName($component.name))

    containerDefs.add(nnkIdentDefs.newTree(
      nnkPostfix.newTree(
        ident("*"),
        containerName
      ),
      nnkBracketExpr.newTree(
        ident("array"),
        newIntLitNode(maxEntities),
        componentObjectName
      ), newEmptyNode()))

    setBasedOnComponent.add quote do:
      if `componentName` of `componentObjectName`:
        `kindName` = `componentKindName`
        `ecsName`.`containerName`[`entityName`.idx] = `componentName`

  let ecsDef = nnkTypeSection.newTree(
    newNimNode(nnkTypeDef).add(
      nnkPostfix.newTree(ident("*"), ecsType),
      newEmptyNode(),
      nnkRefTy.newTree(
        nnkObjectTy.newTree(
            newEmptyNode(),
            newEmptyNode(),
            containerDefs))))

  result.add quote do:
    type
      `componentKindType`* = `enumType`

      `signatureType`* = set[`componentKindType`] ## \
      ## The bitset that identifies what Components each entity has.
      ## For each entity, a Signature is stored within the
      ## `ECS.signatureContainer` array.

    `ecsDef`

    type
      `itemType`* = tuple[`ecsName`: `ecsType`; `entityName`: Entity] ## \
      ## An `Item` is a capsule of the `ECS <easyess.html#ECS>`_ and an `Entity <easyess.html#Entity>`_. Most functions and
      ## templates that follow the pattern `ecs.<function>(entity, <...>)` can
      ## also be called using `(ecs, entity).<function>(<...>)`. This becomes
      ## especially useful within systems since an item of this type is provided.
      ## 
      ## Components can therefore be accessed using `item.<componentName>`
      ## within systems. See `sys` macro for more details.

  result.add quote do:
    func newECS*(): `ecsType` =
      ## Create an `ECS <easyess.html#ECS>`_ instance. The `ECS <easyess.html#ECS>`_ contains arrays of containers
      ## for every component on every entity. It also contains every `Signature`
      ## of every entity. The `ECS <easyess.html#ECS>`_ is used to create entities, register them
      ## as well as to modify their components.
      new(result)

  result.add quote do:
    func getSignature*(`ecsName`: `ecsType`; `entityName`: Entity): Signature =
      ## Get the set of `ComponentKind <easyess.html#ComponentKind>`_ that represents `entity`
      result = `ecsName`.`signaturesName`[`entityName`.idx]

    func getSignature*(`itemName`: (`ecsType`, Entity)): Signature =
      result = `itemName`[0].`signaturesName`[`itemName`[1].idx]

  result.add quote do:
    func inspect*(`ecsName`: `ecsType`; `entityName`: Entity): string =
      ## Get a string representation of `entity` including its debug-label.
      ## When `release` is defined, only the entity id is returned as a string.
      when not defined(release):
        result = `ecsName`.`inspectLabelName`[`entityName`.idx] & "["
        result &= $`entityName`.idx
        result &= "]"
      else:
        result = $`entityName`

    func inspect*(`itemName`: `itemType`): string =
      ## same as `ecs.inspect(entity)`
      `itemName`[0].inspect(`itemName`[1])

    func `toStringName`*(`itemName`: `itemType`): string =
      ## Same as `item.inspect()` and in turn `ecs.inspect(entity)`
      result = `itemName`[0].inspect(`itemName`[1])

  result.add quote do:
    func newEntity*(`ecsName`: `ecsType`; label: string = "Entity"): Entity =
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

        while actualName in `ecsName`.`usedLabelsName`:
          inc n
          actualName = label & " (" & $n & ")"

        `ecsName`.`usedLabelsName`[actualName] = true

      var newId = -1
      for id in `ecsName`.`nextIDName`.idx .. high(`ecsName`.`signaturesName`):
        if `existsComponentKind` notin `ecsName`.`signaturesName`[id]:
          newId = id
          break

      if newId < 0:
        raise newException(IndexDefect, "Tried to instantiate Entity '" &
            label & "' but ran out of ID:s. You can increase the number of supported entities by supplying 'ECSConfig(maxEntities: <int>)' to 'createECS()'")

      result = newId.Entity
      `ecsName`.`nextIDName` = `ecsName`.`nextIDName` + Entity(1)
      `ecsName`.`highestIDName` = max(result, `ecsName`.`highestIDName`)

      `ecsName`.`signaturesName`[newId].incl(`existsComponentKind`)

      when not defined(release):
        `ecsName`.`inspectLabelName`[newId] = actualName

  result.add quote do:
    func removeEntity*(`ecsName`: `ecsType`; `entityName`: Entity) =
      if `existsComponentKind` notin `ecsName`.`signaturesName`[`entityName`.idx]:
        {.line: instantiationInfo().}:
          raise newException(AssertionDefect, "Tried to remove Entity with ID '" & $`entityName`.idx & "' that doesn't exist.")

      `ecsName`.`signaturesName`[`entityName`.idx] = {}
      `ecsName`.`nextIDName` = min(`ecsName`.`nextIDName`, `entityName`)

      # If `entityName` is greated than highestID, something is wrong.
      # If `entityName` is less than highestID, we can deduct that
      # highestID still exists
      # so no '[..] or (`entityName` < highestIDName and ckExists notin `ecsName`.`signaturesName`[`highestIDName`.idx])'
      # is required here.
      if `ecsName`.`highestIDName` == `entityName`:
        var i = `ecsName`.`highestIDName`.idx
        while `existsComponentKind` notin `ecsName`.`signaturesName`[i]:
          if i == 0: break
          dec i
        
        `ecsName`.`highestIDName` = Entity(i)
    
    template removeEntity(`itemName`: Item) =
      removeEntity(`itemName`[0], `itemName`[1])

  result.add quote do:
    func setSignature*(`ecsName`: `ecsType`;
                       `entityName`: Entity;
                       signature: Signature = {}) =
      ## Set the signature of an entity to the specified set of `ComponentKind`.
      ## It is not adviced to use this function since other functions keep track
      ## of and manage the entity's signature. For example, `addComponent()` ensures
      ## that the added component is included in the signature and vice versa for
      ## `removeComponent()`.
      `ecsName`.`signaturesName`[`entityName`.idx] = signature
      `ecsName`.`signaturesName`[`entityName`.idx].incl(`existsComponentKind`)

    func setSignature*(`itemName`: (`ecsType`, Entity);
                       signature: Signature): Signature =
      let (ecs, entity) = `itemName`
      ecs.setSignature(entity, signature)

  result.add quote do:
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
          error("Could not extract component of kind '" & $c1.kind & "'", root)

  result.add quote do:
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

          else: discard

      of nnkCommand, nnkCall:
        for c1 in component:
          c1.expectKind(nnkBracket)
          for c2 in c1:
            return $c2

      else: discard

  result.add quote do:
    macro declareSignature*(components: untyped) =
      ## Internal
      let curly = newNimNode(nnkCurly)

      curly.add(ident(toComponentKindName("exists")))

      for component in extractComponents(components):
        let componentName = extractComponentName(component)
        curly.add(ident(toComponentKindName(componentName)))

      return nnkStmtList.newTree(
          nnkLetSection.newTree(
            nnkIdentDefs.newTree(
              ident("signature"),
              ident("Signature"),
              curly)))

  result.add quote do:
    func toProperComponent*(component: NimNode): NimNode {.compileTime.} =
      ## Internal
      case component.kind
      of nnkObjConstr:
        for c1 in component:
          if c1.kind == nnkIdent: return component
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

      of nnkCommand, nnkCall:
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

  for cd in componentDefinitions:
    let
      name = $cd.name
      lowerName = ident(firstLetterLower(name))
      addName = ident("add" & firstLetterUpper(name))
      componentType = ident(firstLetterUpper(name))
      removeName = ident("remove" & firstLetterUpper(name))
      cn = toContainerName(name)
      componentContainerName = ident(cn)
      ck = toComponentKindName(name)
      componentKind = ident(ck)

      templateComment = newCommentStmtNode(&"Expands to `ecs.{cn}[entity.idx]`")
      addComment = newCommentStmtNode(&"Add `{name} <easyess.html#{name}>`_ to `entity` and update its signature by including `{ck} <easyess.html#ComponentKind>`_")
      removeComment = newCommentStmtNode(&"Remove `{name} <easyess.html#{name}>`_ from `entity` and update its signature by excluding `{ck} <easyess.html#ComponentKind>`_")

    result.add quote do:
      template `lowerName`*(`itemName`: (`ecsType`, Entity)): `componentType` =
        `templateComment`
        if `componentKind` notin `itemName`.getSignature():
          {.line: instantiationInfo().}:
            raise newException(AssertionDefect, "Entity '" & $`itemName` & "' Does not have a component of type '" & `name` & "'")

        `itemName`[0].`componentContainerName`[`itemName`[1].idx]

    result.add quote do:
      func addComponent*(`itemName`: (`ecsType`, Entity);
                         `lowerName`: `componentType`) =
        `addComment`
        if `componentKind` in `itemName`.getSignature():
          {.line: instantiationInfo().}:
            raise newException(AssertionDefect, "Entity '" & $`itemName` & "' Already has a component of type '" & `name` & "'")

        let (`ecsName`, `entityName`) = `itemName`
        `ecsName`.`componentContainerName`[`entityName`.idx] = `lowerName`
        `ecsName`.`signaturesName`[`entityName`.idx].incl(`componentKind`)

      func `addName`*(`itemName`: (`ecsType`, Entity);
                      `lowerName`: `componentType`) =
        `addComment`
        if `componentKind` in `itemName`.getSignature():
          {.line: instantiationInfo().}:
            raise newException(AssertionDefect, "Entity '" & $`itemName` & "' Already has a component of type '" & `name` & "'")

        let (`ecsName`, `entityName`) = `itemName`
        `ecsName`.`componentContainerName`[`entityName`.idx] = `lowerName`
        `ecsName`.`signaturesName`[`entityName`.idx].incl(`componentKind`)

    result.add quote do:
      func removeComponent*[T: `componentType`](`itemName`: (`ecsType`, Entity);
                                                t: typedesc[
                                                    T] = `componentType`) =
        `removeComment`
        if `componentKind` notin `itemName`.getSignature():
          {.line: instantiationInfo().}:
            raise newException(AssertionDefect, "Entity '" & $`itemName` & "' Does not have a component of type '" & `name` & "'")

        `itemName`[0].`signaturesName`[`itemName`[1].idx].excl(`componentKind`)

      func `removeName`*(`itemName`: (`ecsType`, Entity)) =
        `removeComment`
        if `componentKind` notin `itemName`.getSignature():
          {.line: instantiationInfo().}:
            raise newException(AssertionDefect,"Entity '" & $`itemName` & "' Does not have a component of type '" & `name` & "'")

        `itemName`[0].`signaturesName`[`itemName`[1].idx].excl(`componentKind`)

  result.add quote do:
    macro defineComponentAssignments*(`ecsName`: `ecsType`;
                                      `entityName`: untyped;
                                      components: untyped) =
      ## Internal.
      result = newStmtList()

      for component in extractComponents(components):
        let
          componentName = extractComponentName(component)
          containerIdent = ident(firstLetterLower(componentName) & "Container")

        let a = nnkStmtList.newTree(
          nnkAsgn.newTree(
            nnkBracketExpr.newTree(
              nnkDotExpr.newTree(
                `ecsName`,
                containerIdent
          ), nnkDotExpr.newTree(`entityName`, ident("idx"))),
            toProperComponent(component)))

        result.add a

  result.add quote do:
    template createEntity*(`ecsName`: `ecsType`;
                             label: string;
                             components: untyped): Entity =
      ## Create an entity with a label and components. This template
      ## makes it very easy to instantiate an entity with predefined
      ## components. See `newEntity` to create an entity without components

      var entity: Entity
      block:
        declareSignature(components)

        entity = ecs.newEntity(label)
        `ecsName`.setSignature(entity, signature)
        `ecsName`.defineComponentAssignments(entity, components)

      entity

  result.add quote do:
    iterator queryAll*(`ecsName`: `ecsType`;
                       `queryName`: `signatureType` = {`existsComponentKind`}): Entity =
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
      var actualQuery = `queryName`
      actualQuery.incl(`existsComponentKind`)

      for id in 0 .. `ecsName`.`highestIDName`.idx:
        if `ecsName`.`signaturesName`[id] >= actualQuery:
          yield id.Entity

  for groupName, systems in systemDefinitions.pairs:
    let
      groupIdent = ident("run" & firstLetterUpper(groupName))
      systemsDef = newNimNode(nnkStmtList)
      dataName = ident("data")
    var groupDataType = newNilLit()

    for system in systems:
      let (name, signature, _, entireSystem, dataType, sysItemName) = system
      if groupDataType.kind == nnkNilLit:
        groupDataType = dataType
      else:
        if dataType.kind != nnkNilLit:
          doAssert $groupDataType == $dataType, ""

      result.add quote do:
        `entireSystem`

      if dataType.kind == nnkNilLit:
        systemsDef.add quote do:
          for `sysItemName` in `ecsName`.queryAll(`signature`):
            let `sysItemName`: `itemType` = (`ecsName`, `sysItemName`)
            `name`(`itemname`)
      else:
        systemsDef.add quote do:
          for `sysItemName` in `ecsName`.queryAll(`signature`):
            let `sysItemName`: `itemType` = (`ecsName`, `sysItemName`)
            `name`(`itemname`, `dataName`)

    if groupDataType.kind == nnkNilLit:
      result.add quote do:
        proc `groupIdent`*(`ecsName`: `ecsType`) =
          `systemsDef`
    else:
      result.add quote do:
        proc `groupIdent`*(`ecsName`: `ecsType`; `dataName`: `groupDataType`) =
          `systemsDef`

  when ecsDebugMacros: echo repr(result)

