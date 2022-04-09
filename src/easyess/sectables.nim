

#[
Taken from https://github.com/planetis-m/goodluck/blob/main/project2d/sectables.nim
and used under the MIT license. This file has been modified slightly to fit the project
better.

MIT License

Copyright (c) 2019-2020 Contributors to the Goodluck project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]#


from typetraits import supportsCopyMem

const
  growthFactor = 2
  defaultInitialLen = 64

type
  SecTable*[T] = object
    len: int
    p: ptr UncheckedArray[T]

proc `=destroy`*[T](x: var SecTable[T]) =
  if x.p != nil:
    when not supportsCopyMem(T):
      for i in 0..<x.len: `=destroy`(x.p[i])
    when compileOption("threads"):
      deallocShared(x.p)
    else:
      dealloc(x.p)
proc `=copy`*[T](dest: var SecTable[T], src: SecTable[T]) {.error.}

proc newSecTable*[T](len = defaultInitialLen.Natural): SecTable[T] =
  when not supportsCopyMem(T):
    when compileOption("threads"):
      result.p = cast[typeof(result.p)](allocShared0(len * sizeof(T)))
    else:
      result.p = cast[typeof(result.p)](alloc0(len * sizeof(T)))
  else:
    when compileOption("threads"):
      result.p = cast[typeof(result.p)](allocShared(len * sizeof(T)))
    else:
      result.p = cast[typeof(result.p)](alloc(len * sizeof(T)))
  result.len = len

proc grow*[T](s: var SecTable[T], newLen: Natural) =
  if s.p == nil:
    # can't mutate a literal, so we need a fresh copy here:
    when compileOption("threads"):
      s.p = cast[typeof(s.p)](allocShared0(newLen))
    else:
      s.p = cast[typeof(s.p)](alloc0(newLen))
    s.len = newLen
  else:
    if s.len < newLen:
      when not supportsCopyMem(T):
        s.p = cast[typeof(s.p)](reallocShared0(s.p, s.len * sizeof(T), newLen * sizeof(T)))
      else:
        s.p = cast[typeof(s.p)](reallocShared(s.p, newLen * sizeof(T)))
      s.len = newLen

proc mustGrow[T](x: var SecTable[T]; i: int): bool {.inline.} =
  result = x.len - i < 5

proc reserve[T](x: var SecTable[T]; i: int) {.inline.} =
  if mustGrow(x, i): grow(x, x.len * growthFactor)

proc len*[T](s: SecTable[T]): int {.inline.} = s.len

proc `[]`*[T](x: SecTable[T]; i: Natural): lent T =
  rangeCheck x.p != nil and i < x.len
  x.p[i]

proc `[]`*[T](x: var SecTable[T]; i: Natural): var T =
  rangeCheck x.p != nil and i < x.len
  x.p[i]

proc `[]=`*[T](x: var SecTable[T]; i: Natural; y: sink T) =
  reserve(x, i)
  x.p[i] = y

proc clear*[T](x: SecTable[T]) =
  when not supportsCopyMem(T):
    if x.p != nil:
      for i in 0..<x.len: reset(x.p[i])

proc `@`*[T](x: SecTable[T]): seq[T] {.inline.} =
  newSeq(result, x.len)
  for i in 0..x.len-1: result[i] = x[i]

template toOpenArray*(x: SecTable, first, last: int): untyped =
  toOpenArray(x.p, first, last)

template toOpenArray*(x: SecTable): untyped =
  toOpenArray(x.data, 0, x.len-1)
