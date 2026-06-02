// Snapshot tests for the DOT (graphviz) renderer.
//
// The expected strings mirror petgraph's golden output in
// `crates/petgraph/src/dot/mod.rs`. Note that petgraph renders weights with the
// `Debug` formatter (`{:?}`), so a Rust `&str` weight `"A"` is shown quoted as
// `\"A\"`. MoonBit's `Show` for `String` does NOT add surrounding quotes, so to
// reproduce petgraph's exact golden strings we bake the quotes into the string
// weights of `simple_graph` below.
//
// We assert with `assert_eq` against multi-line `#|` string literals so the
// expected DOT reads naturally. A `#|` literal joins its lines with `\n` and has
// no trailing newline, so each expected block ends with a final empty `#|` line
// to account for the trailing `\n` the renderer emits.

///|
/// A simple directed graph mirroring petgraph's `simple_graph` test helper, but
/// with the quote characters baked into the string weights so the rendered DOT
/// matches petgraph's `{:?}` golden output exactly.
fn simple_graph() -> @graph.Graph[String, String] {
  let g : @graph.Graph[String, String] = @graph.Graph::new()
  let a = g.add_node("\"A\"")
  let b = g.add_node("\"B\"")
  g.add_edge(a, b, "\"edge_label\"") |> ignore
  g
}

///|
test "directed graph with int weights" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new()
  let a = g.add_node(10)
  let b = g.add_node(20)
  let c = g.add_node(30)
  g.add_edge(a, b, 1) |> ignore
  g.add_edge(b, c, 2) |> ignore
  assert_eq(
    @dot.to_dot(g),
    (
      #|digraph {
      #|    0 [ label = "10" ]
      #|    1 [ label = "20" ]
      #|    2 [ label = "30" ]
      #|    0 -> 1 [ label = "1" ]
      #|    1 -> 2 [ label = "2" ]
      #|}
      #|
    ),
  )
}

///|
test "undirected graph uses graph keyword and -- edges" {
  let g : @graph.Graph[Int, Int] = @graph.Graph::new_undirected()
  let a = g.add_node(0)
  let b = g.add_node(1)
  g.add_edge(a, b, 7) |> ignore
  assert_eq(
    @dot.to_dot(g),
    (
      #|graph {
      #|    0 [ label = "0" ]
      #|    1 [ label = "1" ]
      #|    0 -- 1 [ label = "7" ]
      #|}
      #|
    ),
  )
}

///|
test "NodeIndexLabel uses indices as node labels" {
  // Matches petgraph test_nodeindexlable_option.
  assert_eq(
    @dot.to_dot(simple_graph(), config=[@dot.NodeIndexLabel]),
    (
      #|digraph {
      #|    0 [ label = "0" ]
      #|    1 [ label = "1" ]
      #|    0 -> 1 [ label = "\"edge_label\"" ]
      #|}
      #|
    ),
  )
}

///|
test "EdgeIndexLabel uses indices as edge labels" {
  // Matches petgraph test_edgeindexlable_option.
  assert_eq(
    @dot.to_dot(simple_graph(), config=[@dot.EdgeIndexLabel]),
    (
      #|digraph {
      #|    0 [ label = "\"A\"" ]
      #|    1 [ label = "\"B\"" ]
      #|    0 -> 1 [ label = "0" ]
      #|}
      #|
    ),
  )
}

///|
test "EdgeNoLabel omits edge labels" {
  // Matches petgraph test_edgenolable_option.
  assert_eq(
    @dot.to_dot(simple_graph(), config=[@dot.EdgeNoLabel]),
    (
      #|digraph {
      #|    0 [ label = "\"A\"" ]
      #|    1 [ label = "\"B\"" ]
      #|    0 -> 1 [ ]
      #|}
      #|
    ),
  )
}

///|
test "NodeNoLabel omits node labels" {
  // Matches petgraph test_nodenolable_option.
  assert_eq(
    @dot.to_dot(simple_graph(), config=[@dot.NodeNoLabel]),
    (
      #|digraph {
      #|    0 [ ]
      #|    1 [ ]
      #|    0 -> 1 [ label = "\"edge_label\"" ]
      #|}
      #|
    ),
  )
}

///|
test "GraphContentOnly omits the digraph wrapper" {
  assert_eq(
    @dot.to_dot(simple_graph(), config=[@dot.GraphContentOnly]),
    (
      #|    0 [ label = "\"A\"" ]
      #|    1 [ label = "\"B\"" ]
      #|    0 -> 1 [ label = "\"edge_label\"" ]
      #|
    ),
  )
}

///|
test "escaping of quotes, backslashes and newlines" {
  // A backslash, a quote, and a newline must be escaped:
  //   "  -> \"        \  -> \\        \n -> \l
  let g : @graph.Graph[String, Int] = @graph.Graph::new()
  let a = g.add_node("a\"b\\c\nd")
  let b = g.add_node("plain")
  g.add_edge(a, b, 0) |> ignore
  assert_eq(
    @dot.to_dot(g),
    (
      #|digraph {
      #|    0 [ label = "a\"b\\c\ld" ]
      #|    1 [ label = "plain" ]
      #|    0 -> 1 [ label = "0" ]
      #|}
      #|
    ),
  )
}
