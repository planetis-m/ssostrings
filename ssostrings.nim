when cpuEndian == littleEndian:
  const
    strLongFlag = 1
else:
  const
    strLongFlag = low(int)

type
  StrPayload = object
    data: UncheckedArray[char]

  LongString = object
    cap, len: int
    p: ptr StrPayload

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

type
  String* {.union.} = object
    long: LongString
    short: ShortString

template isLong(s): bool = (s.short.len and strLongFlag) == strLongFlag

template data(s): untyped =
  if isLong(s): addr s.long.p.data
  else: cast[ptr UncheckedArray[char]](addr s.short.data)

template shortLen(s): int =
  when cpuEndian == littleEndian:
    s.short.len shr 1
  else:
    s.short.len

template shortSetLen(s, length) =
  when cpuEndian == littleEndian:
    s.short.len = length.int8 shl 1
  else:
    s.short.len = length.int8

template longCap(s): int =
  when cpuEndian == littleEndian:
    s.long.cap shr 1
  else:
    s.long.cap and not strLongFlag

template longSetCap(s, capacity) =
  when cpuEndian == littleEndian:
    s.long.cap = capacity shl 1 or strLongFlag
  else:
    s.long.cap = capacity or strLongFlag

proc `=destroy`*(x: var String) =
  frees(x)

proc `=copy`*(a: var String, b: String) =
  if isLong(a):
    if isLong(b) and a.long.p == b.long.p: return
    `=destroy`(a)
    wasMoved(a)
  if isLong(b):
    when compileOption("threads"):
      a.long.p = cast[ptr StrPayload](allocShared(contentSize(b.long.len)))
    else:
      a.long.p = cast[ptr StrPayload](alloc(contentSize(b.long.len)))
    a.long.len = b.long.len
    a.longSetCap b.long.len
    copyMem(addr a.long.p.data[0], addr b.long.p.data[0], contentSize(a.long.len))
  else:
    copyMem(addr a, addr b, sizeof(String))

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old < 65536: result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

proc len*(s: String): int {.inline.} =
  if s.isLong: s.long.len else: s.shortLen

proc prepareAdd(s: var String; addLen: int) =
  let newLen = s.len + addLen
  if isLong(s):
    let oldCap = s.longCap
    if newLen > oldCap:
      let newCap = max(newLen, resize(oldCap))
      when compileOption("threads"):
        s.long.p = cast[ptr StrPayload](reallocShared0(s.long.p, contentSize(oldCap), contentSize(newCap)))
      else:
        s.long.p = cast[ptr StrPayload](realloc0(s.long.p, contentSize(oldCap), contentSize(newCap)))
      s.longSetCap newCap
  elif newLen > strMinCap:
    when compileOption("threads"):
      let p = cast[ptr StrPayload](allocShared0(contentSize(newLen)))
    else:
      let p = cast[ptr StrPayload](alloc0(contentSize(newLen)))
    let oldLen = s.shortLen
    if oldLen > 0:
      # we are about to append, so there is no need to copy the \0 terminator:
      copyMem(addr p.data[0], addr s.short.data[0], min(oldLen, newLen))
    s.long.len = oldLen
    s.long.p = p
    s.longSetCap newLen

proc add*(s: var String; c: char) {.inline.} =
  prepareAdd(s, 1)
  let len = s.len
  s.data[len] = c
  s.data[len+1] = '\0'
  if isLong(s):
    inc s.long.len
  else:
    s.shortSetLen len+1

proc add*(dest: var String; src: String) {.inline.} =
  let srcLen = src.len
  if srcLen > 0:
    prepareAdd(dest, srcLen)
    let destLen = dest.len
    # also copy the \0 terminator:
    copyMem(addr dest.data[destLen], addr src.data[0], srcLen+1)
    if isLong(dest):
      inc dest.long.len, srcLen
    else:
      dest.shortSetLen destLen+srcLen

proc cstrToStr(str: cstring, len: int): String =
  if len <= 0:
    result = String()
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr StrPayload](allocShared(contentSize(len)))
      else:
        let p = cast[ptr StrPayload](alloc(contentSize(len)))
      result = String(long: LongString(len: len, p: p))
      result.longSetCap len
    else:
      result = String()
      result.shortSetLen len
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
    result = String()
  else:
    if space > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr StrPayload](allocShared0(contentSize(space)))
      else:
        let p = cast[ptr StrPayload](alloc0(contentSize(space)))
      result = String(long: LongString(len: 0, p: p))
      result.longSetCap space
    else:
      result = String()

proc initString*(len: Natural): String =
  if len <= 0:
    result = String()
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr StrPayload](allocShared0(contentSize(len)))
      else:
        let p = cast[ptr StrPayload](alloc0(contentSize(len)))
      result = String(long: LongString(len: len, p: p))
      result.longSetCap len
    else:
      result = String()
      result.shortSetLen len

proc setLen*(s: var String, newLen: Natural) =
  if newLen == 0:
    discard "do not free the buffer here, pattern 's.setLen 0' is common for avoiding allocations"
  else:
    if newLen > s.len:
      prepareAdd(s, newLen - s.len)
    s.data[newLen] = '\0'
  if isLong(s):
    s.long.len = newLen
  else:
    s.shortSetLen newLen

# Comparisons
proc eqStrings*(a, b: String): bool =
  result = false
  if a.len == b.len:
    if a.len == 0: result = true
    else: result = equalMem(addr a.data[0], addr b.data[0], a.len)

proc `==`*(a, b: String): bool {.inline.} = eqStrings(a, b)

proc cmpStrings*(a, b: String): int =
  let minLen = min(a.len, b.len)
  if minLen > 0:
    result = cmpMem(addr a.data[0], addr b.data[0], minLen)
    if result == 0:
      result = a.len - b.len
  else:
    result = a.len - b.len

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
  checkBounds(i, x.len)
  x.data[i]

proc `[]`*(x: var String; i: int): var char {.inline.} =
  checkBounds(i, x.len)
  x.data[i]

proc `[]=`*(x: var String; i: int; val: char) {.inline.} =
  checkBounds(i, x.len)
  x.data[i] = val
