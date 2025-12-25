const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Ode = struct {
    allocator: Allocator,
    args: []const Argument,
    t: f64,
    x: []f64,
    p: []f64,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*Ode) void,
        calc: *const fn (*const Ode, f64, [*]const f64, [*]f64) void,
    };

    pub inline fn deinit(self: *Ode) void {
        self.vtable.deinit(self);
    }
    pub inline fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
        self.vtable.calc(self, t, x, dxdt);
    }
    pub inline fn getXDim(self: Ode) usize {
        return self.x.len;
    }
    pub inline fn getPDim(self: Ode) usize {
        return self.p.len;
    }
    pub inline fn getT(self: Ode) f64 {
        return self.t;
    }
    pub inline fn getX(self: Ode, i: usize) f64 {
        return self.x[i];
    }
    pub inline fn getP(self: Ode, i: usize) f64 {
        return self.p[i];
    }
    pub inline fn setT(self: *Ode, t: f64) void {
        self.t = t;
    }
    pub inline fn setX(self: *Ode, i: usize, x: f64) void {
        if (i < self.x.len) self.x[i] = x;
    }
    pub inline fn setP(self: *Ode, i: usize, p: f64) void {
        if (i < self.p.len) self.p[i] = p;
    }

    pub const Factory = struct {
        vtable: *const Factory.VTable,

        pub const VTable = struct {
            init: *const fn (Allocator, []const Argument) anyerror!Ode,
            getArguments: *const fn () []const Argument,
        };

        pub inline fn init(self: Factory, allocator: Allocator, args: []const Argument) anyerror!Ode {
            var ode = try self.vtable.init(allocator, args);
            ode.setT(0.0);
            for (0..ode.getXDim()) |i| {
                ode.setX(i, 0.0);
            }
            for (0..ode.getPDim()) |i| {
                ode.setP(i, 0.0);
            }
            return ode;
        }
        pub inline fn getArguments(self: Factory) []const Argument {
            return self.vtable.getArguments();
        }
    };
};

pub const Constant = struct {
    pub fn init(allocator: Allocator, n: usize) !Ode {
        const args = try allocator.alloc(Argument, 1);
        errdefer allocator.free(args);
        args[0] = .{ .name = "n", .value = .{ .u = n } };

        const x = try allocator.alloc(f64, n);
        errdefer allocator.free(x);

        const p = try allocator.alloc(f64, 0);
        errdefer allocator.free(p);

        return .{
            .allocator = allocator,
            .args = args,
            .t = 0.0,
            .x = x,
            .p = p,
            .vtable = &.{
                .deinit = deinit,
                .calc = calc,
            },
        };
    }

    pub fn deinit(self: *Ode) void {
        self.allocator.free(self.p);
        self.allocator.free(self.x);
        self.allocator.free(self.args);
    }

    pub fn calc(self: *const Ode, t: f64, x: [*]const f64, dxdt: [*]f64) void {
        _ = t;
        _ = x;
        for (0..self.x.len) |i| {
            dxdt[i] = 0;
        }
    }

    pub const Factory = struct {
        fn init(allocator: Allocator, args: []const Argument) !Ode {
            const n = args[0].value.u;
            return try Constant.init(allocator, n);
        }
        fn getArguments() []const Argument {
            return &[_]Argument{.{
                .name = "n",
                .value = .{ .u = 2 },
                .description = "The dimension of the system",
            }};
        }
    };

    pub const factory = Ode.Factory{
        .vtable = &.{
            .init = Factory.init,
            .getArguments = Factory.getArguments,
        },
    };
};

test "factory" {
    var ode = try Constant.factory.init(
        std.testing.allocator,
        Constant.factory.getArguments(),
    );
    defer ode.deinit();
}
