import random

import aglet
import aglet/window/glfw
import rapid/graphics
import glm

import easyess

type
  InputKind = enum
    ikMoveUp, ikMoveDown, ikMoveLeft, ikMoveRight

  Game = object
    graphics: Graphics
    input: set[InputKind]

# === Components ===
when true:
  comp:
    type
      Position = Vec2[float]

      Velocity = Vec2[float]

      IsMove = bool
      DidGrow = bool

      GridPosition = Vec2[int]
      GridCollider = bool

      Direction = enum
        dNone, dUp, dDown, dLeft, dRight

      NextDirection = Direction
      NextGridPosition = GridPosition

      Player = bool
      Apple = bool
      TailReference = Entity
      HeadReference = Entity

      Snake = int
      Tail = bool
      NextSnake = Entity

      Explosion = int
      Particle = Color

const
  gridSize = 12
  gridSizeFloat = gridSize.toFloat()

func manhattanDistance(a, b: Vec2[int]): int {.inline.} =
  return abs(a.x - b.x) + abs(a.y - b.y)

# === Systems ===
when true:
  # === Logic Systems ===
  when true:
    sys [Explosion, Position], "logicSystems":
      proc createExmplosion(item: Item) =
        for i in 0 .. explosion:
          let
            color = rgba(rand(0.0 .. 1.0), rand(0.0 .. 1.0), rand(0.0 .. 1.0), 0.4)
            s = 10.0
            velocity = vec2(rand(-s .. s), rand(-s .. s))

          discard item.ecs.createEntity("Particle"): (
            [Particle]color,
            [Position]position,
            [Velocity]velocity
          )

        item.ecs.removeEntity(item.entity)

    sys [Position, Velocity], "logicSystems":
      proc positionVelocitySystem(item: Item) =
        position += velocity

    sys [vel: Velocity], "logicSystems":
      proc velocitySystem(item: Item) =
        vel *= 0.97

    sys [Snake], "logicSystems":
      proc isMoveSystem(item: Item, game: Game) =
        if card({ikMoveUp, ikMoveDown, ikMoveLeft, ikMoveRight} * game.input) != 0:
          item.addIsMove(true)

    sys [nextPos: NextGridPosition, NextDirection, NextSnake, IsMove], "logicSystems":
      proc setNextDirectionSystem(item: Item, game: Game) =
        nextDirection = (item.ecs, nextSnake).direction
        nextPos = (item.ecs, nextSnake).gridPosition

    sys [pos: GridPosition, Direction, Player, IsMove, tail: TailReference], "logicSystems":
      proc playerMoveSystem(item: Item, game: Game) =
        var delta = vec2(0, 0)

        if ikMoveUp in game.input: delta.y -= 1
        if ikMoveDown in game.input: delta.y += 1
        if ikMoveLeft in game.input: delta.x -= 1
        if ikMoveRight in game.input: delta.x += 1

        pos += delta

        var newDirection: Direction
        if delta.x > 0: newDirection = dRight
        elif delta.x < 0: newDirection = dLeft
        elif delta.y > 0: newDirection = dDown
        elif delta.y < 0: newDirection = dUp

        direction = newDirection

        for apple in item.ecs.queryAll({ckApple, ckGridPosition}):
          if manhattanDistance((item.ecs, apple).gridPosition, pos) <= 2:
            (item.ecs, tail).addDidGrow(true)
            discard item.ecs.createEntity("Explosion"): (
              [Explosion]20,
              [Position]vec2(pos.x.toFloat(), pos.y.toFloat()) * gridSizeFloat
            )

            item.ecs.removeEntity(apple)

            discard item.ecs.createEntity("Apple"): (
              [Apple]true,
              [GridPosition]vec2(rand(0 .. 50), rand(0 .. 50))
            )

            break

    sys [pos: GridPosition, Direction, Tail, DidGrow, head: HeadReference], "logicSystems":
      proc createNewTailSystem(item: Item) =
        let newTail = item.ecs.createEntity("Body"): (
          [Snake]rand(0 .. 10),
          [Tail]true,
          [NextSnake]item.entity,
          [HeadReference]head,
          [Direction]direction,
          [NextDirection]dNone,
          [GridPosition]pos,
          [NextGridPosition]pos
        )

        item.ecs.tailReferenceContainer[head.idx] = newTail

        item.removeTail()
        item.removeHeadReference()

    sys [pos: GridPosition, nextPos: NextGridPosition, Direction, NextDirection, IsMove], "logicSystems":
      proc snakeBodyMoveSystem(item: Item) =
        direction = nextDirection
        pos = nextPos

    sys [pos: GridPosition, IsMove], "logicSystems":
      proc wrapSystem(item: Item) =
        if pos.x < 0:
          pos.x = 50
        if pos.x > 50:
          pos.x = 0

        if pos.y < 0:
          pos.y = 50
        if pos.y > 50: pos.y = 0

    sys [IsMove], "logicSystems":
      proc removeIsMoveSystem(item: Item) = item.removeIsMove()

    sys [Particle, Velocity], "logicSystems":
      proc removeParticleSystem(item: Item) =
        if length(velocity) <= 0.3:
          item.ecs.removeEntity(item.entity)

  # === Rendering Systems ===
  when true:
    sys [pos: GridPosition, Snake], "renderingSystems":
      proc bodyRenderingSystem(item: Item, game: Game) =
        var canvas = game.graphics

        let
          x = (pos.x * gridSize).toFloat()
          y = (pos.y * gridSize).toFloat()
          w = gridSizeFloat
          n1 = snake.toFloat()/10.0
          n2 = 1.0 - n1

        canvas.rectangle(x, y, w, w, rgba(n1, n1, n2, 1))

    sys [pos: Position, Particle], "renderingSystems":
      proc renderParticleSystem(item: Item, game: Game) =
        game.graphics.circle(pos.x, pos.y, 3.0, particle, 6)

    sys [pos: GridPosition, Apple], "renderingSystems":
      proc appleRenderingSystem(item: Item, game: Game) =
        var canvas = game.graphics

        let
          x = (pos.x * gridSize).toFloat()
          y = (pos.y * gridSize).toFloat()
          w = gridSizeFloat

        canvas.circle(x, y, w, rgba(1, 0, 0, 0.4), 16)

    sys [pos: GridPosition, Player], "renderingSystems":
      proc playerRenderingSystem(item: Item, game: Game) =
        var canvas = game.graphics

        let
          x = (pos.x * gridSize).toFloat()
          y = (pos.y * gridSize).toFloat()

        canvas.circle(x + gridSizeFloat/2.0, y + gridSizeFloat/2.0, 10, rgba(1, 1, 0, 1))

createECS(ECSConfig(maxEntities: 15000))


proc createPlayer(ecs: var ECS): Entity =
  let origin = vec2(10, 10)

  let player = ecs.createEntity("Player [Head]"): (
    [Player]true,
    [Snake]rand(0 .. 10),
    [Direction]dUp,
    [GridPosition]origin + vec2(0, 0)
  )

  let body = ecs.createEntity("Body"): (
    [Snake]rand(0 .. 10),
    [NextSnake]player,
    [Direction]dDown,
    [NextDirection]dUp,
    [GridPosition]origin + vec2(0, -1),
    [NextGridPosition]vec2(0, 0)
  )

  let tail = ecs.createEntity("Body"): (
    [Snake]rand(0 .. 10),
    [Tail]true,
    [NextSnake]body,
    [HeadReference]player,
    [Direction]dDown,
    [NextDirection]dDown,
    [GridPosition]origin + vec2(0, -2),
    [NextGridPosition]vec2(0, 0)
  )

  (ecs, player).addTailReference(tail)

  return player


proc main() =
  var agl = initAglet()
  agl.initWindow()

  let
    window = agl.newWindowGlfw(800, 600, "rapid/gfx", winHints(msaaSamples = 8))
    graphics = window.newGraphics()

  const bg = rgba(0.125, 0.125, 0.125, 1.0)

  var
    game = Game(graphics: graphics)
    world = newECS()


  discard world.createPlayer()
  discard world.createEntity("Applce"): (
    [Apple]true,
    [GridPosition]vec2(20, 20),
  )

  while not window.closeRequested:
    window.pollEvents do (event: InputEvent):
      case event.kind
      of iekWindowFrameResize:
        # echo event.size
        discard

      of iekKeyPress:
        case event.key
        of Key.keyEsc: window.requestClose()

        of keyUp, Key.keyW:
          game.input.incl(ikMoveUp)
        of keyDown, Key.keyS:
          game.input.incl(ikMoveDown)
        of keyLeft, Key.keyA:
          game.input.incl(ikMoveLeft)
        of keyRight, Key.keyD:
          game.input.incl(ikMoveRight)
        else: discard

      of iekKeyRelease:
        case event.key
        of keyUp, Key.keyW:
          game.input.excl(ikMoveUp)
        of keyDown, Key.keyS:
          game.input.excl(ikMoveDown)
        of keyLeft, Key.keyA:
          game.input.excl(ikMoveLeft)
        of keyRight, Key.keyD:
          game.input.excl(ikMoveRight)
        else: discard

      else: discard

    world.runLogicSystems(game)

    var frame = window.render()
    frame.clearColor(bg)

    graphics.resetShape()
    world.runRenderingSystems(game)

    graphics.draw(frame)
    frame.finish()


when isMainModule:
  main()
