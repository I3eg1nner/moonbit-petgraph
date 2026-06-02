// Simple graphviz dot file format output.
//
// Ported from petgraph's `src/dot/mod.rs`. Formatting and options are rather
// simple; this is mostly intended for debugging. Exact output may change.

///|
/// `DotConfig` controls how a graph is rendered to the graphviz `.dot` format.
pub(all) enum DotConfig {
  /// Use indices for node labels.
  NodeIndexLabel
  /// Use indices for edge labels.
  EdgeIndexLabel
  /// Do not generate `label` attributes for edges.
  EdgeNoLabel
  /// Do not generate `label` attributes for nodes.
  NodeNoLabel
  /// Do not print the surrounding `graph`/`digraph { ... }` wrapper.
  GraphContentOnly
} derive(Eq)

///|
/// The indentation prefix used for body lines (matches petgraph's `INDENT`).
const INDENT : String = "    "

///|
/// Escape a single label string for graphviz, mirroring petgraph's `Escaper`.
///
/// `"` and `\` are prefixed with a backslash; a newline becomes `\l` (a
/// left-justified linebreak in graphviz). All other characters pass through
/// unchanged.
fn escape(s : String, into : StringBuilder) -> Unit {
  for c in s {
    match c {
      '"' | '\\' => {
        into.write_char('\\')
        into.write_char(c)
      }
      '\n' => into.write_string("\\l")
      _ => into.write_char(c)
    }
  }
}

///|
/// Whether `config` contains the given flag.
fn has(config : Array[DotConfig], flag : DotConfig) -> Bool {
  config.contains(flag)
}

///|
/// Render `graph` to the graphviz `.dot` format.
///
/// The node and edge weight types must implement `Show`; their `to_string()`
/// renderings are used as label text (then escaped). This matches petgraph's
/// use of `Display`/`Debug` for weights.
///
/// `config` is a set of `DotConfig` flags; see [`DotConfig`] for their meaning.
pub fn[N : Show, E : Show] to_dot(
  graph : @graph.Graph[N, E],
  config? : Array[DotConfig] = [],
) -> String {
  let buf = StringBuilder::new()
  let directed = graph.is_directed()
  let graph_kw = if directed { "digraph" } else { "graph" }
  let edge_op = if directed { "->" } else { "--" }
  let content_only = has(config, GraphContentOnly)
  let node_no_label = has(config, NodeNoLabel)
  let edge_no_label = has(config, EdgeNoLabel)
  let node_index_label = has(config, NodeIndexLabel)
  let edge_index_label = has(config, EdgeIndexLabel)
  if !content_only {
    buf.write_string(graph_kw)
    buf.write_string(" {\n")
  }

  // Output all node labels.
  for node in graph.node_ids() {
    buf.write_string(INDENT)
    buf.write_string(node.index().to_string())
    buf.write_string(" [ ")
    if !node_no_label {
      buf.write_string("label = \"")
      if node_index_label {
        buf.write_string(node.index().to_string())
      } else {
        match graph.node_weight(node) {
          Some(w) => escape(w.to_string(), buf)
          None => ()
        }
      }
      buf.write_string("\" ")
    }
    buf.write_string("]\n")
  }

  // Output all edges.
  let mut i = 0
  for edge in graph.edge_ids() {
    match graph.edge_endpoints(edge) {
      Some((src, dst)) => {
        buf.write_string(INDENT)
        buf.write_string(src.index().to_string())
        buf.write_char(' ')
        buf.write_string(edge_op)
        buf.write_char(' ')
        buf.write_string(dst.index().to_string())
        buf.write_string(" [ ")
        if !edge_no_label {
          buf.write_string("label = \"")
          if edge_index_label {
            buf.write_string(i.to_string())
          } else {
            match graph.edge_weight(edge) {
              Some(w) => escape(w.to_string(), buf)
              None => ()
            }
          }
          buf.write_string("\" ")
        }
        buf.write_string("]\n")
      }
      None => ()
    }
    i = i + 1
  }
  if !content_only {
    buf.write_string("}\n")
  }
  buf.to_string()
}
