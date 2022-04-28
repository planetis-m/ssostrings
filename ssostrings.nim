type
  LongString = object
    isLong {.bitsize: 1.}: uint
    cap {.bitsize: sizeof(int) - 1.}: uint
    len: int
    p: ptr UncheckedArray[char]

template contentSize(cap): int = cap + 1

template frees(s) =
  if isLong(s) and s.long.p != nil:
    when compileOption("threads"):
      deallocShared(s.long.p)
    else:
      dealloc(s.long.p)

const
  strMinCap = 22

type
  ShortString = object
    isLong {.bitsize: 1.}: uint8
    len {.bitsize: 7.}: uint8
    data: array[strMinCap + 1, char]

type
  String* {.union.} = object
    long: LongString
    short: ShortString

template isLong(s): bool = bool(s.long.isLong)

template data(s): untyped =
  if isLong(s): s.long.p else: cast[ptr UncheckedArray[char]](addr s.short.data[0])

proc `=destroy`*(x: var String) =
  frees(x)

proc `=copy`*(a: var String, b: String) =
  if isLong(a):
    if isLong(b) and a.long.p == b.long.p: return
    `=destroy`(a)
    wasMoved(a)
  if isLong(b):
    when compileOption("threads"):
      a.long.p = cast[ptr UncheckedArray[char]](allocShared(contentSize(b.long.len)))
    else:
      a.long.p = cast[ptr UncheckedArray[char]](alloc(contentSize(b.long.len)))
    a.long.len = b.long.len
    a.long.cap = uint b.long.len
    a.long.isLong = uint(true)
    copyMem(a.long.p, b.long.p, contentSize(a.long.len))
  else:
    copyMem(addr a, addr b, sizeof(String))

proc resize(old: int): int {.inline.} =
  if old <= 0: result = 4
  elif old < 65536: result = old * 2
  else: result = old * 3 div 2 # for large arrays * 3/2 is better

proc len*(s: String): int {.inline.} =
  if isLong(s): s.long.len else: int s.short.len

proc prepareAdd(s: var String; addLen: int) =
  let newLen = s.len + addLen
  if isLong(s):
    let oldCap = int s.long.cap
    if newLen > oldCap:
      let newCap = max(newLen, resize(oldCap))
      when compileOption("threads"):
        s.long.p = cast[ptr UncheckedArray[char]](reallocShared0(s.long.p, contentSize(oldCap), contentSize(newCap)))
      else:
        s.long.p = cast[ptr UncheckedArray[char]](realloc0(s.long.p, contentSize(oldCap), contentSize(newCap)))
      s.long.cap = uint newCap
  elif newLen > strMinCap:
    when compileOption("threads"):
      let p = cast[ptr UncheckedArray[char]](allocShared0(contentSize(newLen)))
    else:
      let p = cast[ptr UncheckedArray[char]](alloc0(contentSize(newLen)))
    let oldLen = int s.short.len
    if oldLen > 0:
      # we are about to append, so there is no need to copy the \0 terminator:
      copyMem(addr p[0], addr s.short.data[0], min(oldLen, newLen))
    s.long.len = oldLen
    s.long.p = p
    s.long.cap = uint newLen
    s.long.isLong = uint(true)

proc add*(s: var String; c: char) {.inline.} =
  let len = s.len
  prepareAdd(s, 1)
  s.data[len] = c
  s.data[len+1] = '\0'
  if isLong(s):
    inc s.long.len
  else:
    inc s.short.len

proc add*(dest: var String; src: String) {.inline.} =
  let srcLen = src.len
  if srcLen > 0:
    prepareAdd(dest, srcLen)
    # also copy the \0 terminator:
    copyMem(addr dest.data[dest.len], addr src.data[0], srcLen+1)
    if isLong(dest):
      inc dest.long.len, srcLen
    else:
      inc dest.short.len, srcLen

proc cstrToStr(str: cstring, len: int): String =
  if len <= 0:
    discard #result = String()
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr UncheckedArray[char]](allocShared(contentSize(len)))
      else:
        let p = cast[ptr UncheckedArray[char]](alloc(contentSize(len)))
      result.long.cap = uint len
      result.long.isLong = uint(true)
      result.long.p = p
      result.long.len = len
    else:
      result.short.len = uint8(len)
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
    discard #result = String()
  else:
    if space > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr UncheckedArray[char]](allocShared0(contentSize(space)))
      else:
        let p = cast[ptr UncheckedArray[char]](alloc0(contentSize(space)))
      result.long.cap = uint space
      result.long.isLong = uint(true)
      result.long.p = p

proc initString*(len: Natural): String =
  if len <= 0:
    discard #result = String()
  else:
    if len > strMinCap:
      when compileOption("threads"):
        let p = cast[ptr UncheckedArray[char]](allocShared0(contentSize(len)))
      else:
        let p = cast[ptr UncheckedArray[char]](alloc0(contentSize(len)))
      result.long.cap = uint len
      result.long.isLong = uint(true)
      result.long.p = p
      result.long.len = len
    else:
      result.short.len = uint8(len)

proc setLen*(s: var String, newLen: Natural) =
  if newLen == 0:
    discard "do not free the buffer here, pattern 's.setLen 0' is common for avoiding allocations"
  else:
    let oldLen = s.len
    if newLen > oldLen:
      prepareAdd(s, newLen - oldLen)
    s.data[newLen] = '\0'
  if isLong(s):
    s.long.len = newLen
  else:
    s.short.len = uint8(newLen)

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
