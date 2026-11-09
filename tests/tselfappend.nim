import ssostrings

proc main =
  # self-append with growth: the buffer must be reallocated, and the source
  # bytes live in the old buffer, so they must be copied before it is freed
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyz"
    var s = toStr(data)
    s.add(s)
    let expected = data & data
    assert s.len == expected.len
    assert toNimStr(s) == expected
    assert s.toCStr[expected.len] == '\0'

  # self-append in place: enough capacity, no reallocation, overlapping copy
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyz"
    var s = initStringOfCap(data.len * 2 + 8)
    s.setLen(data.len)
    for i in 0 ..< data.len:
      s[i] = data[i]
    s.add(s)
    let expected = data & data
    assert s.len == expected.len
    assert toNimStr(s) == expected
    assert s.toCStr[expected.len] == '\0'

  # repeated self-appends
  block:
    let data = "0123456789012345678901234567890"
    var s = toStr(data)
    var expected = toNimStr(s)
    for i in 1 .. 3:
      s.add(s)
      expected = expected & expected
      assert toNimStr(s) == expected
    assert s.len == data.len * 8

  # short self-append that stays short
  block:
    let data = "abc"
    var s = toStr(data)
    s.add(s)
    assert s.len == 6
    assert toNimStr(s) == "abcabc"

  # short self-append crossing the small-string capacity (promotion)
  block:
    let data = "012345678901234567890"
    var s = toStr(data)
    s.add(s)
    assert s.len == data.len * 2
    assert toNimStr(s) == data & data

  # appending a copy keeps both strings intact
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyz"
    var a = toStr(data)
    var b = a
    b.add(a)
    assert b.len == data.len * 2
    assert toNimStr(b) == data & data
    assert toNimStr(a) == data

  echo "tselfappend: all assertions passed"

main()
