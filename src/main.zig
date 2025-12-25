const std = @import("std");
const ds = @import("dynamical_systems");
const cli = @import("cli.zig");

pub fn main() !void {
    var sa = [_]f64{ 1.0, 2.0, 3.0 };
    const a: []f64 = &sa;
    const p = a.ptr;

    var i: usize = 0;
    _ = &i;

    const p2 = p[i..];

    const v: @Vector(4, f64) = p[i..][0..4].*;

    std.debug.print("p2: {any}\n", .{@TypeOf(p2)});
    std.debug.print("v: {any}\n", .{v});
    // try cli.main();
}
