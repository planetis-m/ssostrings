import std/isolation

const
  strShift = sizeof(int) * 8 - 8

when cpuEndian == littleEndian:
  const
    strLongFlag = 1
else:
  const
    strLongFlag = low(int8)

type
  LongString = object
    cap, len: int
    p: ptr UncheckedArray[char]

template contentSize(cap): int = cap + 1

template frees(s) =
  if isLong(s) and s.long.p != nil:
    when compileOption("threads"):
      deallocShared(s.long.p)
    else:
      dealloc(s.long.p)

const
  strMinCap = max(2, sizeof(LongString) - 1) - 1

type
  ShortString = object
    len: int8
    data: array[strMinCap + 1, char]

#static: assert sizeof(ShortString) == sizeof(String)

type
  String* {.union.} = object
    long: LongString
    short: ShortString

template isLong(s): bool = (s.short.len and strLongFlag) == strLongFlag

template shortLen(s): int =
  when cpuEndian == littleEndian:
    s.short.len shr 1
  else:
    s.short.len

template shortSetLen(s, length) =
  when cpuEndian == littleEndian:
    s.short.len = length shl 1
  else:
    s.short.len = length

template longCap(s): int =
  when cpuEndian == littleEndian:
    s.long.cap shr 1
  else:
    s.long.cap and not (strLongFlag shl strShift)

template longSetCap(s, capacity) =
  when cpuEndian == littleEndian:
    s.long.cap = capacity shl 1 or strLongFlag
  else:
    s.long.cap = capacity or (strLongFlag shl strShift)

proc `=destroy`*(x: var String) =
  frees(x)

proc `=copy`*(a: var String, b: String) =
  if isLong(a):
    if isLong(b) and a.long.p == b.long.p: return
    `=destroy`(a)
    wasMoved(a)
  if isLong(b):
    when compileOption("threads"):
      a.long.p = cast[typeof(a.long.p)](allocShared(contentSize(b.long.len)))
    else:
      a.long.p = cast[typeof(a.long.p)](alloc(contentSize(b.long.len)))
    a.long.len = b.long.len
    longSetCap(a, b.long.len)
    copyMem(a.long.p, b.long.p, contentSize(a.long.len))
  else:
    copyMem(addr a, addr b, sizeof(String))

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old < 65536: result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

proc len*(s: String): int {.inline.} =
  if s.isLong: s.long.len else: s.shortLen

#proc prepareAdd(s: var String; addLen: int) =
  #let newLen = s.len + addLen

proc toCStr*(s: String): cstring {.inline.} =
  if s.isLong: result = cstring(s.long.p)
  else: result = cstring(addr s.short.data)

var
  s: String

longSetCap(s, 127)
echo s.isLong
echo s.short.data
echo s.shortLen
echo s.short.len
