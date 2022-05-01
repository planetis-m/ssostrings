proc integerOutOfRangeError() {.noinline.} =
  raise newException(ValueError, "Parsed integer outside of valid range")

proc rawParseInt[T](s: T, b: var BiggestInt, start = 0): int =
  var
    sign: BiggestInt = -1
    i = start
  if i < s.len:
    if s[i] == '+': inc(i)
    elif s[i] == '-':
      inc(i)
      sign = 1
  if i < s.len and s[i] in {'0'..'9'}:
    b = 0
    while i < s.len and s[i] in {'0'..'9'}:
      let c = ord(s[i]) - ord('0')
      if b >= (low(BiggestInt) + c) div 10:
        b = b * 10 - c
      else:
        integerOutOfRangeError()
      inc(i)
      while i < s.len and s[i] == '_': inc(i) # underscores are allowed and ignored
    if sign == -1 and b == low(BiggestInt):
      integerOutOfRangeError()
    else:
      b = b * sign
      result = i - start

proc parseBiggestInt*[T](s: T, number: var BiggestInt, start = 0): int {.
    raises: [ValueError].} =
  var res = BiggestInt(0)
  # use 'res' for exception safety (don't write to 'number' in case of an
  # overflow exception):
  result = rawParseInt(s, res, start)
  if result != 0:
    number = res

proc parseInt*[T](s: T, number: var int, start = 0): int {.
    noSideEffect, raises: [ValueError].} =
  var res = BiggestInt(0)
  result = parseBiggestInt(s, res, start)
  when sizeof(int) <= 4:
    if res < low(int) or res > high(int):
      integerOutOfRangeError()
  if result != 0:
    number = int(res)

func parseInt*[T](s: T): int =
  result = 0
  let L = parseInt(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid integer")
