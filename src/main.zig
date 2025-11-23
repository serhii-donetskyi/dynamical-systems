const std = @import("std");
const ds = @import("dynamical_systems");

var stdout: std.fs.File.Writer = undefined;

fn print(comptime fmt: []const u8, args: anytype) !void {
    try stdout.interface.print(fmt, args);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_list = try std.ArrayList([]const u8).initCapacity(
        allocator,
        64,
    );
    defer args_list.deinit(allocator);

    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    while (arg_iterator.next()) |arg| {
        try args_list.append(allocator, arg);
    }

    const stdout_file = std.fs.File.stdout();
    var stdout_buffer: [4096]u8 = undefined;
    stdout = std.fs.File.writer(stdout_file, stdout_buffer[0..]);
    defer stdout.interface.flush() catch {};

    var ode = try ds.ode.Linear.init(allocator, 2);
    defer ode.deinit();

    ode.setX(1, 1.0);
    ode.setP(1, 1.0);
    ode.setP(2, -1.0);

    var solver = try ds.solver.RK4.init(allocator, 0.01);
    defer solver.deinit();

    var job = try ds.job.Portrait.init(allocator, 1e6, 1e6, "portrait.txt");
    defer job.deinit();

    try job.run(&solver, &ode);
}
