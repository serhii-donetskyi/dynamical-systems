const std = @import("std");
const ds = @import("dynamical_systems");

pub fn performance() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    inline for ([_]usize{ 2, 4, 8, 16, 32, 64 }) |v_len| {
        var linear = try ds.ode.Linear(v_len).init(allocator, v_len);
        defer linear.deinit();

        var solver = try ds.solver.RK4(v_len).init(allocator, 0.01);
        defer solver.deinit();

        const start = std.time.nanoTimestamp();
        try solver.integrate(&linear, &linear.t, linear.x.ptr, linear.t + 1000.0);
        const end = std.time.nanoTimestamp();
        std.debug.print("RK4({}), duration: {}\n", .{ v_len, end - start });
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Get the executable path
    const exe_path = try std.fs.selfExePathAlloc(allocator);
    defer allocator.free(exe_path);

    // Get the directory containing the executable
    const exe_dir = std.fs.path.dirname(exe_path) orelse ".";
    std.debug.print("Executable directory: {s}\n", .{exe_dir});

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Handle arguments here if needed
    while (args.next()) |arg| {
        std.debug.print("Argument: {s}\n", .{arg});
    }
}
