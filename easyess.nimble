# Package
version       = "0.1.1"
author        = "ErikWDev Ubuntu"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"

# Tasks
task docgen, "Generate docs":
  exec "nim doc2 --index:on -d:docgen --docCmd:'-d:docgen' --outdir:htmldocs src/easyess.nim"

import os
task tests, "Run tests using both -d:release and without":
  echo "Running tests in debug mode" 
  exec "nimble test"
  echo "Running tests in release mode"
  exec "nimble -d:danger test"

  echo "Checking all examples"

  for kind, path in walkDir("examples"):
    let (dir, name, ext) = splitFile(path)

    if ext == ".nim":
      exec "nim check " & path


# Dependencies
requires "nim >= 1.6.0"
