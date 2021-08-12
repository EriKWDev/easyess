
import easyess/core

registerComponents:
  type
    Transform* = object
      position*: int
      rotation*: int

    Physics* = object
      velocity*: int


import easyess/components

system move, [ Transform, Physics ]:
  discard

system damping, [ Physics ]:
  discard

commitSystems run

when isMainModule:
  run()
