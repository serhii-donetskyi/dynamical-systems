const std = @import("std");
const ds = @import("dynamical_systems");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;
const Job = ds.job.Job;
const Allocator = std.mem.Allocator;
const Portrait = @This();

pub fn init(allocator: Allocator, t_step: f64, t_start: f64, t_end: f64) !Job {
    const args = try allocator.alloc(Argument, 3);
    errdefer allocator.free(args);

    args[0] = .{ .name = "t_step", .value = .{ .f = t_step } };
    args[1] = .{ .name = "t_start", .value = .{ .f = t_start } };
    args[2] = .{ .name = "t_end", .value = .{ .f = t_end } };

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

pub fn run(self: *Job, solver: *Solver, ode: *Ode, w: *std.io.Writer, options: Job.Options) !void {
    var buf: [128]u8 = undefined;
    const t_step = self.args[0].value.f;
    const t_start = self.args[1].value.f;
    const t_end = self.args[2].value.f;

    try w.print("t", .{});
    const x_dim = ode.getXDim();

    for (0..x_dim) |i| {
        try w.print("{c}x[{d}]", .{ options.separator, i });
    }
    try w.print("\n", .{});

    var t = ode.getT();

    const x = try self.allocator.alloc(f64, x_dim);
    defer self.allocator.free(x);
    for (0..x_dim) |i| {
        x[i] = ode.getX(i);
    }
    try solver.integrate(ode, &t, x.ptr, t + t_start);

    try w.print("{s}", .{try std.fmt.float.render(buf[0..], t, options.float)});
    for (0..x_dim) |i| {
        try w.print("{c}{s}", .{ options.separator, try std.fmt.float.render(buf[0..], x[i], options.float) });
    }
    try w.print("\n", .{});

    while (t < t_end) {
        try solver.integrate(ode, &t, x.ptr, t + t_step);
        try w.print("{s}", .{try std.fmt.float.render(buf[0..], t, options.float)});
        for (0..x_dim) |i| {
            try w.print("{c}{s}", .{ options.separator, try std.fmt.float.render(buf[0..], x[i], options.float) });
        }
        try w.print("\n", .{});
    }
}

const Factory = struct {
    fn init(allocator: Allocator, args: []const Argument) !Job {
        const t_step = args[0].value.f;
        const t_start = args[1].value.f;
        const t_end = args[2].value.f;
        return try Portrait.init(allocator, t_step, t_start, t_end);
    }
    fn getArguments() []const Argument {
        return &[_]Argument{
            .{ .name = "t_step", .value = .{ .f = 0.1 }, .description = "The step size to output" },
            .{ .name = "t_start", .value = .{ .f = 0.0 }, .description = "The start time" },
            .{ .name = "t_end", .value = .{ .f = 1.0 }, .description = "The end time" },
        };
    }
    fn factory() Job.Factory {
        return .{
            .vtable = &.{
                .init = Factory.init,
                .getArguments = getArguments,
            },
        };
    }
};

export const factory = &Factory.factory();

test "portrait" {
    var job = try Portrait.init(std.testing.allocator, 0.1, 0.0, 0.1);
    defer job.deinit();

    var solver = try ds.solver.Euler.init(std.testing.allocator, 0.01);
    defer solver.deinit();

    var ode = try ds.ode.Constant.init(std.testing.allocator, 2);
    defer ode.deinit();

    var buf: [64]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    try job.run(&solver, &ode, &w, .{ .separator = ' ', .float = .{ .precision = 5, .mode = .decimal } });
}
