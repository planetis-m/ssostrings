import ssostrings
from std/strutils import repeat
from std/sequtils import mapLiterals

# Array where a < b
let lessThan = mapLiterals([
  ("apple", "banana"),
  ("cat", "dog"),
  ("hello", "world"),
  ("1", "2"),
  ("", "a"),
  ("abc", "abcd"),
  ("zebra", "zebras"),
  ("Ant", "ant"),
  ("α", "β"),
  ("9", "A"),
  ("This is a long string!", "This is a longer string!!"),
  ("A string with exactly 23", "A string with exactly 24!"),
  ("π is approximately 3.14", "π is approximately 3.141592")
], toStr)

# Array where a == b
let equalTo = mapLiterals([
  ("hello", "hello"),
  ("", ""),
  ("123", "123"),
  ("Anthropic", "Anthropic"),
  ("   ", "   "),
  ("🙂", "🙂"),
  ("café", "café"),
  ("ß", "ß"),
  ("\\n", "\\n"),
  ("ab", "ab"),
  ("This string is exactly 32 bytes long", "This string is exactly 32 bytes long"),
  ("Unicode: 你好世界", "Unicode: 你好世界"),
  ("A really long string that's used to test equality with another really long string",
   "A really long string that's used to test equality with another really long string")
], toStr)

# Array where a > b
let greaterThan = mapLiterals([
  ("zebra", "aardvark"),
  ("hello", "hell"),
  ("2", "1"),
  ("b", "B"),
  ("abc", "ABC"),
  ("ω", "α"),
  ("a", ""),
  ("café", "cafe"),
  ("z", "9"),
  # ("あ", "ア"),  # Hiragana comes after Katakana in Unicode
  ("This is definitely longer than 23 bytes", "AAA - first string alphabetically"),
  ("ZZZ - last string alphabetically", "This is shorter"),
  # ("Unicode: こんにちは世界", "Unicode: Hello World")  # Unicode comes after ASCII
], toStr)

proc main =
  block: # Less Than (<) Array
    for (a, b) in lessThan:
      assert a < b
      assert a <= b
      assert a != b
      assert not (a == b)
      assert not (a > b)
      assert not (a >= b)

  block: # Equal To (==) Array
    for (a, b) in equalTo:
      assert a == b
      assert a <= b
      assert a >= b
      assert not (a != b)
      assert not (a < b)
      assert not (a > b)

  block: # Greater Than (>) Array
    for (a, b) in greaterThan:
      assert a > b
      assert a >= b
      assert a != b
      assert not (a == b)
      assert not (a < b)
      assert not (a <= b)

  block: # Edge cases
    assert toStr"" <= toStr""
    assert not (toStr"" < toStr"")
    assert not (toStr"" > toStr"")
    assert toStr"" >= toStr""
    assert toStr"a" != toStr"A"
    assert toStr"9" < toStr"A"
    assert toStr"Z" < toStr"a"
    assert toStr"aa" > toStr"a"
    assert toStr("a".repeat(100)) > toStr("a".repeat(99))

main()
