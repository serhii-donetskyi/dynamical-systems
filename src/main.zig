const std = @import("std");
const ds = @import("dynamical_systems");
const cli = @import("cli.zig");

const Global = struct {
    allocator: *const std.mem.Allocator,
    args: *const std.ArrayList([]const u8),
    stdout: *std.fs.File.Writer,
    stderr: *std.fs.File.Writer,
};

fn list_odes(global: *Global) !void {
    var writer = global.stdout;

    const odes = ds.ode.list();
    for (odes) |ode| {
        try writer.interface.print("  {s}\n", .{ode.name});
    }
    // try writer.interface.flush();
}
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args = try std.ArrayList([]const u8).initCapacity(
        allocator,
        64,
    );
    defer args.deinit(allocator);

    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    while (arg_iterator.next()) |arg| {
        try args.append(allocator, arg);
    }

    const stdout_file = std.fs.File.stdout();
    var stdout_buffer: [4096]u8 = undefined;
    const stderr_file = std.fs.File.stderr();
    var stderr_buffer: [4096]u8 = undefined;
    var stdout = std.fs.File.writer(stdout_file, stdout_buffer[0..]);
    var stderr = std.fs.File.writer(stderr_file, stderr_buffer[0..]);

    var global = Global{
        .allocator = &allocator,
        .args = &args,
        .stdout = &stdout,
        .stderr = &stderr,
    };

    try list_odes(&global);

    // const arg_parser = try ds.ArgParser.init(&.{
    //     .{ .name = "--n", .description = "The number of steps" },
    // });

    // // Get the executable path
    // const exe_path = try std.fs.selfExePathAlloc(allocator);
    // defer allocator.free(exe_path);

    // // Get the directory containing the executable
    // const exe_dir = std.fs.path.dirname(exe_path) orelse ".";
    // std.debug.print("Executable directory: {s}\n", .{exe_dir});

    // var arg_parser = try ds.ArgParser.init(allocator);
    // defer arg_parser.deinit();
    // try arg_parser.addArgument(.{ .name = "--n", .description = "The number of steps" });

    // arg_parser.parse() catch |err| {
    //     if (err == ds.ArgParser.Error.HelpRequested) return;
    //     return err;
    // };
}

test "test cli" {
    _ = cli;
}
