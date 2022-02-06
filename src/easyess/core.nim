import macros, strutils, strformat, tables

export macros, tables

type
  BaseIDType = uint16

  Entity* = distinct BaseIDType

  ComponentDefinition = tuple
    name: NimNode
    body: NimNode

  SystemDefinition = tuple
    name: NimNode
    signature: NimNode
    itemType: NimNode
    components: NimNode
    requestsVar: bool

  ECSConfig* = object
    maxEntities*: int

const ecsDebugMacros = false or defined(ecsDebugMacros)

template idx*(entity: Entity): int = entity.int


func firstLetterLower(word: string): string =
  word[0..0].toLower() & word[1..^1]

func firstLetterUpper(word: string): string =
  word[0..0].toUpper() & word[1..^1]

func toComponentKindName(word: string): string =
  "ck" & firstLetterUpper(word)

func toContainerName(word: string): string =
  firstLetterLower(word) & "Container"

func `$`*(entity: Entity): string =
  result = "Entity(id:" & $entity.idx & ")"

func `component`*[T](c: NimNode): (typedesc, NimNode) {.compileTime.} =
  (T, c)

var
  systemDefinitions {.compileTime.}: Table[string, seq[SystemDefinition]]
  componentDefinitions {.compileTime.}: seq[ComponentDefinition]
  numberOfComponents {.compileTime.} = 0

  ecsType {.compileTime.} = nnkRefTy.newTree(ident("ECS"))
  entityName {.compileTime.} = ident("entity")
  ecsName {.compileTime.} = ident("ecs")

macro comp*(body: untyped) =
  for typeSectionChild in body:
    for typeDefChild in typeSectionChild:
      typeDefChild.expectKind(nnkTypeDef)

      block typeDefLoop:
        for postfixOrIdent in typeDefChild:
          case postfixOrIdent.kind:
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
  # Define a system

  var
    itemName: NimNode
    itemType: NimNode

    systemName: NimNode
    systemBody: NimNode

  let
    systemsignature = newNimNode(nnkCurly)
    beforeSystem = newNimNode(nnkStmtList)
    afterSystem = newNimNode(nnkStmtList)
    tupleDef = newNimNode(nnkTupleTy)
    containerTemplates = newNimNode(nnkStmtList)

  var
    before = true
    isFunc = true
    requestsVar = false

  for c1 in system:
    if c1.kind in {nnkProcDef, nnkFuncDef}:
      isFunc = c1.kind == nnkFuncDef
      for c2 in c1:
        case c2.kind:
          of nnkIdent:
            systemName = c2

          of nnkFormalParams:
            for c3 in c2:
              if c3.kind == nnkIdentDefs:
                for i, c4 in c3:
                  if i == 0:
                    itemName = c4
                    continue

                  elif i == 1:
                    if c4.kind == nnkVarTy:
                      requestsVar = true
                      for c5 in c4:
                        itemType = c5
                        break
                      continue

                    itemType = c3

          of nnkStmtList:
            systemBody = c2
            before = false

          else: discard
    else:
      if before:
        beforeSystem.add(c1)
      else:
        afterSystem.add(c1)

  let systemDefinition: SystemDefinition = (
    name: systemName,
    signature: systemsignature,
    itemType: itemType,
    components: components,
    requestsVar: requestsVar
  )

  for component in components:
    systemsignature.add(ident(toComponentKindName($component)))

    let
      componentLower = ident(firstLetterLower($component))
      containerName = ident(toContainerName($component))

    containerTemplates.add quote do:
      template `componentLower`(): untyped =
        `itemName`.`ecsName`.`containerName`[`itemName`.`entityName`.idx]

    let identDefs = newNimNode(nnkIdentDefs).add(
      componentLower,
      ident($component),
      newNimNode(nnkEmpty)
    )
    tupleDef.add(identDefs)

  let key = $group
  if key notin systemDefinitions:
    systemDefinitions[key] = @[]

  systemDefinitions[key].add(systemDefinition)

  result = newNimNode(nnkStmtList)

  result.add quote do:
    type `itemType`* = tuple[`ecsName`: `ecsType`; `entityName`: Entity]

  result.add quote do:
    `beforeSystem`

  if isFunc:
    result.add quote do:
      func `systemName`*(`itemName`: `itemType`) {.used.} =
        `containerTemplates`

        `systemBody`
  else:
    result.add quote do:
      proc `systemName`*(`itemName`: `itemType`) {.used.} =
        `systemBody`

  result.add quote do:
    `afterSystem`

  when ecsDebugMacros: echo repr(result)

macro createECS*(config: static[ECSConfig] = ECSConfig(maxEntities: 100)) =
  result = newNimNode(nnkStmtList)

  let
    componentKindType = ident("ECSComponentKind")
    signatureType = ident("Signature")

    usedLabelsName = ident("usedLabels")
    currentIdName = ident("currentId")
    componentName = ident("component")
    entitiesName = ident("entities")
    releaseName = ident("release")
    queryName = ident("query")
    itemName = ident("item")
    kindName = ident("kind")
    idName = ident("id")

    maxEntities = config.maxEntities
    enumType = newNimNode(nnkEnumTy).add(newEmptyNode())
    setBasedOnComponent = newStmtList()
    containerDefs = newNimNode(nnkRecList)

  containerDefs.add nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), currentIdName),
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
            ident("bool")), newEmptyNode()))))

  containerDefs.add nnkIdentDefs.newTree(
    nnkPostfix.newTree(ident("*"), entitiesName),
    nnkBracketExpr.newTree(
      ident("array"),
      newIntLitNode(maxEntities),
      signatureType), newEmptyNode())

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

      `signatureType`* = set[`componentKindType`]

    `ecsDef`

  result.add quote do:
    func newEcs*(): `ecsType` =
      new(result)

  result.add quote do:
    func inspect*(`ecsName`: `ecsType`; `entityName`: Entity): string =
      ## Get a string representation of `entity` including its label.
      ## When `release` is defined, only the entity id is returned as a string.
      when not defined(release):
        result = "Entity("
        result &= $`ecsName`.`entitiesName`[`entityName`.idx]
        result &= ")"
      else:
        result = $`entityName`

  result.add quote do:
    func newEntity*(`ecsName`: `ecsType`; label: string): Entity =
      when not defined(release):
        var
          n = 0
          actualName = label

        while actualName in `ecsName`.`usedLabelsName`:
          inc n
          actualName = label & " (" & $n & ")"

        `ecsName`.`usedLabelsName`[actualName] = true

      for id in `ecsName`.`currentIdName`.idx .. high(`ecsName`.`entitiesName`):
        if card(`ecsName`.`entitiesName`[id]) == 0:
          `ecsName`.`currentIdName` = id.Entity
          return `ecsName`.`currentIdName`

  result.add quote do:
    func register(`ecsName`: `ecsType`;
                  `entityName`: Entity;
                  signature: `signatureType` = {}) =
      `ecsName`.`entitiesName`[`entityName`.idx] = signature

  result.add quote do:
    func extractComponents*(root: NimNode): seq[NimNode] {.compileTime.} =
      root.expectKind(nnkStmtList)
      for c1 in root:
        c1.expectKind(nnkTupleConstr)
        for c2 in c1:
          result.add(c2)

  result.add quote do:
    func extractComponentName*(component: NimNode): string {.compileTime.} =
      case component.kind:
        of nnkObjConstr:
          for c1 in component:
            case c1.kind:
              of nnkIdent:
                return $c1

              of nnkBracket:
                for c2 in c1:
                  return $c2

              else: discard

        of nnkCommand:
          for c1 in component:
            c1.expectKind(nnkBracket)
            for c2 in c1:
              return $c2

        else: discard

  result.add quote do:
    macro defineSignature*(components: untyped) =
      let curly = newNimNode(nnkCurly)

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
      case component.kind:
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
          assert false, "Component " & repr(component) & " can currently not be interpreted"

  result.add quote do:
    macro defineComponentAssignments*(`ecsName`: `ecsType`;
                                      `entityName`: untyped;
                                      components: untyped) =
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
    template registerEntity*(`ecsName`: `ecsType`;
                             label: string;
                             components: untyped): Entity =
      var entity: Entity
      block:
        defineSignature(components)

        entity = ecs.newEntity(label)
        `ecsName`.register(entity, signature)

        `ecsName`.defineComponentAssignments(entity, components)

      entity

  result.add quote do:
    iterator queryAll*(`ecsName`: `ecsType`;
        `queryName`: `signatureType`): Entity =
      for id in 0 .. high(`ecsName`.`entitiesName`):
        if `ecsName`.`entitiesName`[id] >= `queryName`:
          yield id.Entity

  for groupName, systems in systemDefinitions.pairs:
    let
      groupIdent = ident("run" & firstLetterUpper(groupName))
      systemsDef = newNimNode(nnkStmtList)

    for system in systems:
      let (name, signature, itemType, _, requestsVar) = system

      let itemConstruction = quote do:
        (`ecsName`, `entityName`)

      if not requestsVar:
        systemsDef.add quote do:
          for `idName` in `ecsName`.queryAll(`signature`):
            let `itemName`: `itemType` = `itemConstruction`
            `name`(`itemname`)
      else:
        systemsDef.add quote do:
          for `idName` in `ecsName`.queryAll(`signature`):
            var `itemName`: `itemType` = `itemConstruction`
            `name`(`itemName`)

    result.add quote do:
      proc `groupIdent`(`ecsName`: `ecsType`) =
        `systemsDef`

  when ecsDebugMacros: echo repr(result)

