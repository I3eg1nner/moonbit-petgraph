// Ported tests from petgraph's inline `#[cfg(test)]` module in
// `crates/petgraph/src/dot/mod.rs`.
//
// Only the IN-SCOPE tests are ported here: those that exercise DOT output for a
// plain `Graph` using the config flags we support
// (`NodeIndexLabel`/`EdgeIndexLabel`/`EdgeNoLabel`/`NodeNoLabel`), plus the
// standalone escaping test. The original Rust test names are preserved in the
// MoonBit test annotations.
//
// OUT OF SCOPE (skipped): `test_rankdir_bt_option`, `test_rankdir_tb_option`,
// `test_rankdir_lr_option`, `test_rankdir_rl_option` (use `Config::RankDir`,
// which our `DotConfig` does not have), and `test_with_attr_getters` (uses
// `Dot::with_attr_getters` with custom node/edge attribute getters, which our
// `to_dot` does not support).
//
// As in `dot_test.mbt`, petgraph renders weights with `{:?}` (Debug), so a Rust
// `&str` weight `"A"` is shown quoted as `\"A\"`. MoonBit's `Show` for `String`
// does NOT add surrounding quotes, so we bake the quotes into the string weights
// of `ported_simple_graph` below to reproduce petgraph's exact golden strings.

///|
/// Mirrors petgraph's `simple_graph()` test helper: a directed graph with two
/// `&str` nodes `"A"`/`"B"` and an edge labelled `"edge_label"`. The quote
/// characters are baked into the weights so the rendered DOT matches petgraph's
/// `{:?}` golden output byte-for-byte.
fn ported_simple_graph() -> @graph.Graph[String, String] {
  let graph : @graph.Graph[String, String] = @graph.Graph::new()
  let a = graph.add_node("\"A\"")
  let b = graph.add_node("\"B\"")
  graph.add_edge(a, b, "\"edge_label\"") |> ignore
  graph
}

///|
/// Ported from petgraph `test_escape`.
///
/// petgraph's original test drives the private `Escaper` directly over the input
/// `"\" \\ \n"` and asserts the output `"\\\" \\\\ \\l"`. We have no public
/// `Escaper`, so we exercise the identical escaping behaviour through `to_dot`
/// by using that string as a node weight and checking the emitted `label`.
test "test_escape" {
  let graph : @graph.Graph[String, Int] = @graph.Graph::new()
  graph.add_node("\" \\ \n") |> ignore
  // Input bytes:  "  (space) \  (space) \n
  // Escaped:      \"  (space) \\  (space) \l
  assert_eq(
    @dot.to_dot(graph),
    (
      #|digraph {
      #|    0 [ label = "\" \\ \l" ]
      #|}
      #|
    ),
  )
}

///|
/// Ported from petgraph `test_nodeindexlable_option`.
test "test_nodeindexlable_option" {
  assert_eq(
    @dot.to_dot(ported_simple_graph(), config=[@dot.NodeIndexLabel]),
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
/// Ported from petgraph `test_edgeindexlable_option`.
test "test_edgeindexlable_option" {
  assert_eq(
    @dot.to_dot(ported_simple_graph(), config=[@dot.EdgeIndexLabel]),
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
/// Ported from petgraph `test_edgenolable_option`.
test "test_edgenolable_option" {
  assert_eq(
    @dot.to_dot(ported_simple_graph(), config=[@dot.EdgeNoLabel]),
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
/// Ported from petgraph `test_nodenolable_option`.
test "test_nodenolable_option" {
  assert_eq(
    @dot.to_dot(ported_simple_graph(), config=[@dot.NodeNoLabel]),
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
