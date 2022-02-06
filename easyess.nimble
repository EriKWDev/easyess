# Package
version       = "0.1.0"
author        = "ErikWDev Ubuntu"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"

# Tasks
task docgen, "Generate docs":
  exec "nim doc2 --index:on -d:nimdoc --outdir:docs src/easyess.nim "

# Dependencies
requires "nim >= 1.4.8"
