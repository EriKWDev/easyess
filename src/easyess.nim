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
 its usefulness. You can nom create a file named `ecs.nim` within which you do `import esasyess`,
 define all your components and systems and call `createECS <easyess.html#createECS.m,static[ECSConfig]>`_
 which generates a bunch of code that is exported from the file. You can the simply
 `import ecs` within your other modules without any name conflict with this package.

Note on Docs
============
Since the toplevel exported parts of `easyess` are just three macros, I thought it much more helpful to provide
documentation on all the code that is generated at compiletime once you actually use the package within your code.

In order to show all functions, procs, templates and macros that are generated in the end
by the `createECS <easyess.html#createECS.m,static[ECSConfig]>`_ macro, these docs were generated with the following code present.

.. code-block:: nim
    import easyess

    comp:
      type
        ExampleComponent* = object ## \
        ## An example component for documentation purposes
          data: int

        DocumentationComponent* = tuple ## \
        ## An example component for documentation purposes
          data: float

        ExampleFlag* = enum ## \
        ## An example component for documentation purposes
          efOne
          efTwo

        ExampleID* = uint16 ## \
        ## An example component for documentation purposes

    sys [ExampleComponent, DocumentationComponent, ExampleFlag], "exampleSystems":
      func exampleSystem(item: Item) =
        let (ecs, entity) = item

        discard exampleComponent.data
        discard documentationComponent.data
        discard exampleFlag

    sys [ExampleID], "exampleSystems":
      func exampleIDSystem(item: Item) =
        discard exampleID

    createECS(ECSConfig(maxEntities: 100))

]##

when not defined(docgen):
  import ./easyess/core

  export core

else:
  include ./easyess/core

  comp:
    type
      ExampleComponent* = object ## \
        ## An example component for documentation purposes
        data: int

      DocumentationComponent* = tuple ## \
        ## An example component for documentation purposes
        data: float

      ExampleFlag* = enum ## \
        ## An example component for documentation purposes
        efOne
        efTwo

      ExampleID* = uint16 ## \
        ## An example component for documentation purposes

  sys [ExampleComponent, DocumentationComponent, ExampleFlag], "exampleSystems":
    func exampleSystem(item: Item) =
      let (ecs, entity) = item

      discard exampleComponent.data
      discard documentationComponent.data
      discard exampleFlag

  sys [ExampleID], "exampleSystems":
    func exampleIDSystem(item: Item) =
      discard exampleID

  createECS(ECSConfig(maxEntities: 100))
