const std = @import("std");
const Allocator = std.mem.Allocator;
const HashMap = std.StringHashMap(Argument);
pub const Error = error{
    HelpRequested,
    InvalidOption,
    InvalidArgument,
    MissingOption,
};
const ArgParser = @This();

allocator: Allocator,
map: HashMap,

const Argument = struct {
    description: ?[]const u8 = null,
    default: ?[]const u8 = null,
    value: ?[]const u8 = null,
};

pub fn init(allocator: Allocator) !ArgParser {
    return .{
        .allocator = allocator,
        .map = HashMap.init(allocator),
    };
}
pub fn deinit(self: *ArgParser) void {
    self.map.deinit();
}
pub fn addArgument(
    self: *ArgParser,
    options: struct {
        name: []const u8,
        description: ?[]const u8 = null,
        default: ?[]const u8 = null,
    },
) !void {
    if (!isOption(options.name)) return error.InvalidOption;
    try self.map.put(
        options.name,
        .{
            .description = options.description,
            .default = options.default,
            .value = null,
        },
    );
}
pub fn parse(self: *ArgParser) !void {
    var args = try std.process.argsWithAllocator(self.allocator);
    defer args.deinit();
    const name = args.next() orelse unreachable;

    var option: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (self.map.contains(arg)) {
            var get_put = try self.map.getOrPut(arg);
            get_put.value_ptr.value = "";
            option = arg;
        } else if (option) |opt| {
            var get_put = try self.map.getOrPut(opt);
            get_put.value_ptr.value = arg;
            option = null;
        } else if (isOption(arg)) {
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                try self.printUsage(name);
                return Error.HelpRequested;
            }
            return Error.InvalidOption;
        } else {
            return Error.InvalidArgument;
        }
    }

    var iter = self.map.iterator();
    while (iter.next()) |entry| {
        if (entry.value_ptr.value) |_| {
            continue;
        } else if (entry.value_ptr.default) |default| {
            entry.value_ptr.value = default;
        } else {
            std.log.err(
                "Required argument {s} has not been provided\n",
                .{entry.key_ptr.*},
            );
            return Error.MissingOption;
        }
    }
}
pub fn getArgument(self: ArgParser, name: []const u8) ?[:0]const u8 {
    const arg = self.map.get(name);
    if (arg) |a| return a.value;
}
pub fn printUsage(self: ArgParser, name: []const u8) !void {
    const spaces = " " ** 32;
    var writer = std.fs.File.stdout().writer(&.{});
    try writer.interface.print("Usage: {s} [options]\n", .{name});
    try writer.interface.print("\n", .{});
    try writer.interface.print("Options:\n", .{});
    var iter = self.map.iterator();
    while (iter.next()) |entry| {
        try writer.interface.print(
            "  {s} {s}{s}{s}\n",
            .{
                entry.key_ptr.*,
                "[value]",
                spaces[0 .. spaces.len - entry.key_ptr.len],
                entry.value_ptr.description orelse "",
            },
        );
    }
}

fn isOption(arg: anytype) bool {
    const T = @TypeOf(arg);
    if (T != []const u8 and T != [:0]const u8) {
        @compileError("arg must be a string slice");
    }
    return arg[0] == '-';
}

test "No options" {
    var arg_parser = try ArgParser.init(std.testing.allocator);
    defer arg_parser.deinit();
    try arg_parser.parse();
}

test "Invalid option" {
    var arg_parser = try ArgParser.init(std.testing.allocator);
    defer arg_parser.deinit();
    try arg_parser.addArgument(.{ .name = "--n" });
    std.testing.expectError(Error.MissingOption, arg_parser.parse());
}

test "Invalid argument" {
    var arg_parser = try ArgParser.init(std.testing.allocator);
    defer arg_parser.deinit();
    try arg_parser.addArgument(.{ .name = "--n" });
    try arg_parser.parse();
}
