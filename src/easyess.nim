

import std/[macros, strutils, strformat, tables, macrocache, sets]
import easyess/[slottables]

export slottables

when defined(ecsSecTables):
  static: echo "[easyess] Implementation will use SecTables"
  import easyess/[sectables]
  export sectables
else:
  static: echo "[easyess] Implementation will use HeapArrays"
  import easyess/[heaparrays]
  export heaparrays

type
  EntityImpl = SlotImpl
  Entity* = Slot

proc `$`*(e: Entity): string =
  "Entity(id: " & $e.idx & ", v: " & $e.version & ")"

const maxEntities* = maxSlots

var
  # Component type idents:
  ctComponents {.compileTime.}: CacheSeq

  # System procs: proc sysName(ecs: ECS, <...>) = <...>
  ctSystemDefs {.compileTime.}: seq[NimNode]
  # { "groupName": systemNameIdent}
  ctSystemGroups {.compileTime.}: OrderedTable[string, seq[NimNode]]
  # { systemNameIdent: systemFormalParams }
  ctSystemParams {.compileTime.}: OrderedTable[string, NimNode]

let
  ecsTypeIdent {.compileTime.} = ident("ECS")
  ecsVarIdent {.compileTime.} = ident("ecs")

  entityTypeIdent {.compileTime.} = ident("Entity")
  entityVarIdent {.compileTime.} = ident("entity")

  itemTypeIdent {.compileTime.} = ident("Item")
  itemVarIdent {.compileTime.} = ident("item")
  itemInitVarIdent {.compileTime.} = ident("itemInit")

  queryVarIdent {.compileTime.} = ident("query")

  signatureTypeIdent {.compileTime.} = ident("Signature")
  signatureVarIdent {.compileTime.} = ident("signature")
  signaturesVarIdent {.compileTime.} = ident("signatures")

  toRemoveVarIdent {.compileTime.} = ident("toRemove")

  componentKindTypeIdent {.compileTime.} = ident("ComponentKind")
  componentKindVarIdent {.compileTime.} = ident("componentKind")

  maxEntitiesIdent {.compileTime.} = ident("maxEntities")

func toFirstLetterLower(name: string): string {.compileTime, inline.} = name[0..0].toLowerAscii() & name[1..^1]
func toFirstLetterUpper(name: string): string {.compileTime, inline.} = name[0..0].toUpperAscii() & name[1..^1]
func toComponentKindName(name: string): string {.compileTime, inline.} = "ck" & name.toFirstLetterUpper()
func toComponentContainerName(name: string): string {.compileTime, inline.} = name.toFirstLetterLower() & "Container"
func extractComponentAliasAndTypes(systemComponents: NimNode): seq[(NimNode, NimNode)] {.compileTime, inline.} =
  case systemComponents.kind
  of nnkEmpty:
    return

  of nnkTupleConstr, nnkPar:
    for child in systemComponents.children:
      case child.kind
      of nnkExprColonExpr:
        result.add((child[0], child[1]))

      of nnkIdent:
        result.add((ident(toFirstLetterLower($child)), child))

      else:
        raise newException(AssertionDefect, &"Cannot extract component alias from '{repr(child)}'")

  else:
    raise newException(AssertionDefect, &"Cannot extract component aliases and types from '{repr(systemComponents)}' ({systemComponents.kind})")

macro comp*(body) =
  case body.kind
  of nnkTypeDef:
    expectKind(body[0], nnkPragmaExpr)
    let componentIdent = body[0].basename

    ctComponents.incl(componentIdent)

    when defined(ecsDebugMacros):
      echo repr(body)

    return body
  else:
    error("'comp' cannot be used in this context.", body)

proc addSystemToGroup*(systemIdent: NimNode, systemGroup: string) {.compileTime.} =
  if systemGroup notin ctSystemGroups:
    ctSystemGroups[systemGroup] = @[]

  ctSystemGroups[systemGroup].add(systemIdent)


macro sys*(systemComponents, node) =
  result = newStmtList()

  case node.kind
  of nnkProcDef, nnkFuncDef:
    let
      systemProcFuncKind = node.kind
      systemIdent = node[0]
      systemRealIdent = systemIdent.baseName

      systemFormalParams = node.params
      systemPragmas = node.pragma
      systemOriginalBody = node.body

    ctSystemParams[$systemRealIdent] = systemFormalParams

    if len(systemFormalParams) == 1:
      error(&"System '{$systemRealIdent}' is required to have at least one parameter of type '{$ecsTypeIdent}', like: '{$ecsVarIdent}: {$ecsTypeIdent}'.", systemFormalParams)
    let firstFormalParams = systemFormalParams[1]

    if $firstFormalParams[1] != $ecsTypeIdent:
      error(&"A system is required to have the first parameter be of type '{$ecsTypeIdent}', like: '{$ecsVarIdent}: {$ecsTypeIdent}'. {$systemRealIdent}'s first parameter is of type '{$firstFormalParams[1]}'",
          firstFormalParams[1])

    let systemEcsVarIdent = firstFormalParams[0]
    var
      restSystemPragmas: NimNode = nnkPragma.newTree()
      doInjectQueryAll = false

    for pragmaChild in systemPragmas:
      case pragmaChild.kind
      of nnkExprColonExpr:
        if $pragmaChild[0] == "group" and len(pragmaChild) == 2:
          let theGroup: string = $pragmaChild[1]
          systemRealIdent.addSystemToGroup(theGroup)
          result.add quote do:
            discard `theGroup`

      of nnkIdent:
        case $pragmaChild
        of "all":
          doInjectQueryAll = true
        else:
          restSystemPragmas.add pragmaChild

      else:
        restSystemPragmas.add pragmaChild

    let componentAliasAndTypes = extractComponentAliasAndTypes(systemComponents)
    var
      componentTemplates = newStmtList()
      componentSignature = nnkCurly.newTree()

    for (componentAliasIdent, componentTypeIdent) in componentAliasAndTypes:
      var found = false
      for actualComponent in ctComponents:
        if $componentTypeIdent == $actualComponent:
          found = true
          break

      if not found:
        error(&"Component with name '{$componentTypeIdent}' doesn't exist.", componentTypeIdent)

      componentSignature.add ident(toComponentKindName($componentTypeIdent))
      let
        assignAliasIdent = nnkAccQuoted.newTree(
          componentAliasIdent,
          ident("=")
        )

        componentActualVarIdent = ident(toFirstLetterLower($componentTypeIdent))
        assignActualIdent = nnkAccQuoted.newTree(
          componentActualVarIdent,
          ident("=")
        )

        setActualIdent = ident(&"set{$componentTypeIdent}")
        getActualIdent = ident(&"get{$componentTypeIdent}")

        componentIdent = ident("component")

      if $componentAliasIdent != $componentActualVarIdent and not doInjectQueryAll:
        let aliasComment = newCommentStmtNode(&"=== created because alias '{componentAliasIdent}' is different than real name '{componentActualVarIdent}' ===")
        componentTemplates.add quote do:
          `aliasComment`
          when true:
            template `componentAliasIdent`(`itemVarIdent`: `itemTypeIdent`): `componentTypeIdent` {.used.} =
              `itemVarIdent`.`getActualIdent`()

            template `assignAliasIdent`(`itemVarIdent`: `itemTypeIdent`,
                                    `componentIdent`: `componentTypeIdent`) {.used.} =
              `itemVarIdent`.`setActualIdent`(`componentIdent`)

            template `componentAliasIdent`(`entityVarIdent`: `entityTypeIdent`): `componentTypeIdent` {.used.} =
              (`systemEcsVarIdent`, `entityVarIdent`).`getActualIdent`()

            proc `assignAliasIdent`(`entityVarIdent`: `entityTypeIdent`,
                                    `componentIdent`: `componentTypeIdent`) {.used.} =
              (`systemEcsVarIdent`, `entityVarIdent`).`setActualIdent`(`componentIdent`)

      componentTemplates.add quote do:
        when true:
          template `componentActualVarIdent`(`entityVarIdent`: `entityTypeIdent`): `componentTypeIdent` {.used.} =
            (`systemEcsVarIdent`, `entityVarIdent`).`getActualIdent`()

          template `assignActualIdent`(`entityVarIdent`: `entityTypeIdent`,
                                   `componentIdent`: `componentTypeIdent`) {.used.} =
            (`systemEcsVarIdent`, `entityVarIdent`).`setActualIdent`(`componentIdent`)

    var systemBody: NimNode

    if doInjectQueryAll:
      var insideQueryTemplates = newStmtList()

      for (componentAliasIdent, componentTypeIdent) in componentAliasAndTypes:
        let getComponentIdent = ident(&"get{$componentTypeIdent}")
        insideQueryTemplates.add quote do:
          template `componentAliasIdent`: `componentTypeIdent` {.used.} =
            `itemVarIdent`.`getComponentIdent`()

      systemBody = quote do:
        for `itemVarIdent` in `systemEcsVarIdent`.queryAllItems(`signatureVarIdent`):
          template `entityVarIdent`: `entityTypeIdent` {.used.} = `itemVarIdent`[1]
          `insideQueryTemplates`
          `systemOriginalBody`
    else:
      systemBody = quote do:
        `systemOriginalBody`

    let inner = quote do:
      template `signatureVarIdent`: `signatureTypeIdent` {.used.} =
        `componentSignature`

      `componentTemplates`

      `systemBody`

    let systemDefinition = nnkStmtList.newTree(
      systemProcFuncKind.newTree(
        systemIdent,
        newEmptyNode(),
        newEmptyNode(),
        systemFormalParams,
        restSystemPragmas,
        newEmptyNode(),
        inner
      )
    )

    ctSystemDefs.add systemDefinition

  else:
    error("'sys' cannot be used in this context.", node)

template sys*(body) = sys((), body)

macro makeECS*() =
  result = newStmtList()

  # === Create ComponentKind enum structure ===
  when true:
    when false:
      # This is what the generated structure looks like:
      dumpASTGen:
        type
          ComponentKind* = enum
            ckPosition, ckData1, ckFlag

    var componentTree = nnkEnumTy.newTree(newEmptyNode())
    for componentIdent in ctComponents:
      componentTree.add ident(toComponentKindName($componentIdent))

    var componentKindTypeDef = nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        nnkPostfix.newTree(
          ident("*"),
          componentKindTypeIdent
      ), newEmptyNode(), componentTree))

  # === Create ECS type structure ===
  when true:
    when false:
      # This is what the generated structure looks like:
      dumpASTGen:
        type
          ECS* = ref object
            signatures*: Slottable[Signature]

            positionContainer*: HeapArray[Position]
            data1Container*: HeapArray[Data1]
            flagContainer*: HeapArray[Flag]

    var ecsRecList = nnkRecList.newTree()

    ecsRecList.add nnkIdentDefs.newTree(
      nnkPostfix.newTree(
        ident("*"),
        signaturesVarIdent
      ),
      nnkBracketExpr.newTree(
        ident("Slottable"),
       signatureTypeIdent
      ),
      newEmptyNode()
    )

    ecsRecList.add nnkIdentDefs.newTree(
      nnkPostfix.newTree(
        ident("*"),
        toRemoveVarIdent
      ),
      nnkBracketExpr.newTree(
        ident("seq"),
        entityTypeIdent
      ),
      newEmptyNode()
    )

    for componentIdent in ctComponents:
      let container =
        when defined(ecsSecTables):
          nnkBracketExpr.newTree(
            ident("SecTable"),
            componentIdent
          )
        else:
          nnkBracketExpr.newTree(
            ident("HeapArray"),
            componentIdent
          )

      ecsRecList.add nnkIdentDefs.newTree(
        nnkPostfix.newTree(
          ident("*"),
          ident(toComponentContainerName($componentIdent))
        ),
        container,
        newEmptyNode()
      )

    var ecsTypeDef = nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        nnkPostfix.newTree(
          ident("*"),
          ecsTypeIdent
      ), newEmptyNode(), nnkRefTy.newTree(
        nnkObjectTy.newTree(
        newEmptyNode(),
        newEmptyNode(),
        ecsRecList
      ))))

  # === ECS type Common API ===
  when true:
    result.add quote do:
      `componentKindTypeDef`

      type
        `signatureTypeIdent`* = set[`componentKindTypeIdent`]
        ## The signature of an entity describes which components it currently has. An entity's actual components are stored inside the ECS type inside a '<componentType>Container' array with index entity.idx.

      `ecsTypeDef`

      type
        `itemTypeIdent`* = tuple[`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`]
        ## Simply a tuple of the ECS and an Entity. Useful since both the ECS and entity is required  in order to add/remove the entity as well as to add/remove components to the entity.

      converter toItem*(a: (`ecsTypeIdent`, `entityTypeIdent`)): `itemTypeIdent` =
        (`ecsVarIdent`: a[0], `entityVarIdent`: a[1])

    var initHeapArraysBody = newStmtList()

    for componentTypeIdeny in ctComponents:
      let componentContainerIdent = ident(toComponentContainerName($componentTypeIdeny))
      when defined(ecsSecTables):
        initHeapArraysBody.add quote do:
          result.`componentContainerIdent` = newSecTable[`componentTypeIdeny`]()
      else:
        initHeapArraysBody.add quote do:
          result.`componentContainerIdent` = initHeapArray[`componentTypeIdeny`]()

    result.add quote do:
      proc newECS*(): `ecsTypeIdent` =
        ## Creates a new ECS (Also sometimes called 'World') into which entities can be added using ecs.newEntity()
        new(result)
        result.`signaturesVarIdent` = initSlotTableOfCap[`signatureTypeIdent`](`maxEntitiesIdent`)
        `initHeapArraysBody`

  # === Entity/Item Common API ===
  when true:
    result.add quote do:
      iterator queryAll*(`ecsVarIdent`: `ecsTypeIdent`, `queryVarIdent`: `signatureTypeIdent` = default(`signatureTypeIdent`)): `entityTypeIdent` {.inline.} =
        ## Queries the specified ECS for entities matching the query and yields entities. The query is a Signature which is a set of ComponentKind, i.e.: set[ComponentKind] = {ckPosition, ckData, ...}
        for entity, signature in `ecsVarIdent`.`signaturesVarIdent`.pairs:
          if query <= signature:
            yield entity

      iterator queryAllItems*(`ecsVarIdent`: `ecsTypeIdent`, `queryVarIdent`: `signatureTypeIdent` = default(`signatureTypeIdent`)): `itemTypeIdent` {.inline.} =
        ## Queries the specified ECS for entities matching the query and yields items. The query is a Signature which is a set of ComponentKind, i.e.: set[ComponentKind] = {ckPosition, ckData, ...}
        for entity, signature in `ecsVarIdent`.`signaturesVarIdent`.pairs:
          if query <= signature:
            yield (`ecsVarIdent`: `ecsVarIdent`, `entityVarIdent`: entity)

    result.add quote do:
      proc newEntity*(`ecsVarIdent`: `ecsTypeIdent`): `entityTypeIdent` {.discardable.} =
        ## Creates a new entity without any components. add components using '.addComponent()' or using 'add<ComponentName>()
        `ecsVarIdent`.`signaturesVarIdent`.incl(default(`signatureTypeIdent`))

      proc newItem*(`ecsVarIdent`: `ecsTypeIdent`): `itemTypeIdent` {.discardable.} =
        let entity = `ecsVarIdent`.newEntity()
        (`ecsVarIdent`, entity)

      proc newItem*(`ecsVarIdent`: `ecsTypeIdent`, `itemInitVarIdent`: proc(`itemVarIdent`: `itemTypeIdent`)): `itemTypeIdent` {.discardable.} =
        var item = `ecsVarIdent`.newItem()
        `itemInitVarIdent`(item)
        item

      proc newEntity*(`ecsVarIdent`: `ecsTypeIdent`, `itemInitVarIdent`: proc(`itemVarIdent`: `itemTypeIdent`)): `entityTypeIdent` {.discardable.} =
        var item = `ecsVarIdent`.newItem()
        `itemInitVarIdent`(item)
        item.entity

    result.add quote do:
      template createIt*(`ecsVarIdent`: `ecsTypeIdent`, `itemInitVarIdent`): `itemTypeIdent` =
        block:
          var it {.inject.}: `itemTypeIdent` = `ecsVarIdent`.newItem()
          `itemInitVarIdent`
          it

    result.add quote do:
      template removeEntity*(`itemVarIdent`: `itemTypeIdent`) =
        ## Removes the item's entity and invalidates its ID
        `itemVarIdent`[0].`signaturesVarIdent`.del(`itemVarIdent`[1])

      template removeEntity*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`) =
        ## Removes the entity and invalidates its ID
        (`ecsVarIdent`, `entityVarIdent`).removeEntity()

      template removeItem*(`itemVarIdent`: `itemTypeIdent`) =
        `itemVarIdent`.removeEntity()

    result.add quote do:
      template scheduleRemove*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`) =
        `ecsVarIdent`.`toRemoveVarIdent`.add(`entityVarIdent`)

      template scheduleRemove*(`itemVarIdent`: `itemTypeIdent`) =
        `itemVarIdent`[0].scheduleRemove(`itemVarIdent`[1])

    result.add quote do:
      proc removeScheduled*(`ecsVarIdent`: `ecsTypeIdent`) =
        for `entityVarIdent` in `ecsVarIdent`.`toRemoveVarIdent`.items:
          `ecsVarIdent`.removeEntity(`entityVarIdent`)
        `ecsVarIdent`.`toRemoveVarIdent`.setLen(0)

    result.add quote do:
      template `signatureVarIdent`*(`itemVarIdent`: `itemTypeIdent`): `signatureTypeIdent` =
        `itemVarIdent`[0].`signaturesVarIdent`[`itemVarIdent`[1]]

      template has*(`itemVarIdent`: `itemTypeIdent`, `componentKindVarIdent`: `componentKindTypeIdent`): bool =
        `componentKindVarIdent` in `itemVarIdent`.`signatureVarIdent`

      template has*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`,
                    `componentKindVarIdent`: `componentKindTypeIdent`): bool =
        `componentKindVarIdent` in (`ecsVarIdent`, `entityVarIdent`).`signatureVarIdent`

  # === Component API ===
  when true:
    var fetchComponentData: seq[tuple[kind: NimNode, container: NimNode]]

    for componentTypeIdent in ctComponents:
      let
        componentTypeString = $componentTypeIdent
        componentKindIdent = ident(toComponentKindName(componentTypeString))
        componentVarIdent = ident(toFirstLetterLower(componentTypeString))
        containerVarIdent = ident(toComponentContainerName(componentTypeString))

        addComponentIdent = ident("add" & componentTypeString)
        removeComponentIdent = ident("remove" & componentTypeString)

        tIdent = ident("t")

        addComponentComment = newCommentStmtNode(&"Adds a component of type '{componentTypeString}' and includes '{$componentKindIdent}' into the {$entityVarIdent}'s signature ")
        removeComponentComment = newCommentStmtNode(&"Removes component of type '{componentTypeString}' and excludes '{$componentKindIdent}' from the {$entityVarIdent}'s signature ")

        componentSectionComment = newCommentStmtNode(&"Procs and templates for: {componentTypeString}")
        assignComponentIdent = nnkAccQuoted.newTree(
          componentVarIdent,
          ident("=")
        )

        hasComponentIdent = ident(&"has{componentTypeString}")

        getComponentIdent = ident(&"get{componentTypeString}")
        setComponentIdent = ident(&"set{componentTypeString}")
        componentContainerIdent = ident(toComponentContainerName($componentTypeString))

      fetchComponentData.add((componentKindIdent, componentContainerIdent))

      result.add componentSectionComment

      result.add quote do:
        template `hasComponentIdent`*(`itemVarIdent`: `itemTypeIdent`): bool =
          `itemVarIdent`.has `componentKindIdent`

      result.add quote do:
        proc `addComponentIdent`*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`,
                                  `componentVarIdent`: `componentTypeIdent` = default(`componentTypeIdent`)) =
          `addComponentComment`
          `ecsVarIdent`.`signaturesVarIdent`[`entityVarIdent`].incl `componentKindIdent`
          `ecsVarIdent`.`containerVarIdent`[`entityVarIdent`.idx] = `componentVarIdent`

        template `addComponentIdent`*(`itemVarIdent`: `itemTypeIdent`,
                                    `componentVarIdent`: `componentTypeIdent` = default(`componentTypeIdent`)) =
          `addComponentComment`
          `itemVarIdent`[0].`addComponentIdent`(`itemVarIdent`[1], `componentVarIdent`)

        template addComponent*(`itemVarIdent`: `itemTypeIdent`,
                              `componentVarIdent`: `componentTypeIdent` = default(`componentTypeIdent`)) =
          `addComponentComment`
          `itemVarIdent`.`addComponentIdent`(`componentVarIdent`)

        template addComponent*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`,
                              `componentVarIdent`: `componentTypeIdent` = default(`componentTypeIdent`)) =
          `addComponentComment`
          (`ecsVarIdent`, `entityVarIdent`).`addComponentIdent`(`componentVarIdent`)

      result.add quote do:
        template `getComponentIdent`*(`itemVarIdent`: `itemTypeIdent`): `componentTypeIdent` =
          assert `componentKindIdent` in `itemVarIdent`.`signatureVarIdent`
          `itemVarIdent`[0].`containerVarIdent`[`itemVarIdent`[1].idx]

        proc `setComponentIdent`(`itemVarIdent`: `itemTypeIdent`,
                                  `componentVarIdent`: `componentTypeIdent`) =
          if `componentKindIdent` notin `itemVarIdent`.`signatureVarIdent`:
            `itemVarIdent`.`addComponentIdent`(`componentVarIdent`)
          else:
            `itemVarIdent`[0].`containerVarIdent`[`itemVarIdent`[1].idx] = `componentVarIdent`

      result.add quote do:
        template `componentVarIdent`*(`itemVarIdent`: `itemTypeIdent`): `componentTypeIdent` =
          `itemVarIdent`.`getComponentIdent`()

        template `assignComponentIdent`*(`itemVarIdent`: `itemTypeIdent`,
                                        `componentVarIdent`: `componentTypeIdent`) =
          `itemVarIdent`.`setComponentIdent`(`componentVarIdent`)

      result.add quote do:
        proc `removeComponentIdent`*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`) =
          `removeComponentComment`
          `ecsVarIdent`.`signaturesVarIdent`[`entityVarIdent`].excl `componentKindIdent`

        template `removeComponentIdent`*(`itemVarIdent`: `itemTypeIdent`) =
          `removeComponentComment`
          `itemVarIdent`[0].`removeComponentIdent`(`itemVarIdent`[1])

        template removeComponent*(`itemVarIdent`: `itemTypeIdent`, `tIdent`: typedesc[`componentTypeIdent`]) =
          `removeComponentComment`
          `itemVarIdent`.`removeComponentIdent`()

        template removeComponent*(`ecsVarIdent`: `ecsTypeIdent`,
                                  `entityVarIdent`: `entityTypeIdent`,
                                  `tIdent`: typedesc[`componentTypeIdent`]) =
          `removeComponentComment`
          (`ecsVarIdent`, `entityVarIdent`).`removeComponentIdent`()

    let
      kindIdent = ident("kind")
      resultIdent = ident("result")
      inspectComponentIdent = ident("inspectComponent")

    var kindCaseStmt = nnkCaseStmt.newTree(kindIdent)

    for (kind, container) in fetchComponentData:
      kindCaseStmt.add nnkOfBranch.newTree(
        kind,
        quote do: $`itemVarIdent`[0].`container`[`itemVarIdent`[1].idx]
      )

    result.add quote do:
      template `inspectComponentIdent`*(`itemVarIdent`: `itemTypeIdent`,
                                        `kindIdent`: `componentKindTypeIdent`): string =
        `kindCaseStmt`

      template `inspectComponentIdent`*(`ecsVarIdent`: `ecsTypeIdent`,
                                        `entityVarIdent`: `entityTypeIdent`,
                                        `kindIdent`: `componentKindTypeIdent`): string =
        (`ecsVarIdent`, `entityVarIdent`).`inspectComponentIdent`(`kindIdent`)

    # The reasong we loop over low(ComponentKind)..high(ComponentKind) instead of simply the item's signature
    # is because the signature is not guaranteed to be in a specific order. The order of components being the
    # same every time is useful when one would actuallly use this proc (as a debug aid).
    let theComment = newCommentStmtNode("Returns a string representation of an entity and all its components. This is only intended as a debug aid and its use might have significant performance implications.")
    result.add quote do:
      proc inspect*(`itemVarIdent`: `itemTypeIdent`): string =
        `theComment`
        `resultIdent` = $`itemVarIdent`[1] & ":\n"

        for `kindIdent` in low(`componentKindTypeIdent`)..high(`componentKindTypeIdent`):
          if `itemVarIdent`.has(`kindIdent`):
            `resultIdent` &= " " & $`kindIdent` & ": " & `itemVarIdent`.`inspectComponentIdent`(`kindIdent`)
            `resultIdent` &= "\n"
        `resultIdent` = `resultIdent`[0..^2] # remove last \n

    result.add quote do:
      proc inspect*(`ecsVarIdent`: `ecsTypeIdent`, `entityVarIdent`: `entityTypeIdent`): string =
        `theComment`
        `resultIdent` = $`entityVarIdent` & ":\n"

        for `kindIdent` in low(`componentKindTypeIdent`)..high(`componentKindTypeIdent`):
          if `ecsVarIdent`.has(`entityVarIdent`, `kindIdent`):
            `resultIdent` &= " " & $`kindIdent` & ": " & `ecsVarIdent`.`inspectComponentIdent`(`entityVarIdent`, `kindIdent`)
            `resultIdent` &= "\n"
        `resultIdent` = `resultIdent`[0..^2] # remove last \n

  # === Systems API ===
  when true:
    for systemDef in ctSystemDefs:
      result.add systemDef

    result.add newCommentStmtNode("=== System Groups ===")
    for (groupNameString, systemIdents) in ctSystemGroups.pairs:
      let
        runGroupNameIdent = ident("run" & toFirstLetterUpper(groupNameString))
        runGroupComment = newCommentStmtNode(&"Runs every system in the group '{groupNameString}'.")

      var
        runGroupBody = newStmtList()
        groupFormalParams = nnkFormalParams.newTree(
          newEmptyNode(),
          newIdentDefs(
            ecsVarIdent,
            ecsTypeIdent,
            newEmptyNode()
          )
        )

      var alreadyAddedGroupParams: HashSet[string]

      for systemIdent in systemIdents:
        # TODO: Make sure that groups require the correct params and call the correct systems with them
        var systemCall = nnkCall.newTree(
          systemIdent
        )

        var systemParams = ctSystemParams[$systemIdent]

        for i in 1 ..< len(systemParams):
          let theParams = systemParams[i]

          if i == 1: # first parameter must currently be ECS
            systemCall.add nnkExprEqExpr.newTree(
              theParams[0],
              ecsVarIdent
            )
            continue

          systemCall.add theParams[0]

          let key = ($theParams[0]).toLowerAscii()
          if key notin alreadyAddedGroupParams:
            groupFormalParams.add theParams
            alreadyAddedGroupParams.incl(key)

        runGroupBody.add systemCall

      var runGroupProc = quote do:
        proc `runGroupNameIdent`*() {.inline.} =
          `runGroupComment`
          `runGroupBody`

      runGroupProc.params = groupFormalParams

      when defined(ecsDebugGroupCalls):
        echo repr(runGroupProc)

      result.add runGroupProc

  when defined(ecsDebugMacros):
    echo repr(result)

template createECS*() = makeECS()


when isMainModule:
  type
    Vector2 = object
      x: float
      y: float

    Position {.comp.} = Vector2
    Velocity {.comp.} = Vector2

    Data1 {.comp.} = tuple
      d: bool

    Flag {.comp.} = bool

    Flag2 {.comp.} = int

    States {.comp.} = enum
      sOne, sTwo, sThree

    Label {.comp.} = string

  proc positionSys(ecs: ECS) {.sys: (pos: Position, vel: Velocity, Data1),
                               group: "logicSystems", all.} =
    pos.x += vel.x
    pos.y += vel.y


  func restSys(customECSParamName: ECS) {.sys: (Data1, Flag, Flag2),
                                          group: "renderingSystems".} =
    for item in customECSParamName.queryAllItems(signature):
      debugEcho " ", item

  makeECS()

  var
    world = newECS()
    player = world.newItem()

  player.addComponent(position = Position(x: 0.0, y: 0.0))
  player.addPosition(Position(x: 100.0, y: 100.0))
  player.addVelocity(Velocity(x: 100.0, y: 100.0))
  player.addData1()
  player.addFlag()
  player.addFlag2()

  doAssert player.has(ckPosition)
  doAssert player.hasPosition()

  for i in 0..<1:
    let player2 = world.createIt():
      it.addPosition()
      it.addVelocity()
      it.addData1()

    doAssert player2.has(ckVelocity)
    doAssert player2.hasVelocity()

  for i in 0..<3:
    let oldPosition = player.position
    world.runLogicSystems()
    doAssert player.position.x > oldPosition.x

  let
    test1 = world.newEntity()
    test2 = world.newEntity()
  echo test1, " ", test2
