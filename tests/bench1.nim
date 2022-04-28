import std/[algorithm, times, stats, strformat]
import cowstrings, ssostrings

proc warmup() =
  # Warmup - make sure cpu is on max perf
  let start = cpuTime()
  var a = 123
  for i in 0 ..< 300_000_000:
    a += i * i mod 456
    a = a mod 789
  let dur = cpuTime() - start
  echo &"Warmup: {dur:>4.4f} s ", a

proc printStats(name: string, stats: RunningStat, dur: float) =
  echo &"""{name}:
  Collected {stats.n} samples in {dur:>4.4f} s
  Average time: {stats.mean * 1000:>4.4f} ms
  Stddev  time: {stats.standardDeviationS * 1000:>4.4f} ms
  Min     time: {stats.min * 1000:>4.4f} ms
  Max     time: {stats.max * 1000:>4.4f} ms"""

template bench(name, samples, code: untyped) =
  var stats: RunningStat
  let globalStart = cpuTime()
  for i in 0 ..< samples:
    let start = cpuTime()
    code
    let duration = cpuTime() - start
    stats.push duration
  let globalDuration = cpuTime() - globalStart
  printStats(name, stats, globalDuration)

converter toCow(str: string): cowstrings.String = cowstrings.toStr(str)
converter toSso(str: string): ssostrings.String = ssostrings.toStr(str)

proc myCmp[T](a, b: T): int =
  when T is cowstrings.String:
    cowstrings.cmpStrings(a, b)
  elif T is ssostrings.String:
    ssostrings.cmpStrings(a, b)
  else:
    cmp[T](a, b)

proc test[T] =
  const data = "01234567890123456789012345678901234567890123456789"
  const reps = 10000
  echo "----------------------------"
  echo $T, " (", sizeof(T), " bytes)"
  echo "----------------------------"
  for length in 22 .. 23:
    echo "Length ", length, ": "
    let testString = data[0..<length]
    var strings = newSeqOfCap[T](reps)

    bench("Construction " & $T, reps):
      strings.add(testString)

    var count = 0
    bench("Copy " & $T, reps):
      var copy = strings[0]
      inc count, copy.len

    count = 0
    bench("Move " & $T, reps):
      var move = move(strings[0])
      inc count, move.len
      strings[0] = move(move)

    count = 0
    bench("Compare " & $T, reps):
      for i in 1..<strings.len:
        inc count, myCmp(strings[0], strings[i])

    bench("Sort " & $T, reps):
      sort(strings, myCmp)

proc main =
  warmup()
  test[string]()
  test[ssostrings.String]()
  test[cowstrings.String]()

main()
