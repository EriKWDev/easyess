
import
  macros,
  tables,
  sets,
  strformat,
  strutils


func firstLetterLower(word: string): string {.inline.} =
  return word[0..0].toLower() & word[1..^1]

func firstLetterUpper(word: string): string {.inline.} =
  return word[0..0].toUpper() & word[1..^1]

func enumName(name: string): string {.inline.} =
  return "ecsce" & firstLetterUpper(name)

func tableName(name: string): string {.inline.} =
  return firstLetterLower(name) & "componentTable"


type
  ECSComponentDeclaration = object
    name: NimNode
    body: NimNode

  ECSSystemDeclaration = object
    name: NimNode
    componentNames: seq[string]
    body: NimNode

  ECSEntityID = int

var
  ecsComponentDeclarations* {.compileTime.} = newSeq[ECSComponentDeclaration]()
  ecsSystemDeclarations* {.compileTime.} = newSeq[ECSSystemDeclaration]()


macro system*[N](name: untyped, components: array[N, typed], body: untyped) =
  var componentNames: seq[string]

  for component in components:
    componentNames.add(component.repr)

  let systemDeclaration = ECSSystemDeclaration(
    name: name,
    body: body,
    componentNames: componentNames
  )

  ecsSystemDeclarations.add(systemDeclaration)

  return
    quote do:
      type
        ECSTransformTuple = tuple[transform: ptr Transform, id: ECSEntityID]

      proc `name`*(entities: seq[ECSTransformTuple]) =
        `body`

macro commitSystems*(name: untyped) =
  let runnerBody = newNimNode(nnkEmpty)

  return
    quote do:
      proc `name`*() =
        `runnerBody`


macro registerComponents*(body: untyped) =
  for typeSectionChild in body.children:
    for typeDefChild in typeSectionChild.children:
      typeDefChild.expectKind(nnkTypeDef)

      block typeDefLoop:
        for postfixOrIdent in typeDefChild.children:
          case postfixOrIdent.kind:
            of nnkPostfix:
              for identifier in postfixOrIdent.children:
                if identifier.eqIdent("*"):
                  continue

                ecsComponentDeclarations.add(ECSComponentDeclaration(
                  name: identifier,
                  body: typeDefChild
                ))

                break typeDefLoop

            of nnkIdent:
              ecsComponentDeclarations.add(ECSComponentDeclaration(
                name: postfixOrIdent,
                body: typeDefChild
              ))

              break typeDefLoop

            else:
              error(&"{postfixOrIdent.kind}''Has to be Identifier or Postfix NimNodeKind", postfixOrIdent)


macro commitComponents*() =
  let typeSection = newNimNode(nnkTypeSection)

  for componentDeclaration in ecsComponentDeclarations:
    typeSection.add(componentDeclaration.body)

  result = newStmtList(typeSection)
