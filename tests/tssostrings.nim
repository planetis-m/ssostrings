import ssostrings, std/enumerate

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
    for i, str in enumerate(mitems(a)):
      let strLen = data.len - i
      let expected = data[0..<strLen]
      assert(str.toCStr == expected.cstring)
      assert(str.len == strLen)

main()
