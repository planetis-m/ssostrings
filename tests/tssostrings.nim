import ssostrings, std/enumerate, std/parseutils

template toOa(s: String; first, last: int): untyped =
  toOpenArray(toCStr(addr s), first, last)

template toOa(s: String): untyped =
  toOpenArray(toCStr(addr s), 0, len(s)-1)

proc main =
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var str: String
    for c in data:
      str.add c
    let expected = toStr(data)
    assert(str.len == data.len)
    assert(str == expected)
  block:
    let data = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    var a: seq[String]
    for i in 0..data.len:
      let strLen = data.len - i
      let expected = data[0..<strLen]
      var str = toStr(expected)
      a.add(str)
      assert(str.toCStr == expected.cstring)
      assert(str.len == strLen)
    for i, str in enumerate(items(a)):
      let strLen = data.len - i
      let expected = data[0..<strLen]
      assert(str.toCStr == expected.cstring)
      assert(str.len == strLen)
  block:
    var str = toStr(cstring"7B")
    var num = 0
    assert parseHex(str.toOa, num) == 2
    assert num == 123

main()
