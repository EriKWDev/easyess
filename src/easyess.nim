#
#
#                      Easyess
#            Copyright (c) 2022 ErikWDev
#
#       See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#


##[

 :Author: ErikWDev (Erik W. Gren)
 :Copyright: 2021-2022


 The `easyess` module aims to provive a basic ECS setup for nim with
 macros and templates in order to abstract away the implementation
 details with minimal effect on performance.

 `easyess` is still under active development. For a more complete, mature
 and flexible setup I recommend the package [polymorph](https://github.com/rlipsc/polymorph).

 While the name `easyess` might seem terrible for searchability (and it is..), I still argue
 its usefulness. You can nom create a file named `ecs.nim` within which you can do `import esasyess`
 and call `createECS()` which generates a bunch of code that is exported from the file. You can then
 simply `import ecs` within your other modules without any name conflict with this package.

Note on Docs
============

In order to show all functions, procs, templates and macros that are generated in the end
by the `createECS()` macro, these docs were generated with the code below present.

.. code-block:: nim
    import easyess

    comp:
      type
        ExampleComponent = object
          exampleData: int

        OtherExampleComponent = tuple
          otherData: float

        ExampleFlag = enum
          efOne
          efTwo

    sys [ExampleComponent, OtherExampleComponent, ExampleFlag], "exampleSystems":
      func exampleSystem(item: ExampleItem) =
        let (ecs, entity) = item

        discard exampleComponent.exampleData
        discard otherExampleComponent.otherData
        discard exampleFlag

    createECS(ECSConfig(maxEntities: 100))

]##

when not defined(docgen):
  import ./easyess/core

  export core

else:
  include ./easyess/core

  comp:
    type
      ExampleComponent = object
        exampleData: int

      OtherExampleComponent = tuple
        otherData: float

      ExampleFlag = enum
        efOne
        efTwo

  sys [ExampleComponent, OtherExampleComponent, ExampleFlag], "exampleSystems":
    func exampleSystem(item: ExampleItem) =
      let (ecs, entity) = item

      discard exampleComponent.exampleData
      discard otherExampleComponent.otherData
      discard exampleFlag

  createECS(ECSConfig(maxEntities: 100))
