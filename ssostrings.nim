when cpuEndian == littleEndian:
  const
    strLongFlag = 1
else:
  const
    strLongFlag = low(int)

type
  StrPayload = UncheckedArray[char]

  String* = object # LongString
    cap, len: int
    p: ptr StrPayload

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

template data(s): untyped =
  if isLong(s): s.p else: cast[ptr StrPayload](addr s.short.data)

template shortLen(s): int =
  when cpuEndian == littleEndian:
    s.short.len shr 1
  else:
    s.short.len

template setShortLen(s, length) =
  when cpuEndian == littleEndian:
    s.short.len = length.int8 shl 1
  else:
    s.short.len = length.int8

template longCap(s): int =
  when cpuEndian == littleEndian:
    s.cap shr 1
  else:
    s.cap and not strLongFlag

template setLongCap(s, capacity) =
  when cpuEndian == littleEndian:
    s.cap = capacity shl 1 or strLongFlag
  else:
    s.cap = capacity or strLongFlag

proc `=destroy`*(x: var String) =
  frees(x)

proc `=copy`*(a: var String, b: String) =
  if isLong(a):
    if isLong(b) and a.p == b.p: return
    `=destroy`(a)
    wasMoved(a)
  if isLong(b):
    when compileOption("threads"):
      a.p = cast[ptr StrPayload](allocShared(contentSize(b.len)))
    else:
      a.p = cast[ptr StrPayload](alloc(contentSize(b.len)))
    a.len = b.len
    a.setLongCap b.len
    copyMem(a.p, b.p, contentSize(a.len))
  else:
    copyMem(addr a, addr b, sizeof(String))

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old < 65536: result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

proc len*(s: String): int {.inline.} =
  if s.isLong: s.len else: s.shortLen

proc prepareAdd(s: var String; addLen: int) =
  let newLen = len(s) + addLen
  if isLong(s):
    let oldCap = s.longCap
    if newLen > oldCap:
      let newCap = max(newLen, resize(oldCap))
      when compileOption("threads"):
        s.p = cast[ptr StrPayload](reallocShared0(s.p, contentSize(oldCap), contentSize(newCap)))
      else:
        s.p = cast[ptr StrPayload](realloc0(s.p, contentSize(oldCap), contentSize(newCap)))
      s.setLongCap newCap
  elif newLen > strMinCap:
    when compileOption("threads"):
      let p = cast[ptr StrPayload](allocShared0(contentSize(newLen)))
    else:
      let p = cast[ptr StrPayload](alloc0(contentSize(newLen)))
    let oldLen = s.shortLen
    if oldLen > 0:
      # we are about to append, so there is no need to copy the \0 terminator:
      copyMem(addr p[0], addr s.short.data[0], min(oldLen, newLen))
    s.len = oldLen
    s.p = p
    s.setLongCap newLen

proc add*(s: var String; c: char) {.inline.} =
  prepareAdd(s, 1)
  let len = len(s)
  s.data[len] = c
  s.data[len+1] = '\0'
  if isLong(s):
    inc s.len
  else:
    s.setShortLen len+1

proc add*(dest: var String; src: String) {.inline.} =
  let srcLen = len(src)
  if srcLen > 0:
    prepareAdd(dest, srcLen)
    let destLen = len(dest)
    # also copy the \0 terminator:
    copyMem(addr dest.data[destLen], addr src.data[0], srcLen+1)
    if isLong(dest):
      inc dest.len, srcLen
    else:
      dest.setShortLen destLen+srcLen

proc cstrToStr(str: cstring, len: int): String =
  if len <= 0:
    result = String(cap: 0, len: 0, p: nil)
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr StrPayload](allocShared(contentSize(len)))
      else:
        let p = cast[ptr StrPayload](alloc(contentSize(len)))
      result.setLongCap len
      result.p = p
      result.len = len
    else:
      result.setShortLen len
    copyMem(addr result.data[0], str, len+1)

proc toStr*(str: cstring): String {.inline.} =
  if str == nil: cstrToStr(str, 0)
  else: cstrToStr(str, str.len)

proc toStr*(str: string): String {.inline.} =
  cstrToStr(str.cstring, str.len)

proc toCStr*(s: String): cstring {.inline.} =
  result = cstring(s.data)

proc initStringOfCap*(space: Natural): String =
  # this is also 'system.newStringOfCap'.
  if space <= 0:
    result = String(cap: 0, len: 0, p: nil)
  else:
    if space > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr StrPayload](allocShared0(contentSize(space)))
      else:
        let p = cast[ptr StrPayload](alloc0(contentSize(space)))
      result.setLongCap space
      result.p = p

proc initString*(len: Natural): String =
  if len <= 0:
    result = String(cap: 0, len: 0, p: nil)
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr StrPayload](allocShared0(contentSize(len)))
      else:
        let p = cast[ptr StrPayload](alloc0(contentSize(len)))
      result.setLongCap len
      result.p = p
      result.len = len
    else:
      result.setShortLen len

proc setLen*(s: var String, newLen: Natural) =
  if newLen == 0:
    discard "do not free the buffer here, pattern 's.setLen 0' is common for avoiding allocations"
  else:
    let oldLen = len(s)
    if newLen > oldLen:
      prepareAdd(s, newLen - oldLen)
    s.data[newLen] = '\0'
  if isLong(s):
    s.len = newLen
  else:
    s.setShortLen newLen

# Comparisons
proc eqStrings*(a, b: String): bool =
  result = false
  if len(a) == len(b):
    if len(a) == 0: result = true
    else: result = equalMem(addr a.data[0], addr b.data[0], len(a))

proc `==`*(a, b: String): bool {.inline.} = eqStrings(a, b)

proc cmpStrings*(a, b: String): int =
  let minLen = min(len(a), len(b))
  if minLen > 0:
    result = cmpMem(addr a.data[0], addr b.data[0], minLen)
    if result == 0:
      result = len(a) - len(b)
  else:
    result = len(a) - len(b)

proc `<=`*(a, b: String): bool {.inline.} = cmpStrings(a, b) <= 0
proc `<`*(a, b: String): bool {.inline.} = cmpStrings(a, b) < 0

proc raiseIndexDefect(i, n: int) {.noinline, noreturn.} =
  raise newException(IndexDefect, "index " & $i & " not in 0 .. " & $n)

template checkBounds(i, n) =
  when compileOption("boundChecks"):
    {.line.}:
      if i < 0 or i >= n:
        raiseIndexDefect(i, n-1)

proc `[]`*(x: String; i: int): char {.inline.} =
  checkBounds(i, len(x))
  x.data[i]

proc `[]`*(x: var String; i: int): var char {.inline.} =
  checkBounds(i, len(x))
  x.data[i]

proc `[]=`*(x: var String; i: int; val: char) {.inline.} =
  checkBounds(i, len(x))
  x.data[i] = val
