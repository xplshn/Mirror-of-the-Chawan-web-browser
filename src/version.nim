{.used.}

import std/macros

template imp(x: untyped) = import x

macro tryImport(x: untyped, name: static string) =
  let vs = ident(name & "Version")
  quote do:
    when not compiles(imp `x`):
      static:
        error("Cannot find submodule " & `name` &
          ". Please run `make submodule` to fetch the required submodules.")
    import `x` as `vs`

macro checkVersion(xs: static string, major, minor, patch: int) =
  let x = ident(xs & "Version")
  quote do:
    when `x`.Major < `major` or `x`.Minor < `minor` or `x`.Patch < `patch`:
      var es = $`major` & "." & $`minor` & "." & $`patch`
      var gs = $`x`.Major & "." & $`x`.Minor & "." & $`x`.Patch
      error("Version of " & `xs` & " too low (expected " & es & ", got " &
        gs & "). Please run `make submodule` to update.")

tryImport chagashi/version, "chagashi"
tryImport chame/version, "chame"

static:
  checkVersion("chagashi", 0, 4, 2)
  checkVersion("chame", 0, 14, 5)
