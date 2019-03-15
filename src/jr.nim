import json
import noise
import re
import sequtils
import streams
import strformat
import strutils

proc freopen(path: cstring, mode: cstring, stream: File): File {.header: "<stdio.h>", importc: "freopen".}
proc fdopen(fd: cint, mode: cstring): File {.header: "<stdio.h>", importc: "fdopen".}
proc dup(oldfd: cint): cint {.header: "<unistd.h>", importc: "dup".}
proc ttyname(fd: cint): cstring {.header: "<unistd.h>", importc: "ttyname".}

# What are the piped inputs/outputs?
let pipeout = fdopen(dup(getFileHandle(stdout)), "a")
let pipein  = fdopen(dup(getFileHandle(stdin)), "r")

# Remap stdin/stdout to the attached console
if freopen("/dev/tty", "r", stdin) == nil:
  quit(QuitFailure)

if freopen("/dev/tty", "a", stdout) == nil:
  quit(QuitFailure)

let payload = pipein.newFileStream.parseJson

# We explode the JSON into every node & subnode, keyed by the identifying path.
#
# E.g. { one: { two : true }, three: 4 } gives:
#   root         => { one: { two : true }, three: 4 }
#   root.one     => { two : true }
#   root.one.two => true
#   root.three   => 4
#
# This allows us to easily match queries to subnodes.

type
  PathNode = tuple[key: string, node: JsonNode]

proc getPathNodes(prefix: string, node: JsonNode): seq[PathNode] =
  var nodes = @[ (key: prefix, node: node) ]
  
  case node.kind
  of JObject:
    for k, n in pairs(node):
      nodes.add( getPathNodes(fmt"{prefix}.{k}", n) )
  of JArray:
    for i, n in node.elems:
      nodes.add( getPathNodes(fmt"{prefix}.{i}", n) )
  else:
    discard

  nodes

proc match(str, pattern: string): bool =
  if pattern =~ re"^\{(.*)\}$":
    let alternatives = matches[0].split(",")
    if str in alternatives:
      return true
    return false
  if pattern == "*":
    return true
  return str == pattern
  
proc filter(nodes: seq[PathNode], pattern: string): seq[PathNode] =
  let filterTokens = pattern.split(".")
  filter(nodes) do (n: PathNode) -> bool:
    let nodeTokens = n.key.split(".")

    if len(filterTokens) != len(nodeTokens):
      return false

    for t in zip(filterTokens, nodeTokens):
      let pattern = t[0]
      let path = t[1]
      if not path.match(pattern):
        return false
    return true
  
let path_nodes = getPathNodes("root", payload)

var repl = Noise.init()
let prompt = Styler.init(fgGreen, "> ")
repl.setPrompt(prompt)

type
  Cmd = enum
    Keys, Show

while repl.readLine():

  let line = repl.getLine

  var pattern = "root"
  var command = Keys
  
  if line =~ re"^keys +(.*)$":
    pattern = fmt"root.{matches[0]}"
    command = Keys
  elif line =~ re"^keys$":
    pattern = fmt"root"
    command = Keys
  else:
    pattern = fmt"root.{line}"
    command = Show

  repl.historyAdd(line)

  case command
  of Show:
    for n in path_nodes.filter(pattern):
      echo fmt"{n.key[5..^1]}: {pretty(n.node)}"
  of Keys:
    for n in path_nodes.filter(fmt"{pattern}.*"):
      let kind = fmt"{n.node.kind}"
      echo fmt"{n.key[5..^1]}: {kind[1..^1]}"

pipeout.write(payload)
