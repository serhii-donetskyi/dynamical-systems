const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Error = error{
    MissingArgument,
    UnparsedArgument,
    UnknownArgument,
    UnknownValue,
    HelpRequested,
};

fn hash(key: []const u8) usize {
    var res = @as(usize, 5381);
    for (key) |c| {
        res = (res << 5) + res + c;
    }
    return res;
}

pub const Argument = struct {
    name: []const u8,
    description: ?[]const u8 = null,
    default: ?[]const u8 = null,
};

fn isArgument(name: []const u8) bool {
    return name.len > 0 and name[0] == '-';
}

pub fn ArgParser(comptime arguments: []const Argument) type {
    for (arguments) |argument| {
        if (!isArgument(argument.name)) {
            @compileError("Argument name must start with '-' but got: " ++ argument.name);
        }
    }
    const len = arguments.len;
    const values = blk: {
        var values: [len]?[]const u8 = undefined;
        for (0..len) |i| {
            values[i] = arguments[i].default;
        }
        break :blk values;
    };
    const help_string = blk: {
        var res: []const u8 = undefined;
        res = "Options:\n";
        const spaces: [16]u8 = @splat(' ');
        for (arguments) |argument| {
            res = res ++ "  " ++ argument.name ++ " [value]" ++ spaces[0 .. spaces.len - argument.name.len] ++ (argument.description orelse "") ++ "\n";
        }
        break :blk res;
    };
    return struct {
        const Self = @This();
        const Enum: type = blk: {
            var enumFields: [len]std.builtin.Type.EnumField = undefined;
            for (0..len) |i| {
                enumFields[i] = .{
                    .name = arguments[i].name[0..arguments[i].name.len :0],
                    .value = hash(arguments[i].name),
                };
            }
            break :blk @Type(.{ .@"enum" = .{
                .tag_type = usize,
                .fields = &enumFields,
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_exhaustive = false,
            } });
        };

        comptime arguments: []const Argument = arguments,
        values: [len]?[]const u8 = values,

        fn getIndex(self: Self, name: []const u8) ?usize {
            _ = self;
            const e = @as(Enum, @enumFromInt(hash(name)));
            switch (e) {
                inline else => |tag| {
                    return comptime blk: {
                        for (@typeInfo(Enum).@"enum".fields, 0..) |field, i| {
                            if (@intFromEnum(tag) == field.value) {
                                break :blk i;
                            }
                        }
                    };
                },
                _ => return null,
            }
        }
        pub fn getArgument(self: Self, name: []const u8) ![]const u8 {
            const index = self.getIndex(name) orelse return Error.UnknownArgument;
            return self.values[index] orelse return Error.UnparsedArgument;
        }
        pub fn parse(self: *Self, args: []const []const u8) !void {
            var option: ?[]const u8 = null;
            for (args) |arg| {
                if (self.getIndex(arg)) |index| {
                    self.values[index] = "";
                    option = arg;
                } else if (option) |opt| {
                    const index = self.getIndex(opt) orelse unreachable;
                    self.values[index] = arg;
                    option = null;
                } else if (isArgument(arg)) {
                    if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                        return Error.HelpRequested;
                    }
                    return Error.UnknownArgument;
                } else {
                    return Error.UnknownValue;
                }
            }
            for (self.values) |value| {
                if (null == value) {
                    return Error.MissingArgument;
                }
            }
        }
        pub fn getHelpString(self: Self) []const u8 {
            _ = self;
            return help_string;
        }
    };
}

pub fn init(comptime arguments: []const Argument) ArgParser(arguments) {
    return .{};
}

test "parser init" {
    var parser = init(&.{
        .{ .name = "-a" },
        .{
            .name = "-b",
            .default = "b",
            .description = "b description",
        },
    });
    const Enum = @TypeOf(parser).Enum;
    const a = Enum.@"-a";

    // test Enum
    try std.testing.expectEqual(hash("-a"), @intFromEnum(a));

    // test getArgument
    try std.testing.expectEqual(Error.UnparsedArgument, parser.getArgument("-a"));
    try std.testing.expectEqual(Error.UnknownArgument, parser.getArgument("-c"));
    try std.testing.expectEqualStrings("b", try parser.getArgument("-b"));

    // test getHelpString
    try std.testing.expectEqualStrings(
        parser.getHelpString(),
        "Options:\n  -a [value]              \n  -b [value]              b description\n",
    );
}

test "parser parse" {
    var parser = init(&.{
        .{ .name = "-a" },
        .{ .name = "-b", .default = "b" },
    });

    // test parse errors
    try std.testing.expectEqual(Error.MissingArgument, parser.parse(&.{}));
    try std.testing.expectEqual(Error.UnknownArgument, parser.parse(&.{ "-c", "1" }));
    try std.testing.expectEqual(Error.UnknownValue, parser.parse(&.{"a"}));
    try std.testing.expectEqual(Error.HelpRequested, parser.parse(&.{"--help"}));
    try std.testing.expectEqual(Error.HelpRequested, parser.parse(&.{"-h"}));

    // test parse success
    try parser.parse(&.{ "-a", "1" });
    try std.testing.expectEqualStrings("1", try parser.getArgument("-a"));
    try std.testing.expectEqualStrings("b", try parser.getArgument("-b"));

    try parser.parse(&.{ "-b", "2" });
    try std.testing.expectEqualStrings("1", try parser.getArgument("-a"));
    try std.testing.expectEqualStrings("2", try parser.getArgument("-b"));

    try parser.parse(&.{ "-b", "1", "-a", "2" });
    try std.testing.expectEqualStrings("2", try parser.getArgument("-a"));
    try std.testing.expectEqualStrings("1", try parser.getArgument("-b"));
}
