
import nimraylib_now
import easyess

import std/[random]

func vec3(x, y, z: float): Vector3 {.inline.} =
  Vector3(x: x, y: y, z: z)


type
  Game = ref object
    camera: Camera3D
    deltaTime: float

comp:
  type
    Position = Vector3

    Velocity = Vector3

    Sphere = object
      radius: float


sys [Position, Velocity], "logicSystems":
  proc moveSystem(item: Item, game: Game) =
    position += velocity * game.deltaTime * 10.0
    velocity *= max(min(1.0, game.deltaTime * 8.0), 0.98)

    if abs(velocity.x) < 0.1 and abs(velocity.y) < 0.1 and abs(velocity.z) < 0.1:
      velocity = vec3(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0), rand(-1.0 .. 1.0))


sys [Position, Sphere], "renderSystems":
  proc renderSphereSystem(item: Item) =
    drawSphereWires(position, sphere.radius, 5, 5, RED)


createECS(ECSConfig(maxEntities: 5000))


const n = 2500

proc main() =
  setConfigFlags(MSAA_4X_HINT or WINDOW_RESIZABLE)

  initWindow(800, 800, "3D game")
  setTargetFPS 0

  let ecs = newECS()

  for i in 0 .. n:
    discard ecs.createEntity("Sphere"): (
      Sphere(radius: rand(0.1 .. 0.6)),
      [Position]vec3(0.0, 0.0, 0.0),
      [Velocity]vec3(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0), rand(-1.0 .. 1.0)),
    )

  let game = Game.new()

  game.camera = Camera3D(
    position: vec3(0.0, 10.0, 10.0),
    target: vec3(0.0, 0.0, 0.0),
    up: vec3(0.0, 1.0, 0.0),
    fovy: 95.0,
    projection: PERSPECTIVE
  )
  game.camera.setCameraMode(CameraMode.ORBITAL)

  while not windowShouldClose():
    game.deltaTime = getFrameTime()
    updateCamera(game.camera.addr)

    ecs.runLogicSystems(game)

    beginDrawing():
      clearBackground(Color(r: 12, g: 12, b: 12))

      beginMode3D(game.camera):
        ecs.runRenderSystems()
        drawGrid(100, 1.0)

      drawFPS 10, 10

  closeWindow()


when isMainModule:
  main()
