const std = @import("std");
const cli = @import("../cli.zig");

fn defaultHash(key: []const u8) usize {
    return @truncate(std.hash.Wyhash.hash(0, key));
}

fn HashMap(
    comptime T: type,
    comptime hash: fn ([]const u8) usize,
    comptime keys: []const []const u8,
) type {
    const len = keys.len;
    const Enum = blk: {
        var enumFields: [len]std.builtin.Type.EnumField = undefined;
        for (0..len) |i| {
            enumFields[i] = .{
                .name = keys[i][0.. :0],
                .value = hash(keys[i]),
            };
        }
        break :blk @Type(.{ .@"enum" = .{
            .tag_type = usize,
            .fields = &enumFields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = false,
        } });
    };
    const getIndex = struct {
        fn getIndex(key: []const u8) ?usize {
            const e = @as(Enum, @enumFromInt(hash(key)));
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
    }.getIndex;

    return struct {
        const Self = @This();
        const Entry = struct {
            key: []const u8,
            value_ptr: *?T,
        };
        const Iterator = struct {
            index: usize,
            values: []?T,
            pub fn next(self: *Iterator) ?Entry {
                if (self.index < len) return .{
                    .key = keys[self.index],
                    .value_ptr = &self.values[self.index],
                };
                return null;
            }
            pub fn reset(self: *Iterator) void {
                self.index = 0;
            }
        };

        comptime len: usize = len,
        values: [len]?T,

        pub fn init() Self {
            return .{
                .values = @splat(null),
            };
        }
        pub fn get(self: Self, key: []const u8) ?T {
            const index = getIndex(key) orelse return null;
            return self.values[index];
        }
        pub fn getKeys(self: Self) []const []const u8 {
            _ = self;
            return keys;
        }
        pub fn getPtr(self: *Self, key: []const u8) ?*?T {
            const index = getIndex(key) orelse return null;
            return &self.values[index];
        }
        pub fn set(self: *Self, key: []const u8, value: T) bool {
            const index = getIndex(key) orelse return false;
            self.values[index] = value;
            return true;
        }
    };
}

pub fn AutoHashMap(comptime T: type, comptime keys: []const []const u8) type {
    return HashMap(T, defaultHash, keys);
}

test "hashMap" {
    var hashMap = AutoHashMap(i32, &.{ "a", "b", "c" }).init();
    try std.testing.expectEqual(true, hashMap.set("a", 1));
    try std.testing.expectEqual(true, hashMap.set("b", 2));
    try std.testing.expectEqual(false, hashMap.set("d", 4));
    try std.testing.expectEqual(1, hashMap.get("a"));
    try std.testing.expectEqual(2, hashMap.get("b"));
    try std.testing.expectEqual(null, hashMap.get("c"));
    try std.testing.expectEqual(null, hashMap.get("d"));
    try std.testing.expectEqual(1, hashMap.getPtr("a").?.*);
    try std.testing.expectEqual(2, hashMap.getPtr("b").?.*);
    try std.testing.expectEqual(null, hashMap.getPtr("c").?.*);
    try std.testing.expectEqual(null, hashMap.getPtr("d"));
}
