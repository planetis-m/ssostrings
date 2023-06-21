when defined(nimPreviewSlimSystem):
  import std/assertions

when cpuEndian == littleEndian:
  const
    strLongFlag = 1
else:
  const
    strLongFlag = low(int)

type
  String* = object # LongString
    cap, len: int
    p: ptr UncheckedArray[char]

template contentSize(cap): int = cap + 1
template isLong(s): bool = (s.cap and strLongFlag) == strLongFlag

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
template short(s: String): untyped = cast[ptr ShortString](addr s)

template data(s: String): untyped =
  if isLong(s): s.p else: cast[ptr UncheckedArray[char]](addr s.short.data[0])

template shortLen(s): int =
  when cpuEndian == littleEndian:
    s.short.len shr 1
  else:
    s.short.len

template setShortLen(s, n) =
  when cpuEndian == littleEndian:
    s.short.len = int8(n) shl 1
  else:
    s.short.len = int8(n)

template longCap(s): int =
  when cpuEndian == littleEndian:
    int(uint(s.cap) shr 1)
  else:
    s.cap and not strLongFlag

template setLongCap(s, n) =
  when cpuEndian == littleEndian:
    s.cap = n shl 1 or strLongFlag
  else:
    s.cap = n or strLongFlag

proc `=destroy`*(x: String) =
  frees(x)

template dups(a, b) =
  if isLong(b):
    when compileOption("threads"):
      a.p = cast[ptr UncheckedArray[char]](allocShared(contentSize(b.len)))
    else:
      a.p = cast[ptr UncheckedArray[char]](alloc(contentSize(b.len)))
    a.len = b.len
    a.setLongCap b.len
    copyMem(a.p, b.p, contentSize(a.len))
  else:
    copyMem(addr a, addr b, sizeof(String))

proc `=dup`*(b: String): String =
  dups(result, b)

proc `=copy`*(a: var String, b: String) =
  if isLong(a):
    if isLong(b) and a.p == b.p: return
    `=destroy`(a)
    wasMoved(a)
  dups(a, b)

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old <= high(int16): result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

proc len*(s: String): int {.inline.} =
  if isLong(s): s.len else: s.shortLen

proc high*(s: String): int {.inline.} = len(s)-1
proc low*(s: String): int {.inline.} = 0

proc prepareAdd(s: var String; addLen: int) =
  let newLen = len(s) + addLen
  if isLong(s):
    let oldCap = s.longCap
    if newLen > oldCap:
      let newCap = max(newLen, resize(oldCap))
      when compileOption("threads"):
        s.p = cast[ptr UncheckedArray[char]](
            reallocShared0(s.p, contentSize(oldCap), contentSize(newCap)))
      else:
        s.p = cast[ptr UncheckedArray[char]](
            realloc0(s.p, contentSize(oldCap), contentSize(newCap)))
      s.setLongCap newCap
  elif newLen > strMinCap:
    when compileOption("threads"):
      let p = cast[ptr UncheckedArray[char]](allocShared0(contentSize(newLen)))
    else:
      let p = cast[ptr UncheckedArray[char]](alloc0(contentSize(newLen)))
    let oldLen = s.shortLen
    if oldLen > 0:
      # we are about to append, so there is no need to copy the \0 terminator:
      copyMem(p, addr s.short.data[0], min(oldLen, newLen))
    s.len = oldLen
    s.p = p
    s.setLongCap newLen

proc add*(s: var String; c: char) {.inline.} =
  let len = len(s)
  prepareAdd(s, 1)
  s.data[len] = c
  s.data[len+1] = '\0'
  if isLong(s):
    inc s.len
  else:
    s.setShortLen len+1

proc add*(dest: var String; src: String) {.inline.} =
  let srcLen = len(src)
  if srcLen > 0:
    let destLen = len(dest)
    prepareAdd(dest, srcLen)
    # also copy the \0 terminator:
    copyMem(addr dest.data[destLen], src.data, srcLen+1)
    if isLong(dest):
      inc dest.len, srcLen
    else:
      dest.setShortLen destLen+srcLen

proc cstrToStr(str: cstring, len: int): String =
  if len <= 0:
    result = default(String)
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr UncheckedArray[char]](allocShared(contentSize(len)))
      else:
        let p = cast[ptr UncheckedArray[char]](alloc(contentSize(len)))
      result = String(p: p, len: len)
      result.setLongCap len
    else:
      result = default(String)
      result.setShortLen len
    copyMem(result.data, str, len+1)

proc toStr*(str: cstring): String {.inline.} =
  if str == nil: cstrToStr(str, 0)
  else: cstrToStr(str, str.len)

proc toStr*(str: string): String {.inline.} =
  cstrToStr(str.cstring, str.len)

proc toCStr*(s: ptr String): cstring {.inline.} =
  result = cast[cstring](s[].data)

template toCStr*(s: String): cstring = toCStr(addr s)

proc initStringOfCap*(space: Natural): String =
  # this is also 'system.newStringOfCap'.
  if space <= 0:
    result = default(String)
  else:
    if space > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr UncheckedArray[char]](allocShared0(contentSize(space)))
      else:
        let p = cast[ptr UncheckedArray[char]](alloc0(contentSize(space)))
      result = String(p: p)
      result.setLongCap space
    else:
      result = default(String)

proc initString*(len: Natural): String =
  if len <= 0:
    result = default(String)
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr UncheckedArray[char]](allocShared0(contentSize(len)))
      else:
        let p = cast[ptr UncheckedArray[char]](alloc0(contentSize(len)))
      result = String(p: p, len: len)
      result.setLongCap len
    else:
      result = default(String)
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
  let aLen = len(a)
  if aLen != len(b):
    result = false
  else: result = equalMem(a.data, b.data, aLen)

proc `==`*(a, b: String): bool {.inline.} = eqStrings(a, b)

proc cmpStrings*(a, b: String): int =
  let aLen = len(a)
  let bLen = len(b)
  result = cmpMem(a.data, b.data, min(aLen, bLen))
  if result == 0:
    if aLen < bLen:
      result = -1
    elif aLen > bLen:
      result = 1

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

iterator items*(a: String): char {.inline.} =
  var i = 0
  let L = len(a)
  while i < L:
    yield a[i]
    inc(i)
    assert(len(a) == L, "the length of the string changed while iterating over it")

iterator mitems*(a: var String): var char {.inline.} =
  var i = 0
  let L = len(a)
  while i < L:
    yield a[i]
    inc(i)
    assert(len(a) == L, "the length of the string changed while iterating over it")

template toOpenArray*(s: String; first, last: int): untyped =
  toOpenArray(toCStr(addr s), first, last)

template toOpenArray*(s: String): untyped =
  toOpenArray(toCStr(addr s), 0, s.high)
