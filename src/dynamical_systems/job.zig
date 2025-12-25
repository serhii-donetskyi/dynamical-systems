const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Job = struct {
    pub const Options = struct {
        separator: u8,
        float: std.fmt.float.Options,
    };

    allocator: Allocator,
    args: []const Argument,
    data: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*Job) void,
        run: *const fn (*Job, *Solver, *Ode, *std.io.Writer, Options) anyerror!void,
    };

    pub inline fn deinit(self: *Job) void {
        self.vtable.deinit(self);
    }
    pub inline fn run(self: *Job, solver: *Solver, ode: *Ode, w: *std.io.Writer, options: Options) anyerror!void {
        return self.vtable.run(self, solver, ode, w, options);
    }

    pub const Factory = struct {
        vtable: *const Factory.VTable,

        const VTable = struct {
            init: *const fn (Allocator, []const Argument) anyerror!Job,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn init(self: Factory, allocator: Allocator, args: []const Argument) anyerror!Job {
            return self.vtable.init(allocator, args);
        }
        pub inline fn getArguments(self: Factory) []const Argument {
            return self.vtable.getArguments();
        }
    };
};

pub const Skip = struct {
    pub fn init(allocator: Allocator, t_end: f64) !Job {
        const args = try allocator.alloc(Argument, 1);
        errdefer allocator.free(args);
        args[0] = .{ .name = "t_end", .value = .{ .f = t_end } };

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

    pub fn run(self: *Job, solver: *Solver, ode: *Ode, w: *std.io.Writer, options: Job.Options) anyerror!void {
        _ = w;
        _ = options;
        const t_end = self.args[0].value.f;

        var t = ode.getT();
        const x = try self.allocator.alloc(f64, ode.getXDim());
        defer self.allocator.free(x);
        for (0..ode.getXDim()) |i| {
            x[i] = ode.getX(i);
        }

        try solver.integrate(ode, &t, x.ptr, t_end);

        ode.setT(t);
        for (0..ode.getXDim()) |i| {
            ode.setX(i, x[i]);
        }
    }

    pub const Factory = struct {
        pub fn init(allocator: Allocator, args: []const Argument) !Job {
            return try Skip.init(allocator, args[0].value.f);
        }
        pub fn getArguments() []const Argument {
            return &[_]Argument{
                .{ .name = "t_end", .value = .{ .f = 1.0 } },
            };
        }
    };

    pub const factory = Job.Factory{
        .vtable = &.{
            .init = Factory.init,
            .getArguments = Factory.getArguments,
        },
    };
};

test "factory" {
    var ode = try ds.ode.Constant.init(std.testing.allocator, 2);
    defer ode.deinit();

    ode.setT(0.0);
    for (0..ode.getXDim()) |i| {
        ode.setX(i, 0.0);
    }

    var solver = try ds.solver.Euler.init(std.testing.allocator, 0.01);
    defer solver.deinit();

    var job = try Skip.factory.init(
        std.testing.allocator,
        Skip.factory.getArguments(),
    );
    defer job.deinit();

    var buf: [64]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    try job.run(&solver, &ode, &w, .{ .separator = ' ', .float = .{ .precision = 5, .mode = .decimal } });
    try std.testing.expectApproxEqAbs(ode.getT(), 1.0, 1e-9);
    for (0..ode.getXDim()) |i| {
        try std.testing.expectEqual(ode.getX(i), 0.0);
    }
}
