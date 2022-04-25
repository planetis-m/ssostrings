import std/isolation

const
  strShift = sizeof(int) * 8 - 8

when cpuEndian == littleEndian:
  const
    strLongFlag = 0x01
else:
  const
    strLongFlag = 0xF0

type
  String* = object # LongString
    cap, len: int
    p: ptr UncheckedArray[char]

template contentSize(cap): int = cap + 1

template frees(s) =
  if isLong(s) and s.p != nil:
    when compileOption("threads"):
      deallocShared(s.p)
    else:
      dealloc(s.p)

const
  strMinCap = max(2, sizeof(String) - 1) - 1

type
  ShortString = object
    len: int8
    data: array[strMinCap + 1, char]

static: assert sizeof(ShortString) == sizeof(String)
template short(s): untyped = cast[ptr ShortString](addr s)[]

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
    s.cap shr 1
  else:
    s.cap and not (strLongFlag shl strShift)

template longSetCap(s, capacity) =
  when cpuEndian == littleEndian:
    s.cap = capacity shl 1
  else:
    s.cap = capacity
  s.short.len = s.short.len or strLongFlag

proc `=destroy`*(x: var String) =
  frees(x)

proc `=copy`*(a: var String, b: String) =
  if isLong(a):
    if isLong(b) and a.p == b.p: return
    `=destroy`(a)
    wasMoved(a)
  if isLong(b):
    when compileOption("threads"):
      a.p = cast[typeof(a.p)](allocShared(contentSize(b.len)))
    else:
      a.p = cast[typeof(a.p)](alloc(contentSize(b.len)))
    a.len = b.len
    longSetCap(a, b.len)
    copyMem(a.p, b.p, contentSize(a.len))
  else:
    short(a) = b.short

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old < 65536: result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

#proc prepareAdd(s: var String; addLen: int) =
  #let newLen = s.len + addLen

proc len*(s: String): int {.inline.} =
  if s.isLong: s.len else: s.shortLen

proc toCStr*(s: String): cstring {.inline.} =
  if s.isLong: result = cstring(s.p)
  else: result = cstring(addr s.short.data)

var
  s: String

echo s.isLong
#longSetCap(s, 1230)
#shortSetLen(s, 23)
echo s.shortLen
echo s.short.data
