const std = @import("std");
const cli = @import("../cli.zig");

const Error = error{
    InvalidArgument,
    UnknownArgument,
    MissingArgument,
    MissingValue,
    DuplicateArgument,
    HelpRequested,
};

const Argument = struct {
    name: []const u8,
    description: []const u8 = "",
    default: ?[]const u8 = null,
    is_flag: bool = false,

    pub fn isValidName(arg: []const u8) bool {
        return arg.len > 0 and arg[0] == '-';
    }
};

fn ArgParser(comptime arguments: []const Argument) type {
    const len = arguments.len;
    const keys = &comptime blk: {
        var keys: [len][]const u8 = undefined;
        for (0..len) |i| {
            const key = arguments[i].name;
            if (!Argument.isValidName(key)) @compileError("Argument name must start with '-' but got: " ++ key);
            keys[i] = key;
        }
        break :blk keys;
    };
    const help_string = blk: {
        var res: []const u8 = undefined;
        res = "Options:\n";
        const spaces: [16]u8 = @splat(' ');
        for (arguments) |argument| {
            res = res ++ "  " ++ argument.name ++ " [value]" ++ spaces[0 .. spaces.len - argument.name.len] ++ argument.description ++ "\n";
        }
        break :blk res;
    };

    const map = blk: {
        var map = cli.hash_map.AutoHashMap(*const Argument, keys).init();
        for (arguments) |argument| {
            _ = map.set(argument.name, &argument);
        }
        break :blk map;
    };

    return struct {
        const Self = @This();
        const Map = cli.hash_map.AutoHashMap([]const u8, keys);

        map: Map,

        pub fn init() Self {
            return .{ .map = Map.init() };
        }
        pub fn parse(self: *Self, args: []const []const u8) !void {
            var i = @as(usize, 0);
            while (i < args.len) : (i += 1) {
                const arg = args[i];
                if (self.map.getPtr(arg)) |value_ptr| {
                    if (value_ptr.*) |value| {
                        _ = value;
                        return Error.DuplicateArgument;
                    }
                    const argument = map.get(arg) orelse unreachable;
                    if (argument.is_flag) {
                        value_ptr.* = "1";
                    } else {
                        i += 1;
                        if (i < args.len) {
                            value_ptr.* = args[i];
                        } else {
                            return Error.MissingValue;
                        }
                    }
                } else if (Argument.isValidName(arg)) {
                    if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                        return Error.HelpRequested;
                    }
                    return Error.UnknownArgument;
                } else {
                    return Error.InvalidArgument;
                }
            }
            for (arguments) |argument| {
                if (self.map.get(argument.name)) |value| {
                    _ = value;
                } else if (argument.is_flag) {
                    _ = self.map.set(argument.name, "0");
                } else if (argument.default) |default| {
                    _ = self.map.set(argument.name, default);
                } else {
                    return Error.MissingArgument;
                }
            }
        }
        pub fn get(self: Self, name: []const u8) ?[]const u8 {
            return self.map.get(name);
        }
        pub fn getHelpString(self: Self) []const u8 {
            _ = self;
            return help_string;
        }
    };
}

test "test arguments errors" {
    var arguments = ArgParser(&.{
        .{ .name = "--a" },
        .{ .name = "--b", .default = "3" },
        .{ .name = "--c", .is_flag = true },
    }).init();
    try std.testing.expectError(
        Error.MissingArgument,
        arguments.parse(&.{}),
    );
    try std.testing.expectError(
        Error.MissingValue,
        arguments.parse(&.{"--a"}),
    );
    try std.testing.expectError(
        Error.DuplicateArgument,
        arguments.parse(&.{ "--a", "10", "--a" }),
    );
    try std.testing.expectError(
        Error.UnknownArgument,
        arguments.parse(&.{"--d"}),
    );
    try std.testing.expectError(
        Error.InvalidArgument,
        arguments.parse(&.{ "--c", "1" }),
    );
    try std.testing.expectError(
        Error.InvalidArgument,
        arguments.parse(&.{"a"}),
    );
    try std.testing.expectError(
        Error.HelpRequested,
        arguments.parse(&.{"--help"}),
    );
    try std.testing.expectError(
        Error.HelpRequested,
        arguments.parse(&.{"-h"}),
    );
}

test "test arguments default" {
    var arguments = ArgParser(&.{
        .{ .name = "--a" },
        .{ .name = "--b", .default = "3" },
        .{ .name = "--c", .is_flag = true },
    }).init();
    try arguments.parse(&.{ "--a", "10" });
    try std.testing.expectEqual(arguments.get("--a"), "10");
    try std.testing.expectEqual(arguments.get("--b"), "3");
    try std.testing.expectEqual(arguments.get("--c"), "0");
}

test "test arguments" {
    var arguments = ArgParser(&.{
        .{ .name = "--a" },
        .{ .name = "--b", .default = "3" },
        .{ .name = "--c", .is_flag = true },
    }).init();
    try arguments.parse(&.{ "--a", "10", "--b", "20", "--c" });
    try std.testing.expectEqual(arguments.get("--a"), "10");
    try std.testing.expectEqual(arguments.get("--b"), "20");
    try std.testing.expectEqual(arguments.get("--c"), "1");
}
