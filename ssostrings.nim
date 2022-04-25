import std/isolation

const
  strShift = sizeof(int) * 8 - 8
  strLongFlag = low(int)

type
  String* = object # LongString
    cap, len: int
    p: ptr UncheckedArray[char] # can be nil if len == 0.

template contentSize(cap): int = cap + 1

template isLong(s): bool = (s.cap and strLongFlag) == strLongFlag

template frees(s) =
  if s.p != nil and isLong(s):
    when compileOption("threads"):
      deallocShared(s.p)
    else:
      dealloc(s.p)

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old < 65536: result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

const
  strMinCap = max(2, sizeof(String) - 1) - 1

type
  ShortString = object
    len: int8
    data: array[strMinCap + 1, char]

static: assert sizeof(ShortString) == sizeof(String)
template short(s): untyped = cast[ptr ShortString](addr s)[]

proc `=destroy`*(x: var String) =
  frees(x)

template `+!`(p: pointer, s: int): pointer =
  cast[pointer](cast[int](p) +% s)

proc `=copy`*(a: var String, b: String) =
  if isLong(b):
    if a.p != b.p:
      `=destroy`(a)
      wasMoved(a)
    when compileOption("threads"):
      a.p = cast[typeof(a.p)](allocShared(contentSize(b.len)))
    else:
      a.p = cast[typeof(a.p)](alloc(contentSize(b.len)))
    a.len = b.len
    a.cap = a.len or strLongFlag
    copyMem(a.p, b.p, contentSize(a.len))
  else:
    let newLen = b.short.len
    if isLong(a):
      `=destroy`(a)
      wasMoved(a)
    if newLen > 0:
      copyMem(addr a, addr b, newLen)
      a.short.len = newLen
    zeroMem(addr a +! newLen, sizeof(String))

proc len*(s: String): int {.inline.} =
  if s.isLong: s.len else: s.short.len

var
  s: String

s.short.len = 1
echo s.isLong
echo s.cap
echo s.short.len

proc toCStr*(s: String): cstring {.inline.} =
  if s.isLong: result = cstring(addr s.p)
  else: result = cstring(addr s.short.data)



