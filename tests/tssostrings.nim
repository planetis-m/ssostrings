import ssostrings, std/[enumerate, parseutils, assertions, hashes]

proc parseHex[T: SomeInteger](s: String, number: var T, start = 0,
                              maxLen = 0): int {.noSideEffect, inline.} =
  parseHex(s.toOpenArray(start, s.high), number, maxLen)

proc main =
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var str = String()
    for c in data:
      str.add c
    let expected = toStr(data)
    assert str.len == data.len
    assert str == expected
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var a: seq[String] = @[]
    for i in 0..data.len:
      let strLen = data.len - i
      let expected = data[0..<strLen]
      var str = toStr(expected)
      a.add(str)
      assert str.toCStr == expected.cstring
      assert str.len == strLen
    for i, str in enumerate(items(a)):
      let strLen = data.len - i
      let expected = data[0..<strLen]
      assert str.toCStr == expected.cstring
      assert str.len == strLen
  block:
    let str = toStr(cstring"7B")
    var num = 0
    assert parseHex(str, num) == 2
    assert num == 123
  block:
    let str = toStr(cstring"7B")
    assert str.toNimStr == "7B"

main()
