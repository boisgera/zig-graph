const std = @import("std");
const Graph = @import("graph.zig").Graph;

pub fn main() !void {
    const Node = u16;
    const Label = f64;

    var graph = Graph(Node, Label).init();
    defer graph.deinit();

    try graph.nodes.put(0, {});
    try graph.nodes.put(1, {});
    try graph.nodes.put(42, {});
    try graph.nodes.put(666, {});
    try graph.edges.put(.{ 0, 1 }, 1.0);
    try graph.edges.put(.{ 1, 42 }, 2.0);
    try graph.edges.put(.{ 42, 666 }, 3.0);

    // std.debug.print("{}\n", .{graph});

    const map = try graph.getMap(0);
    _ = map;
}
