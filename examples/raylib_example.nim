
import std/[random]
import pkg/[easyess, nimraylib_now]


# === Components ===

when true:
  type
    Position {.comp.} = Vector2

    Velocity {.comp.} = Vector2

    DrawData {.comp.} = object
      color: Color
      radius: float


# === Systems ===

when true:
  proc positionSystem(ecs: ECS) {.sys: (pos: Position, Velocity), group: "logicSystems".} =
    let
      mousePos = getMousePosition()
      isPressed = isMouseButtonDown(MouseButton.LEFT)

    for item in ecs.queryAllItems(signature):
      item.pos += item.velocity

      var dirToMouse = item.pos - mousePos

      if length(dirToMouse) < 200:
        if isPressed: dirToMouse = -dirToMouse
        item.velocity += dirToMouse.normalize() * 2.0

  proc velocitySystem(ecs: ECS) {.sys: (vel: Velocity), group: "logicSystems", all.} =
    vel *= 0.97

    if length(vel) < 0.1:
      vel = (rand(-10.0..10.0), rand(-10.0..10.0))

  proc stayInWindowSystem(ecs: ECS) {.sys: (pos: Position), group: "logicSystems".} =
    let
      w = getScreenWidth().toFloat()
      h = getScreenHeight().toFloat()

    for item in ecs.queryAllItems(signature):
      if item.pos.x < 0: item.pos.x += w
      elif item.pos.x > w: item.pos.x -= w

      if item.pos.y < 0: item.pos.y += h
      elif item.pos.y > h: item.pos.y -= h

  proc clearScreenSystem(ecs: ECS) {.sys, group: "renderingSystems".} =
    clearBackground BLACK

  proc drawSystem(ecs: ECS) {.sys: (pos: Position, DrawData), group: "renderingSystems".} =
    let
      w = getScreenWidth().toFloat()
      h = getScreenHeight().toFloat()

    for item in ecs.queryAllItems(signature):
      let
        r = item.drawData.radius
        d = r * 2
        pos = item.pos

      if pos.x - d > w or pos.x + d < 0 or
         pos.y - d > h or pos.y + d < 0:
        continue

      drawCircleSector(pos, r, 0.0, 360.0, 8, item.drawData.color)

  proc drawGUISystem(ecs: ECS) {.sys, group: "renderingSystems".} =
    drawRectangleRec((0.0, 0.0, 300.0, 100.0), WHITE)
    drawFPS 10, 10
    drawText textFormat("Number of entities: %d", len(ecs.signatures)), 10, 30, 20, RED
    drawText "Click with mouse!", 10, 50, 15, RED

makeECS()


# === Adding Entities ===

proc initWorld(world: ECS) =
  const numberOfEntities = 50_000

  template randomColor(): Color =
    Color(r: rand(255).uint8, g: rand(255).uint8, b: rand(255).uint8, a: 255.uint8)

  for i in 0 ..< numberOfEntities:
    world.newItem() do (it: Item):
      it.position = (rand(0.0..900.0), rand(0.0..1150.0))
      it.velocity = (rand(-10.0..10.0), rand(-10.0..10.0))

      if rand(0.0..1.0) > 0.8:
        it.drawData = DrawData(color: randomColor(), radius: rand(1.0..5.0))
      else:
        it.drawData = DrawData(color: RED, radius: rand(0.8..3.0))


# === Gameloop ===

const
  fixedDelta = 1.0/60.0

proc main() =
  randomize()
  setConfigFlags(WINDOW_RESIZABLE or MSAA_4X_HINT)

  initWindow(800, 950, "Easyess Example with Raylib")
  setTargetFPS 0 # No FPS limit for rendering

  var world = newECS()
  world.initWorld()

  var
    previousTime = getTime()
    lag = 0.0

  while not windowShouldClose():
    let
      currentTime = getTime()
      delta = currentTime - previousTime

    lag += delta
    previousTime = currentTime

    while lag >= fixedDelta:
      world.runLogicSystems()
      lag -= fixedDelta

    beginDrawing():
      world.runRenderingSystems()

  closeWindow()


when isMainModule:
  main()
