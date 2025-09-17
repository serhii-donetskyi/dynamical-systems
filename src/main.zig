const std = @import("std");
const ds = @import("dynamical_systems");

pub fn performance() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var linear = try ds.ode.Linear(0).init(allocator, 2);
    defer linear.deinit();

    var solver = try ds.solver.RK4(0).init(allocator, 0.01);
    defer solver.deinit();

    try solver.integrate(&linear, &linear.t, linear.x.ptr, linear.t + 1e6);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // // Get the executable path
    // const exe_path = try std.fs.selfExePathAlloc(allocator);
    // defer allocator.free(exe_path);

    // // Get the directory containing the executable
    // const exe_dir = std.fs.path.dirname(exe_path) orelse ".";
    // std.debug.print("Executable directory: {s}\n", .{exe_dir});

    var arg_parser = try ds.ArgParser.init(allocator);
    defer arg_parser.deinit();
    try arg_parser.addArgument(.{ .name = "--n", .description = "The number of steps" });

    arg_parser.parse() catch |err| {
        if (err == ds.ArgParser.Error.HelpRequested) return;
        return err;
    };
}
