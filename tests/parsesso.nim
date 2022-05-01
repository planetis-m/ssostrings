
proc parseBin*[N; T: SomeInteger](s: N, number: var T, start = 0,
    maxLen = 0): int {.noSideEffect.} =
  var i = start
  var output = T(0)
  var foundDigit = false
  let last = min(s.len, if maxLen == 0: s.len else: i + maxLen)
  if i + 1 < last and s[i] == '0' and (s[i+1] in {'b', 'B'}): inc(i, 2)
  while i < last:
    case s[i]
    of '_': discard
    of '0'..'1':
      output = output shl 1 or T(ord(s[i]) - ord('0'))
      foundDigit = true
    else: break
    inc(i)
  if foundDigit:
    number = output
    result = i - start

func parseBinInt*[T](s: T): int =
  result = 0
  let L = parseBin(s, result, 0)
  if L != s.len or L == 0:
    raise newException(ValueError, "invalid binary integer")
