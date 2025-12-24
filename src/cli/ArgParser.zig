const std = @import("std");

const Allocator = std.mem.Allocator;
const ArgParser = @This();
pub const Error = error{
    NameTooLong,
    MissingValue,
    UnknownOption,
    UnknownArgument,
    PositionalArgumentMustBeString,
    PositionalArgumentMissing,
    HelpRequested,
};

pub const InputArg = struct {
    name: []const u8,
    ptr: union(enum) {
        bool: *bool,
        str: *[]const u8,
        list: *[]const []const u8,
    },

    pub fn isValidName(name: []const u8) bool {
        return name.len > 0 and name[0] == '-';
    }
};

const InputArgMap = std.StringHashMap(*const InputArg);
const BufferMap = std.StringHashMap(*anyopaque);

const List = std.ArrayList([]const u8);

allocator: Allocator,
args: List,
kwargs: InputArgMap,
buffers: BufferMap,

pub fn init(allocator: Allocator, vargs: []const InputArg) !ArgParser {
    var args = try List.initCapacity(allocator, vargs.len);
    errdefer args.deinit(allocator);

    var kwargs = InputArgMap.init(allocator);
    errdefer kwargs.deinit();

    for (vargs) |*arg_ptr| {
        if (arg_ptr.name.len > 25) return Error.NameTooLong;
        // Add arg to positional arguments if it is not a keyword argument
        if (!InputArg.isValidName(arg_ptr.name)) {
            if (arg_ptr.ptr != .str) return Error.PositionalArgumentMustBeString;
            try args.append(allocator, arg_ptr.name);
        }
        try kwargs.put(arg_ptr.name, arg_ptr);
    }

    return .{
        .allocator = allocator,
        .args = args,
        .kwargs = kwargs,
        .buffers = BufferMap.init(allocator),
    };
}

pub fn deinit(self: *ArgParser) void {
    var iter = self.buffers.iterator();
    while (iter.next()) |entry| {
        const name = entry.key_ptr.*;
        const ptr = entry.value_ptr.*;
        switch (self.kwargs.get(name).?.ptr) {
            .bool => {},
            .str => {},
            .list => {
                var list_ptr: *List = @ptrCast(@alignCast(ptr));
                list_ptr.deinit(self.allocator);
                self.allocator.destroy(list_ptr);
            },
        }
    }
    self.args.deinit(self.allocator);
    self.kwargs.deinit();
    self.buffers.deinit();
}

pub fn parse(self: *ArgParser, args: []const []const u8) !void {
    var pos_idx = @as(usize, 0);
    var arg_idx = @as(usize, 0);
    while (arg_idx < args.len) : (arg_idx += 1) {
        const arg = args[arg_idx];
        const arg_name, const arg_value = blk: {
            if (!InputArg.isValidName(arg)) {
                if (pos_idx < self.args.items.len) {
                    pos_idx += 1;
                    break :blk .{ self.args.items[pos_idx - 1], arg };
                }
                return Error.UnknownArgument;
            }
            if (self.kwargs.get(arg)) |input_arg_ptr| {
                if (input_arg_ptr.ptr == .bool)
                    break :blk .{ arg, "true" };
                arg_idx += 1;
                if (arg_idx < args.len)
                    break :blk .{ arg, args[arg_idx] }
                else
                    return Error.MissingValue;
            }
            if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
                return Error.HelpRequested;
            }
            return Error.UnknownOption;
        };
        if (self.kwargs.get(arg_name)) |input_arg_ptr| {
            switch (input_arg_ptr.ptr) {
                .bool => {
                    input_arg_ptr.ptr.bool.* = true;
                },
                .str => {
                    input_arg_ptr.ptr.str.* = arg_value;
                },
                .list => {
                    const list_ptr: *List = blk: {
                        const ptr_any = self.buffers.get(arg) orelse {
                            const ptr = try self.allocator.create(List);
                            ptr.* = try List.initCapacity(self.allocator, 1);
                            try self.buffers.put(arg, @ptrCast(ptr));
                            break :blk ptr;
                        };
                        break :blk @ptrCast(@alignCast(ptr_any));
                    };
                    try list_ptr.append(self.allocator, arg_value);
                    input_arg_ptr.ptr.list.* = list_ptr.items;
                },
            }
        } else unreachable;
    }
    if (pos_idx < self.args.items.len) {
        return Error.PositionalArgumentMissing;
    }
}

test "ArgParser" {
    var b: bool = false;
    var str: []const u8 = "";
    var list: []const []const u8 = undefined;
    var pos_arg: []const u8 = "";

    var parser = try ArgParser.init(
        std.testing.allocator,
        &[_]InputArg{
            .{
                .name = "-b",
                .ptr = .{ .bool = &b },
            },
            .{
                .name = "-s",
                .ptr = .{ .str = &str },
            },
            .{
                .name = "-l",
                .ptr = .{ .list = &list },
            },
            .{
                .name = "pos_arg",
                .ptr = .{ .str = &pos_arg },
            },
        },
    );
    defer parser.deinit();

    try parser.parse(&[_][]const u8{ "-b", "-s", "test", "-l", "0", "-l", "1", "-l", "2", "pos_arg" });
    try std.testing.expect(b);
    try std.testing.expectEqualStrings(str, "test");
    try std.testing.expectEqualStrings(list[0], "0");
    try std.testing.expectEqualStrings(list[1], "1");
    try std.testing.expectEqualStrings(list[2], "2");
    try std.testing.expectEqualStrings(pos_arg, "pos_arg");
}

test "ArgParser errors" {
    var b: bool = false;
    var str: []const u8 = "";
    var list: []const []const u8 = undefined;
    var pos_arg: []const u8 = "";

    var parser = try ArgParser.init(
        std.testing.allocator,
        &[_]InputArg{
            .{
                .name = "-b",
                .ptr = .{ .bool = &b },
            },
            .{
                .name = "-s",
                .ptr = .{ .str = &str },
            },
            .{
                .name = "-l",
                .ptr = .{ .list = &list },
            },
            .{
                .name = "pos_arg",
                .ptr = .{ .str = &pos_arg },
            },
        },
    );
    defer parser.deinit();

    try std.testing.expectError(Error.PositionalArgumentMissing, parser.parse(&[_][]const u8{}));
    try std.testing.expectError(Error.UnknownArgument, parser.parse(&[_][]const u8{ "pos_arg1", "pos_arg2" }));
    try std.testing.expectError(Error.MissingValue, parser.parse(&[_][]const u8{"-s"}));
    try std.testing.expectError(Error.MissingValue, parser.parse(&[_][]const u8{"-l"}));
    try std.testing.expectError(Error.UnknownOption, parser.parse(&[_][]const u8{"-unknown"}));
    try std.testing.expectError(Error.HelpRequested, parser.parse(&[_][]const u8{"-h"}));
    try std.testing.expectError(Error.HelpRequested, parser.parse(&[_][]const u8{"--help"}));
}
