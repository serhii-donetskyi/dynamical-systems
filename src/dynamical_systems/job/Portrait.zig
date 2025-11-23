const std = @import("std");
const ds = @import("../../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;
const Solver = ds.solver.Solver;
const Job = ds.job.Job;
const Allocator = std.mem.Allocator;
const Portrait = @This();

pub fn init(allocator: Allocator, t_step: f64, t_end: f64, file_path: []const u8) !Job {
    const args = try allocator.alloc(Argument, 3);
    errdefer allocator.free(args);

    args[0] = .{ .name = "t_step", .value = .{ .f = t_step } };
    args[1] = .{ .name = "t_end", .value = .{ .f = t_end } };
    args[2] = .{ .name = "file", .value = .{ .s = file_path } };

    return .{
        .allocator = allocator,
        .args = args,
        .data = undefined,
        .vtable = &.{
            .deinit = deinit,
            .run = run,
        },
    };
}

pub fn deinit(self: *Job) void {
    self.allocator.free(self.args);
}

pub fn run(self: *Job, solver: *Solver, ode: *ODE) !void {
    const t_step = self.args[0].value.f;
    const t_end = self.args[1].value.f;
    const file_path = self.args[2].value.s;

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();

    var buffer: [4024]u8 = undefined;
    var writer = file.writer(buffer[0..]);
    defer writer.interface.flush() catch {};

    try writer.interface.print("t", .{});
    for (0..ode.getXDim()) |i| {
        try writer.interface.print(" x[{}]", .{i});
    }
    try writer.interface.print("\n", .{});

    var t = ode.getT();

    const x_dim = ode.getXDim();
    const x = try self.allocator.alloc(f64, x_dim);
    defer self.allocator.free(x);
    for (0..x_dim) |i| {
        x[i] = ode.getX(i);
    }

    try writer.interface.print("{}", .{t});
    for (0..x_dim) |i| {
        try writer.interface.print(" {}", .{x[i]});
    }
    try writer.interface.print("\n", .{});

    while (t < t_end) {
        try solver.integrate(ode, &t, x.ptr, t + t_step);
        try writer.interface.print("{}", .{t});
        for (0..x_dim) |i| {
            try writer.interface.print(" {}", .{x[i]});
        }
        try writer.interface.print("\n", .{});
    }
}

test {
    var job = try Portrait.init(std.testing.allocator, 0.1, 1.0, "portrait.txt");
    defer job.deinit();

    var solver = try ds.solver.RK4.init(std.testing.allocator, 0.01);
    defer solver.deinit();

    var ode = try ds.ode.Linear.init(std.testing.allocator, 2);
    defer ode.deinit();

    try job.run(&solver, &ode);

    const file_exists = blk: {
        std.fs.cwd().access("portrait.txt", .{}) catch {
            break :blk false;
        };
        break :blk true;
    };
    try std.testing.expect(file_exists);
    if (file_exists) {
        try std.fs.cwd().deleteFile("portrait.txt");
    }
}
