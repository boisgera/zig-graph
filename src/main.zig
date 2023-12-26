const std = @import("std");
const Graph = @import("graph.zig").Graph;

pub fn main() !void {
    const Node = u16;
    const Label = f64;
    var graph = Graph(Node, Label).init();
    try graph.nodes.put(0, {});
    try graph.nodes.put(1, {});
    try graph.nodes.put(42, {});
    try graph.nodes.put(666, {});
    try graph.edges.put(.{ 0, 42 }, 1.0);
    try graph.edges.put(.{ 0, 666 }, std.math.inf(f64));

    std.debug.print("{}\n", .{graph});

    var it = (try graph.neighbors(0)).iterator();
    while (it.next()) |kv| {
        const node = kv.key_ptr.*;
        std.debug.print("{}\n", .{node});
    }
}
