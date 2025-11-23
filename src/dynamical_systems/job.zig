const ds = @import("../dynamical_systems.zig");
const Argument = ds.Argument;
const ODE = ds.ode.ODE;
const Solver = ds.solver.Solver;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Job = struct {
    allocator: Allocator,
    args: []const Argument,
    data: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        deinit: *const fn (*Job) void,
        run: *const fn (*Job, *Solver, *ODE) anyerror!void,
    };

    pub inline fn deinit(self: *Job) void {
        self.vtable.deinit(self);
    }
    pub inline fn run(self: *Job, solver: *Solver, ode: *ODE) anyerror!void {
        return self.vtable.run(self, solver, ode);
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

pub const Portrait = @import("job/Portrait.zig");

test {
    _ = Portrait;
}
