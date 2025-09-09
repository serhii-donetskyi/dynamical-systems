const std = @import("std");
const ds = @import("dynamical_systems");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const x_dim = 2;
    const vector_len = 0;

    var solver = try ds.solver.RK4(vector_len).init(allocator, 0.01);
    defer solver.deinit();

    var ode = try ds.ode.Linear(vector_len).init(allocator, x_dim);
    defer ode.deinit();

    try solver.integrate(&ode, &ode.t, ode.x.ptr, 1000000);
}
