import ssostrings

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
    for i in 0..data.len:
      let strLen = data.len - i
      let expected = data[0..<strLen]
      let str = toStr(expected)
      assert(str.len == strLen)
      assert(str.toCStr == expected.cstring)

main()
