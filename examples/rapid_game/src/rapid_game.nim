import aglet
import aglet/window/glfw
import rapid/graphics
import glm

import easyess

comp:
  type
    Position = Vec2[float]

    Velocity = Vec2[float]

sys [Position, Velocity], "logicSystems":
  proc positionVelocitySystem(item: Item) =
    echo position
    echo velocity

    position += velocity

sys [vel: Velocity], "logicSystems":
  proc velocitySystem(item: Item) =
    vel *= 0.8

createECS(ECSConfig(maxEntities: 1200))

proc main() =
  var agl = initAglet()
  agl.initWindow()

  let
    window = agl.newWindowGlfw(800, 600, "rapid/gfx", winHints(msaaSamples = 8))
    graphics = window.newGraphics()

  const bg = rgba(0.125, 0.125, 0.125, 1.0)

  var world = newECS()

  discard world.createEntity("Player"): (
    [Position]vec2(0.0, 0.0),
    [Velocity]vec2(10.0, 10.0)
  )

  while not window.closeRequested:
    window.pollEvents do (event: InputEvent):
      case event.kind
      of iekWindowFrameResize:
        echo event.size

      of iekKeyPress:
        echo event
        case event.key
        of keyEsc: window.requestClose()
        else: discard

      else: discard

    var frame = window.render()
    frame.clearColor(bg)
    frame.finish()

    world.runLogicSystems()


when isMainModule:
  main()
