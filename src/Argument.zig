const std = @import("std");

pub const Argument = @This();

pub const Value = union(enum) {
    i: isize,
    u: usize,
    f: f64,
    s: []const u8,
};

value: Value = .{ .i = 0 },
name: []const u8 = "",

test "test argument" {
    const name = "test";
    const i_argument = Argument{ .name = name, .value = .{ .i = 1 } };
    const s_argument = Argument{ .name = name, .value = .{ .s = name } };

    switch (i_argument.value) {
        .i => |i| {
            try std.testing.expect(i == 1);
        },
        else => unreachable,
    }

    switch (s_argument.value) {
        .s => |s| {
            try std.testing.expect(std.mem.eql(u8, s, name));
        },
        else => unreachable,
    }
}
