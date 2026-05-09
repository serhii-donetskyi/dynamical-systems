const std = @import("std");
const ds = @import("dynamical_systems");
const Cli = @import("Cli.zig");

pub fn main(init: std.process.Init) !void {
    try Cli.main(&init);
}
