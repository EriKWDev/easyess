# Package

version       = "0.1.0"
author        = "ErikWDev"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["rapid_game"]
binDir        = "bin"

# Dependencies

requires "nim >= 1.6.4"
requires "https://github.com/liquidev/rapid#a50704e542987dc9cb9456e481f8f631e885c56a"

requires "easyess"
