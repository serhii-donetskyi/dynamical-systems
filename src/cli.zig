const std = @import("std");
const ds = @import("dynamical_systems");

const ArgParser = @import("cli/ArgParser.zig");
const DynLib = std.DynLib;
const StringHashMap = std.StringHashMap;
const Dir = std.Io.Dir;
const File = std.Io.File;

const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;
const Job = ds.job.Job;

const DynLibs = std.ArrayList(DynLib);
const Strings = std.ArrayList([]const u8);
const ArgumentMap = StringHashMap(*ds.Argument);

const CommandMap = StringHashMap(*const fn (*Cli) anyerror!void);
const OdeMap = StringHashMap(*const Ode.Factory);
const SolverMap = StringHashMap(*const Solver.Factory);
const JobMap = StringHashMap(*const Job.Factory);

const Cli = @This();

const NameAndDescription = struct {
    name: []const u8,
    description: []const u8,
};

const Error = error{
    UnexpectedBinPath,
    UnexpectedAppPath,
    FactoryNotFound,
    MissingCommand,
    UnknownCommand,
    UnknownComponent,

    UnknownArgument,
    InvalidArgument,
    MissingArgument,
};

init: *const std.process.Init,
allocator: std.mem.Allocator,
args: Strings,
stderr: File.Writer,
commands: CommandMap,
dyn_libs: DynLibs,
odes: OdeMap,
solvers: SolverMap,
jobs: JobMap,

pub fn main(init: *const std.process.Init) !void {
    const usage =
        \\ Usage: {s} <command> [options]
        \\
        \\ Commands:
        \\   ode-list                          List available ODEs
        \\   solver-list                       List available solvers
        \\   job-list                          List available jobs
        \\   ode-get-args <ode-name>           Get arguments for an ODE
        \\   solver-get-args <solver-name>     Get arguments for a solver
        \\   job-get-args <job-name>           Get arguments for a job
        \\   run                               Run a dynamical system simulation
        \\
        \\ Options:
        \\   -h, --help     Show usage message and exit
        \\
    ;
    const allocator = init.arena.allocator();

    var args = try Strings.initCapacity(allocator, 64);

    var iter = try init.minimal.args.iterateAllocator(allocator);
    defer iter.deinit();
    while (iter.next()) |arg| {
        try args.append(allocator, arg);
    }

    const no_buf: [0]u8 = undefined;
    var self = Cli{
        .init = init,
        .allocator = allocator,
        .args = args,
        .stderr = std.Io.File.stderr().writer(init.io, no_buf[0..]),
        .commands = CommandMap.init(allocator),
        .dyn_libs = try DynLibs.initCapacity(allocator, 16),
        .odes = OdeMap.init(allocator),
        .solvers = SolverMap.init(allocator),
        .jobs = JobMap.init(allocator),
    };

    inline for ([_]type{ Ode, Solver, Job }) |component| {
        try self.componentLoad(component);
    }

    try self.commands.put("ode-list", componentList(Ode));
    try self.commands.put("solver-list", componentList(Solver));
    try self.commands.put("job-list", componentList(Job));
    try self.commands.put("ode-get-args", componentGetArguments(Ode));
    try self.commands.put("solver-get-args", componentGetArguments(Solver));
    try self.commands.put("job-get-args", componentGetArguments(Job));
    try self.commands.put("run", run);

    if (self.args.items.len < 2) {
        try self.log("Error: missing command\n", .{});
        try self.log(usage, .{self.args.items[0]});
        return Error.MissingCommand;
    }

    const command = self.commands.get(self.args.items[1]) orelse {
        try self.log("Error: unknown command: '{s}'\n", .{self.args.items[1]});
        try self.log(usage, .{self.args.items[0]});
        return Error.UnknownCommand;
    };

    try command(&self);
}

fn deinit(self: *Cli) void {
    self.odes.deinit();
    self.solvers.deinit();
    self.jobs.deinit();
    self.dyn_libs.deinit(self.allocator);
    self.args.deinit(self.allocator);
    // self.stderr.flush() catch {};
}

fn log(self: *Cli, comptime fmt: []const u8, args: anytype) !void {
    try self.stderr.interface.print(fmt, args);
}

fn componentGetPair(self: *Cli, component: type) struct { []const u8, *StringHashMap(*const component.Factory) } {
    return switch (component) {
        Ode => .{ "ODE", &self.odes },
        Solver => .{ "Solver", &self.solvers },
        Job => .{ "Job", &self.jobs },
        else => @compileError("Unknown component type: " ++ @typeName(component)),
    };
}

fn componentLoad(self: *Cli, component: type) !void {
    const component_name, const map = self.componentGetPair(component);

    const bin_dir = Dir.path.dirname(self.args.items[0]) orelse return Error.UnexpectedBinPath;
    const app_dir = Dir.path.dirname(bin_dir) orelse return Error.UnexpectedAppPath;
    const lib_dir = try Dir.path.join(self.allocator, &.{ app_dir, "lib", component_name });
    defer self.allocator.free(lib_dir);

    var dir = Dir.openDirAbsolute(self.init.io, lib_dir, .{ .iterate = true }) catch |err| {
        try self.log("Error: cannot open directory '{s}': {s}\n", .{ lib_dir, @errorName(err) });
        return err;
    };
    defer dir.close(self.init.io);

    var iter = dir.iterate();
    while (try iter.next(self.init.io)) |entry| {
        if (entry.kind == .file) {
            const file_path = try Dir.path.join(self.allocator, &.{ lib_dir, entry.name });
            defer self.allocator.free(file_path);

            var lib = DynLib.open(file_path) catch |err| {
                try self.log("Error: cannot load {s} library '{s}': {s}\n", .{ component_name, entry.name, @errorName(err) });
                return;
            };
            try self.dyn_libs.append(self.allocator, lib);

            const factory_ = lib.lookup(*const *const component.Factory, "factory");
            if (factory_) |factory| {
                var name = entry.name;
                if (std.mem.eql(u8, name[0..3], "lib")) name = name[3..];
                if (std.mem.lastIndexOf(u8, name, ".")) |dot_idx| name = name[0..dot_idx];
                var factory_name = try self.allocator.dupe(u8, name);
                factory_name = std.ascii.lowerString(factory_name, factory_name);
                try map.put(factory_name, factory.*);
            } else {
                try self.log("Error: cannot load {s} library '{s}': factory not found\n", .{ component_name, entry.name });
                return;
            }
        }
    }
}

fn componentList(component: type) fn (*Cli) anyerror!void {
    return struct {
        fn func(self: *Cli) !void {
            const name, const map = self.componentGetPair(component);

            var idx: usize = 1;
            var iter = map.keyIterator();
            if (iter.len == 0) {
                try self.log("No available {s}s\n", .{name});
                return;
            }
            try self.log("Available {s}s:\n", .{name});
            while (iter.next()) |key| : (idx += 1) {
                try self.log("  {d}. {s}\n", .{ idx, key.* });
            }
        }
    }.func;
}

fn componentGetArguments(component: type) fn (*Cli) anyerror!void {
    return struct {
        fn func(self: *Cli) !void {
            const padding: [32]u8 = @splat(' ');
            const name, const map = self.componentGetPair(component);
            var actual_name: []const u8 = "";

            var parser = try ArgParser.init(
                self.allocator,
                &.{
                    .{ .name = name, .ptr = .{ .str = &actual_name } },
                },
            );
            defer parser.deinit();

            parser.parse(self.args.items[2..]) catch |err| switch (err) {
                ArgParser.Error.HelpRequested => {
                    var buffer: [32]u8 = undefined;
                    const name_lower = std.ascii.lowerString(buffer[0..], name);
                    try self.log("Usage: {s} {s} <{s}-name>\n", .{ self.args.items[0], self.args.items[1], name_lower });
                    return;
                },
                else => return err,
            };

            if (map.get(actual_name)) |factory| {
                const cargs = factory.getArguments();
                if (cargs.len == 0) {
                    try self.log("'{s}' has no arguments\n", .{actual_name});
                    return;
                }
                try self.log("Arguments for {s}:\n", .{actual_name});
                for (cargs, 1..) |carg, idx| {
                    const type_slug = switch (carg.value) {
                        .u => "<integer>",
                        .i => "<integer>",
                        .f => "<float>",
                        .s => "<string>",
                    };
                    try self.log("  {d}. {s} {s} {s}{s}\n", .{ idx, carg.name, type_slug, padding[0 .. padding.len - carg.name.len - type_slug.len - 3], carg.description });
                }
            } else {
                try self.log("Error: unknown name '{s}' for {s}\n", .{ actual_name, name });
                return Error.UnknownComponent;
            }

            return;
        }
    }.func;
}

fn componentCreate(self: *Cli, component: type, name: []const u8, cargs: []const []const u8) anyerror!component {
    const cname, const cmap = self.componentGetPair(component);
    const factory = cmap.get(name) orelse {
        if (name.len == 0) {
            var buffer: [32]u8 = undefined;
            const lower_cname = std.ascii.lowerString(buffer[0..], cname);
            try self.log("Error: missing -{s} argument\n", .{lower_cname});
            return Error.MissingArgument;
        }
        try self.log("Error: unknown {s}: '{s}'\n", .{ cname, name });
        return Error.UnknownComponent;
    };

    var fargs_map = ArgumentMap.init(self.allocator);
    defer fargs_map.deinit();

    const fargs = blk: {
        const default_fargs = factory.getArguments();
        const fargs = try self.allocator.alloc(ds.Argument, default_fargs.len);
        errdefer self.allocator.free(fargs);
        for (0..default_fargs.len) |i| {
            fargs[i] = default_fargs[i];
            try fargs_map.put(fargs[i].name, &fargs[i]);
        }
        break :blk fargs;
    };
    defer self.allocator.free(fargs);

    for (cargs) |carg| {
        if (std.mem.indexOfScalar(u8, carg, '=')) |idx| {
            const aname = carg[0..idx];
            const avalue = carg[idx + 1 ..];
            if (fargs_map.get(aname)) |arg_ptr| {
                _ = fargs_map.remove(aname);
                switch (arg_ptr.value) {
                    .u => |*u| {
                        u.* = std.fmt.parseInt(usize, avalue, 10) catch {
                            try self.log("Error: invalid {s} argument '{s}': it must be a non-negative integer, got '{s}'\n", .{ cname, aname, avalue });
                            return Error.InvalidArgument;
                        };
                    },
                    .i => |*i| {
                        i.* = std.fmt.parseInt(isize, avalue, 10) catch {
                            try self.log("Error: invalid {s} argument '{s}': it must be an integer, got '{s}'\n", .{ cname, aname, avalue });
                            return Error.InvalidArgument;
                        };
                    },
                    .f => |*f| {
                        f.* = std.fmt.parseFloat(f64, avalue) catch {
                            try self.log("Error: invalid {s} argument '{s}': it must be a float, got '{s}'\n", .{ cname, aname, avalue });
                            return Error.InvalidArgument;
                        };
                    },
                    .s => |*s| {
                        s.* = avalue;
                    },
                }
            } else {
                try self.log("Error: unknown {s} argument '{s}'\n", .{ cname, aname });
                return Error.UnknownArgument;
            }
        } else {
            try self.log("Error: invalid {s} argument '{s}': it must be in the format 'name=value'\n", .{ cname, carg });
            return Error.InvalidArgument;
        }
    }
    var iter = fargs_map.keyIterator();
    while (iter.next()) |key| {
        try self.log("Error: missing {s} argument '{s}'\n", .{ cname, key.* });
        return Error.MissingArgument;
    }

    return factory.init(self.allocator, fargs);
}

fn run(self: *Cli) anyerror!void {
    const usage =
        \\ Usage: {0s} {1s} [arguments] [options]
        \\
        \\ Arguments:
        \\   -ode <ode-name>                                            Name of the ODE to simulate.
        \\   -ode-arg <name=value> [-ode-arg <name=value> ...]          Arguments for the ODE.
        \\   -t <float>                                                 Initial time.
        \\   -x <float> [-x <float> ...]                                Initial state values.
        \\   -p <float> [-p <float> ...]                                Initial parameter values.
        \\   -solver <solver-name>                                      Name of the solver to use.
        \\   -solver-arg <name=value> [-solver-arg <name=value> ...]    Arguments for the solver.
        \\   -job <job-name>                                            Name of the job to run.
        \\   -job-arg <name=value> [-job-arg <name=value> ...]          Arguments for the job.
        \\
        \\ Output Options:
        \\   --float-precision <integer>                                Number of decimal places to use for floating point numbers.
        \\   --float-mode <mode>                                        Mode to use for floating point numbers.
        \\   --separator <character>                                    Separator to use for output.
        \\   --file <path>                                              Path to the file to write the output to.
        \\
        \\ Global Options:
        \\   -h,  --help                                                Show usage message and exit.
        \\
        \\ Example:
        \\   {0s} {1s} \
        \\      -ode linear -ode-arg n=2 \
        \\      -t 0 \
        \\      -x 0 -x 1 \
        \\      -p 0 -p 1 -p -1 -p 0 \
        \\      -solver rk4 -solver-arg h_max=0.01 \
        \\      -job portrait -job-arg t_step=0.1 -job-arg t_start=0.0 -job-arg t_end=10.0
        \\
    ;

    var ode_name: []const u8 = &.{};
    var ode_args: []const []const u8 = &.{};
    var ode_t: []const u8 = &.{};
    var ode_x: []const []const u8 = &.{};
    var ode_p: []const []const u8 = &.{};
    var solver_name: []const u8 = &.{};
    var solver_args: []const []const u8 = &.{};
    var job_name: []const u8 = &.{};
    var job_args: []const []const u8 = &.{};

    var float_precision: []const u8 = "5";
    var float_mode: []const u8 = "decimal";
    var separator: []const u8 = " ";
    var file: []const u8 = "";

    var parser = try ArgParser.init(
        self.allocator,
        &.{
            .{ .name = "-ode", .ptr = .{ .str = &ode_name } },
            .{ .name = "-ode-arg", .ptr = .{ .list = &ode_args } },
            .{ .name = "-t", .ptr = .{ .str = &ode_t } },
            .{ .name = "-x", .ptr = .{ .list = &ode_x } },
            .{ .name = "-p", .ptr = .{ .list = &ode_p } },
            .{ .name = "-solver", .ptr = .{ .str = &solver_name } },
            .{ .name = "-solver-arg", .ptr = .{ .list = &solver_args } },
            .{ .name = "-job", .ptr = .{ .str = &job_name } },
            .{ .name = "-job-arg", .ptr = .{ .list = &job_args } },
            .{ .name = "--float-precision", .ptr = .{ .str = &float_precision } },
            .{ .name = "--float-mode", .ptr = .{ .str = &float_mode } },
            .{ .name = "--separator", .ptr = .{ .str = &separator } },
            .{ .name = "--file", .ptr = .{ .str = &file } },
        },
    );
    defer parser.deinit();

    parser.parse(self.args.items[2..]) catch |err| switch (err) {
        ArgParser.Error.HelpRequested => {
            try self.log(usage, .{ self.args.items[0], self.args.items[1] });
            return;
        },
        else => return err,
    };
    var ode = try self.componentCreate(Ode, ode_name, ode_args);
    defer ode.deinit();
    if (ode_t.len == 0) {
        try self.log("Error: missing -t option\n", .{});
        return Error.MissingArgument;
    }
    if (ode.getXDim() != ode_x.len) {
        try self.log("Error: expected {d} initial state values, got {d}\n", .{ ode.getXDim(), ode_x.len });
        return Error.InvalidArgument;
    }
    if (ode.getPDim() != ode_p.len) {
        try self.log("Error: expected {d} parameter values, got {d}\n", .{ ode.getPDim(), ode_p.len });
        return Error.InvalidArgument;
    }
    ode.setT(std.fmt.parseFloat(f64, ode_t) catch {
        try self.log("Error: invalid -t value: expected a float, got '{s}'\n", .{ode_t});
        return Error.InvalidArgument;
    });
    for (0..ode.getXDim()) |i| {
        ode.setX(i, std.fmt.parseFloat(f64, ode_x[i]) catch {
            try self.log("Error: invalid -x value: expected a float, got '{s}'\n", .{ode_x[i]});
            return Error.InvalidArgument;
        });
    }
    for (0..ode.getPDim()) |i| {
        ode.setP(i, std.fmt.parseFloat(f64, ode_p[i]) catch {
            try self.log("Error: invalid -p value: expected a float, got '{s}'\n", .{ode_p[i]});
            return Error.InvalidArgument;
        });
    }

    var solver = try self.componentCreate(Solver, solver_name, solver_args);
    defer solver.deinit();

    var job = try self.componentCreate(Job, job_name, job_args);
    defer job.deinit();

    const job_options = Job.Options{
        .separator = blk: {
            if (separator.len != 1) {
                try self.log("Error: invalid --separator value: expected a single character, got '{s}'\n", .{separator});
                return Error.InvalidArgument;
            }
            break :blk separator[0];
        },
        .float = .{ .precision = std.fmt.parseInt(usize, float_precision, 10) catch {
            try self.log("Error: invalid --float-precision value: expected a non-negative integer, got '{s}'\n", .{float_precision});
            return Error.InvalidArgument;
        }, .mode = blk: {
            if (std.mem.eql(u8, float_mode, "decimal")) break :blk .decimal;
            if (std.mem.eql(u8, float_mode, "scientific")) break :blk .scientific;
            try self.log("Error: invalid --float-mode value: expected 'decimal' or 'scientific', got '{s}'\n", .{float_mode});
            return Error.InvalidArgument;
        } },
    };
    if (std.mem.eql(u8, file, "-")) {
        var buffer: [4096]u8 = undefined;
        var stdout_file = File.stdout();
        defer stdout_file.close(self.init.io);
        var stdout_writer = stdout_file.writer(self.init.io, buffer[0..]);
        defer stdout_writer.flush() catch {};

        try job.run(&solver, &ode, &stdout_writer.interface, job_options);
        return;
    }

    const cwd = Dir.cwd();
    var buffer: [4096]u8 = undefined;
    if (file.len == 0) {
        var w = std.Io.Writer.fixed(&buffer);
        try w.print("{s}", .{ode_name});
        if (ode_args.len > 0) {
            try w.print("({s}", .{ode_args[0]});
            for (ode_args[1..]) |arg| {
                try w.print("_{s}", .{arg});
            }
            try w.print(")", .{});
        }
        try w.print("{c}", .{std.fs.path.sep});
        if (ode_p.len > 0) {
            try w.print("p=(", .{});
            try w.print("{s}", .{ode_p[0]});
            for (ode_p[1..]) |arg| {
                try w.print(",{s}", .{arg});
            }
            try w.print(")", .{});
        }
        try w.print("t=({s})", .{ode_t});
        try w.print("x=({s}", .{ode_x[0]});
        for (ode_x[1..]) |arg| {
            try w.print(",{s}", .{arg});
        }
        try w.print("){s}.txt", .{job_name});

        file = buffer[0..w.end];
    }

    if (Dir.path.dirname(file)) |dir| {
        try cwd.createDirPath(self.init.io, dir);
    }

    var f = try cwd.createFile(self.init.io, file, .{});
    defer f.close(self.init.io);
    var fw = f.writer(self.init.io, buffer[0..]);
    defer fw.flush() catch {};

    try job.run(&solver, &ode, &fw.interface, job_options);
}

// fn getOdeDimensions() anyerror!void {
//     const padding: [32]u8 = @splat(' ');

//     var ode_name: []const u8 = &.{};
//     var ode_args: []const []const u8 = &.{};

//     var parser = try ArgParser.init(
//         allocator,
//         &.{
//             .{ .name = "-ode", .ptr = .{ .str = &ode_name } },
//             .{ .name = "-ode-arg", .ptr = .{ .list = &ode_args } },
//         },
//     );
//     defer parser.deinit();

//     parser.parse(args[2..]) catch |err| switch (err) {
//         ArgParser.Error.HelpRequested => {
//             try stdout.print("Usage: {s} {s} [arguments] [options]\n", .{ args[0], args[1] });
//             try stdout.print("\n", .{});
//             try stdout.print("Arguments:\n", .{});
//             for ([_]NameAndDescription{
//                 .{ .name = "-ode <ode-name>", .description = "ODE to get dimensions for." },
//                 .{ .name = "-ode-arg <name=value>", .description = "ODE argument. This is a list of 'name=value' pairs.\n" },
//             }) |arg| {
//                 try stdout.print("  {s}{s}{s}\n", .{ arg.name, padding[0 .. padding.len - arg.name.len], arg.description });
//             }

//             try stdout.print("General Options:\n", .{});
//             for ([_]NameAndDescription{
//                 .{ .name = "-h,  --help", .description = "Show usage message and exit" },
//             }) |arg| {
//                 try stdout.print("  {s}{s}{s}\n", .{ arg.name, padding[0 .. padding.len - arg.name.len], arg.description });
//             }

//             return;
//         },
//         else => return err,
//     };

//     var ode = try createComponent(Ode, ode_name, ode_args);
//     defer ode.deinit();

//     try stdout.print("Dimensions for '{s}':\n", .{ode_name});
//     try stdout.print("  phase dimension (x): {d}\n", .{ode.getXDim()});
//     try stdout.print("  parameter dimension (p): {d}\n", .{ode.getPDim()});
//     return;
// }

// fn loadCommands() !void {
//     try commands.put("list-odes", listComponents(Ode));
//     try commands.put("list-solvers", listComponents(Solver));
//     try commands.put("list-jobs", listComponents(Job));
//     try commands.put("get-ode-args", getComponentArguments(Ode));
//     try commands.put("get-solver-args", getComponentArguments(Solver));
//     try commands.put("get-job-args", getComponentArguments(Job));
//     try commands.put("run", run);
//     try commands.put("get-ode-dimensions", getOdeDimensions);
// }

// fn printUsage() !void {
//     const padding: [32]u8 = @splat(' ');

//     try stdout.print("Usage: {s} <command> [options]\n", .{args[0]});
//     try stdout.print("\n", .{});

//     try stdout.print("Commands:\n", .{});

//     for ([_]NameAndDescription{
//         .{ .name = "run", .description = "Run a dynamical system simulation\n" },
//         .{ .name = "get-ode-dimensions", .description = "Get dimensions for an ODE\n" },
//         .{ .name = "list-odes", .description = "List available ODEs" },
//         .{ .name = "list-solvers", .description = "List available solvers" },
//         .{ .name = "list-jobs", .description = "List available jobs\n" },
//         .{ .name = "get-ode-args", .description = "Get arguments for an ODE" },
//         .{ .name = "get-solver-args", .description = "Get arguments for a solver" },
//         .{ .name = "get-job-args", .description = "Get arguments for a job\n" },
//     }) |cnd| {
//         try stdout.print("  {s}{s}{s}\n", .{ cnd.name, padding[0 .. padding.len - cnd.name.len], cnd.description });
//     }

//     try stdout.print("General Options:\n", .{});
//     for ([_]NameAndDescription{
//         .{ .name = "-h,  --help", .description = "Show usage message and exit" },
//     }) |arg| {
//         try stdout.print("  {s}{s}{s}\n", .{ arg.name, padding[0 .. padding.len - arg.name.len], arg.description });
//     }
// }

// pub fn main(init: *std.process.Init) !void {
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//     allocator = arena.allocator();

//     const stdout_file = std.fs.File.stdout();
//     var stdout_buffer: [4096]u8 = undefined;
//     var stdout_fw = std.fs.File.writer(stdout_file, stdout_buffer[0..]);
//     stdout = &stdout_fw.interface;
//     defer stdout.flush() catch {};

//     const stderr_file = std.fs.File.stderr();
//     var stderr_buffer: [4096]u8 = undefined;
//     var stderr_fw = std.fs.File.writer(stderr_file, stderr_buffer[0..]);
//     stderr = &stderr_fw.interface;
//     defer stderr.flush() catch {};

//     var arg_list = try std.ArrayList([]const u8).initCapacity(allocator, 64);
//     defer arg_list.deinit(allocator);

//     var arg_iterator = try std.process.argsWithAllocator(allocator);
//     defer arg_iterator.deinit();

//     while (arg_iterator.next()) |arg| {
//         try arg_list.append(allocator, arg);
//     }
//     args = arg_list.items;

//     dyn_libs = try DynLibs.initCapacity(allocator, 8);
//     defer {
//         for (dyn_libs.items) |*lib| {
//             lib.close();
//         }
//         dyn_libs.deinit(allocator);
//     }

//     commands = CommandMap.init(allocator);
//     defer commands.deinit();
//     odes = OdeMap.init(allocator);
//     defer {
//         var iter = odes.keyIterator();
//         while (iter.next()) |key| {
//             allocator.free(key.*);
//         }
//         odes.deinit();
//     }
//     solvers = SolverMap.init(allocator);
//     defer {
//         var iter = solvers.keyIterator();
//         while (iter.next()) |key| {
//             allocator.free(key.*);
//         }
//         solvers.deinit();
//     }
//     jobs = JobMap.init(allocator);
//     defer {
//         var iter = jobs.keyIterator();
//         while (iter.next()) |key| {
//             allocator.free(key.*);
//         }
//         jobs.deinit();
//     }

//     try loadCommands();
//     try loadComponent(Ode);
//     try loadComponent(Solver);
//     try loadComponent(Job);

//     if (args.len < 2) {
//         try stderr.print("Error: missing command\n", .{});
//         return Error.MissingCommand;
//     }

//     const command = commands.get(args[1]) orelse {
//         if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help")) {
//             try printUsage();
//             return;
//         }
//         try stderr.print("Error: unknown command: '{s}'\n", .{args[1]});
//         return Error.UnknownCommand;
//     };

//     return try command();
// }

// test {
//     _ = ArgParser;
// }
