#
#
#                     Easyess
#        (c) Copyright 2022 Erik W. Gren
#
#       See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#


##[

 :Author: ErikWDev (Erik W. Gren)
 :Copyright: 2022


 The `easyess` module aims to provive a basic ECS setup for nim with
 macros and templates in order to abstract away the implementation
 details with minimal effect on performance.

 `easyess` is still under active development. For a more complete, mature
 and flexible setup I recommend the package [polymorph](https://github.com/rlipsc/polymorph).

Note on Docs
============

In order to show all functions, procs, templates and macros that are generated in the end
by the #createECS macro, these docs were generated with the code below present.

.. code-block:: nim
    import easyess

    comp:
      type
        ExampleComponent = object of Component
          exampleData: int

        OtherExampleComponent = object of Compnoent
          otherData: float

    sys [ExampleComponent, OtherExampleComponent], "exampleSystems":
      func exampleSystem(item: ExampleItem) =
        discard item.exampleComponent.exampleData
        discard item.otherExampleComponent.otherData

    createECS(ECSConfig(maxEntities: 100))


Parsing and Formatting Dates
============================

  

]##

when not defined(nimdoc):
  import ./easyess/core

  export core

else:
  include ./easyess/core

  comp:
    type
      ExampleComponent = object of Component
        exampleData: int

      OtherExampleComponent = object of Compnoent
        otherData: float

  sys [ExampleComponent, OtherExampleComponent], "exampleSystems":
    func exampleSystem(item: ExampleItem) =
      discard item.exampleComponent.exampleData
      discard item.otherExampleComponent.otherData

  createECS(ECSConfig(maxEntities: 100))
