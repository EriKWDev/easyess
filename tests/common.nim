
const suiteName* = static:
  var
    a = when defined(release): "release" else: "debug"
    b = when defined(ecsSecTables): "SecTables" else: "HeapArrays"

  a & " " & b
