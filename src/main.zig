const std = @import("std");
const ds = @import("dynamical_systems");
const cli = @import("cli.zig");

pub fn main() !void {
    // var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    // defer arena.deinit();
    // const allocator = arena.allocator();

    // var args_list = try std.ArrayList([]const u8).initCapacity(
    //     allocator,
    //     64,
    // );
    // defer args_list.deinit(allocator);

    // var arg_iterator = try std.process.argsWithAllocator(allocator);
    // defer arg_iterator.deinit();

    // while (arg_iterator.next()) |arg| {
    //     try args_list.append(allocator, arg);
    // }

    // const stdout_file = std.fs.File.stdout();
    // var stdout_buffer: [4096]u8 = undefined;
    // const stdout_writer = std.fs.File.writer(stdout_file, stdout_buffer[0..]);
    // defer stdout_writer.interface.flush() catch {};

    // const stdin_file = std.fs.File.stdin();
    // var stdin_buffer: [4096]u8 = undefined;
    // const stdin_reader = stdin_file.reader(stdin_buffer[0..]);

    // Initialize CLI globals
    // cli.allocator = allocator;
    // cli.stdout = stdout_writer;
    // cli.stdin = stdin_reader;

    // Run interactive CLI
    try cli.main();
}
