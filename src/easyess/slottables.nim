

#[
Taken from https://github.com/planetis-m/goodluck/blob/main/project2d/slottables.nim
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


when defined(ecsSmallSlots):
  type SlotImpl* = uint16
else:
  type SlotImpl* = uint32

type
  Slot* = distinct SlotImpl

const
  versionBits = 3

  versionMask {.used.} = 1 shl versionBits - 1
  indexBits = sizeof(Slot) * 8 - versionBits

  indexMask = 1 shl indexBits - 1
  invalidId* = Slot(indexMask) # a sentinel value to represent an invalid slot
  maxSlots* = indexMask

template idx*(e: Slot): int = e.int and indexMask
template version*(e: Slot): SlotImpl = e.SlotImpl shr indexBits
template toSlot*(idx, v: SlotImpl): Slot = Slot(v shl indexBits or idx)

proc `==`*(a, b: Slot): bool {.borrow.}

type
  Entry*[T] = tuple
    s: Slot
    value: T

  SlotTable*[T] = object
    freeHead: int
    slots: seq[Slot]
    data: seq[Entry[T]]

proc initSlotTableOfCap*[T](capacity: Natural): SlotTable[T] =
  result = SlotTable[T](
    data: newSeqOfCap[Entry[T]](capacity),
    slots: newSeqOfCap[Slot](capacity),
    freeHead: 0
  )

func len*[T](x: SlotTable[T]): int {.inline.} =
  x.data.len

func contains*[T](x: SlotTable[T], e: Slot): bool {.inline.} =
  e.idx < x.slots.len and x.slots[e.idx].version == e.version

proc raiseRangeDefect() {.noinline, noreturn.} =
  raise newException(RangeDefect, "SlotTable number of elements overflow")

proc incl*[T](x: var SlotTable[T], value: T): Slot =
  when compileOption("boundChecks"):
    if x.len + 1 == maxSlots:
      raiseRangeDefect()
  let idx = x.freeHead
  if idx < x.slots.len:
    template slot: untyped = x.slots[idx]

    let occupiedVersion = slot.version or 1
    result = toSlot(idx.SlotImpl, occupiedVersion)
    x.data.add((s: result, value: value))
    x.freeHead = slot.idx
    slot = toSlot(x.data.high.SlotImpl, occupiedVersion)
  else:
    result = toSlot(idx.SlotImpl, 1)
    x.data.add((s: result, value: value))
    x.slots.add(toSlot(x.data.high.SlotImpl, 1))
    x.freeHead = x.slots.len

proc freeSlot[T](x: var SlotTable[T], slotIdx: int): int {.inline.} =
  # Helper function to add a slot to the freelist. Returns the index that
  # was stored in the slot.
  template slot: untyped = x.slots[slotIdx]
  result = slot.idx
  slot = toSlot(x.freeHead.SlotImpl, slot.version + 1)
  x.freeHead = slotIdx

proc delFromSlot[T](x: var SlotTable[T], slotIdx: int) {.inline.} =
  # Helper function to remove a value from a slot and make the slot free.
  # Returns the value deld.
  let valueIdx = x.freeSlot(slotIdx)
  # Remove values/slot_indices by swapping to end.
  x.data[valueIdx] = move(x.data[x.data.high])
  x.data.setLen(x.data.high)
  # Did something take our place? Update its slot to new position.
  if x.data.len > valueIdx:
    let kIdx = x.data[valueIdx].s.idx
    template slot: untyped = x.slots[kIdx]
    slot = toSlot(valueIdx.SlotImpl, slot.version)

proc del*[T](x: var SlotTable[T], e: Slot) =
  if x.contains(e):
    x.delFromSlot(e.idx)

proc clear*[T](x: var SlotTable[T]) =
  x.freeHead = 0
  x.slots.setLen(0)
  x.data.setLen(0)

template get(x, e) =
  template slot: Slot = x.slots[e.idx]
  if e.idx >= x.slots.len or slot.version != e.version:
    raise newException(KeyError, "Slot not in SlotTable")
  # This is safe because we only store valid indices.
  let idx = slot.idx
  result = x.data[idx].value

func `[]`*[T](x: SlotTable[T], e: Slot): T =
  get(x, e)

func `[]`*[T](x: var SlotTable[T], e: Slot): var T =
  get(x, e)

iterator pairs*[T](x: SlotTable[T]): Entry[T] =
  for i in 0 ..< x.len:
    yield x.data[i]
