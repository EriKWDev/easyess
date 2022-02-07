import easyess

comp:
  type
    ExampleComponent* = object
      data*: int

    TupleComponent* = tuple ## \
      ## Note that in order to export you Components
      ## you, as usual, have to explicitly mark the
      ## type with `*`
      data: string
      data2: int

    EnumComponent* = enum
      ecFlagOne
      ecFlagTwo

    Health* = distinct int

    InternalUnexportedFlag = distinct bool

sys [ExampleComponent], "systems":
  proc system(item: ECItem) =
    discard

createECS()

let ecs = newECS()

