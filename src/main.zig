const std = @import("std");
const ds = @import("dynamical_systems");

pub fn performance() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    for ([_]usize{ 2, 4, 8, 16, 32, 64 }) |n| {
        inline for ([_]usize{ 0, 2, 4, 8, 16, 32 }) |v_len| {
            var linear = try ds.ode.Linear(v_len).init(allocator, n);
            defer linear.deinit();

            const start = std.time.nanoTimestamp();
            for (0..10000) |_| {
                linear.calc(linear.t, linear.x.ptr, linear.x.ptr);
            }
            const end = std.time.nanoTimestamp();
            std.debug.print("Linear({}), n={}, duration: {}\n", .{ v_len, n, end - start });
        }
        std.debug.print("\n", .{});
    }
}

pub fn main() !void {
    try performance();
}
