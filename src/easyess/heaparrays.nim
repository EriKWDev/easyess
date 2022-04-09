

#[
Taken from https://github.com/planetis-m/goodluck/blob/main/project2d/heaparrays.nim
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

import slottables
from typetraits import supportsCopyMem

type
  HeapArray*[T] = object
    p: ptr array[maxSlots, T]

proc `=destroy`*[T](x: var HeapArray[T]) =
  if x.p != nil:
    when not supportsCopyMem(T):
      for i in 0..<maxSlots: `=destroy`(x[i])
    when compileOption("threads"):
      deallocShared(x.p)
    else:
      dealloc(x.p)

proc `=copy`*[T](dest: var HeapArray[T], src: HeapArray[T]) {.error.}

proc initHeapArray*[T](): HeapArray[T] =
  when not supportsCopyMem(T):
    when compileOption("threads"):
      result.p = cast[typeof(result.p)](allocShared0(maxSlots * sizeof(T)))
    else:
      result.p = cast[typeof(result.p)](alloc0(maxSlots * sizeof(T)))
  else:
    when compileOption("threads"):
      result.p = cast[typeof(result.p)](allocShared(maxSlots * sizeof(T)))
    else:
      result.p = cast[typeof(result.p)](alloc(maxSlots * sizeof(T)))

template get(x, i) =
  rangeCheck x.p != nil and i < maxSlots
  x.p[i]

proc `[]`*[T](x: HeapArray[T]; i: Natural): lent T =
  get(x, i)

proc `[]`*[T](x: var HeapArray[T]; i: Natural): var T =
  get(x, i)

proc `[]=`*[T](x: var HeapArray[T]; i: Natural; y: sink T) =
  rangeCheck x.p != nil and i < maxSlots
  x.p[i] = y

proc clear*[T](x: HeapArray[T]) =
  when not supportsCopyMem(T):
    if x.p != nil:
      for i in 0..<maxSlots: reset(x[i])

proc `@`*[T](x: HeapArray[T]): seq[T] {.inline.} =
  newSeq(result, maxSlots)
  for i in 0..<maxSlots: result[i] = x[i]

template toOpenHeapArray*(x: HeapArray, first, last: int): untyped =
  toOpenHeapArray(x.p, first, last)

template toOpenHeapArray*(x: HeapArray): untyped =
  toOpenHeapArray(x.p, 0, maxSlots-1)
