# Package

version       = "1.0.0"
author        = "ErikWDev"
description   = "An easy to use ECS.. Easyess!"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.8"


task tests, "run all tests":
  exec "nimble test -d:danger"
  exec "nimble test -d:ecsSecTables -d:danger"
  
  exec "nimble test"
  exec "nimble test -d:ecsSecTables"
