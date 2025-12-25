const std = @import("std");
const ds = @import("dynamical_systems");

const ArgParser = @import("cli/ArgParser.zig");
const DynLib = std.DynLib;
const StringHashMap = std.StringHashMap;

const Ode = ds.ode.Ode;
const Solver = ds.solver.Solver;
const Job = ds.job.Job;

const DynLibs = std.ArrayList(DynLib);
const ArgumentMap = StringHashMap(*ds.Argument);

const CommandMap = StringHashMap(*const fn () anyerror!void);
const OdeMap = StringHashMap(*const Ode.Factory);
const SolverMap = StringHashMap(*const Solver.Factory);
const JobMap = StringHashMap(*const Job.Factory);

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

var allocator: std.mem.Allocator = undefined;
var stdout: *std.Io.Writer = undefined;
var stderr: *std.Io.Writer = undefined;

var dyn_libs: DynLibs = undefined;
var args: []const []const u8 = undefined;

var commands: CommandMap = undefined;
var odes: OdeMap = undefined;
var solvers: SolverMap = undefined;
var jobs: JobMap = undefined;

fn getComponentPair(component: type) struct { name: []const u8, map: *StringHashMap(*const component.Factory) } {
    return switch (component) {
        Ode => .{ .name = "ODE", .map = &odes },
        Solver => .{ .name = "Solver", .map = &solvers },
        Job => .{ .name = "Job", .map = &jobs },
        else => @compileError("Unknown component type: " ++ @typeName(component)),
    };
}

fn loadComponent(component: type) !void {
    const cwd = std.fs.cwd();

    const pair = getComponentPair(component);
    const component_name = pair.name;
    const map = pair.map;

    const bin_dir = try std.fs.selfExeDirPathAlloc(allocator);
    defer allocator.free(bin_dir);

    const app_dir = std.fs.path.dirname(bin_dir) orelse return Error.UnexpectedAppPath;

    const lib_path = try std.fs.path.join(allocator, &.{ app_dir, "lib", component_name });
    defer allocator.free(lib_path);

    var dir = cwd.openDir(lib_path, .{}) catch |err| {
        try stderr.print("Error opening directory '{s}': {s}\n", .{ lib_path, @errorName(err) });
        return;
    };
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file) {
            const file_path = try std.fs.path.join(allocator, &.{ lib_path, entry.name });
            defer allocator.free(file_path);

            var lib = DynLib.open(file_path) catch |err| {
                try stderr.print("Error loading {s} library '{s}': {s}\n", .{ component_name, entry.name, @errorName(err) });
                return;
            };
            try dyn_libs.append(allocator, lib);

            const factory_ = lib.lookup(*const *const component.Factory, "factory");
            if (factory_) |factory| {
                var name = entry.name;
                if (std.mem.eql(u8, name[0..3], "lib")) name = name[3..];
                if (std.mem.lastIndexOf(u8, name, ".")) |dot_idx| name = name[0..dot_idx];
                var factory_name = try allocator.dupe(u8, name);
                factory_name = std.ascii.lowerString(factory_name, factory_name);
                try map.put(factory_name, factory.*);
            } else {
                try stderr.print("Error loading {s} library '{s}': factory not found\n", .{ component_name, entry.name });
                return;
            }
        }
    }
}

fn listComponents(component: type) fn () anyerror!void {
    return struct {
        fn func() !void {
            const pair = comptime getComponentPair(component);
            const name = pair.name;
            const map = pair.map;

            var idx: usize = 1;
            var iter = map.keyIterator();
            if (iter.len == 0) {
                try stdout.print("No available {s}s\n", .{name});
                return;
            }
            try stdout.print("Available {s}s:\n", .{name});
            while (iter.next()) |key| : (idx += 1) {
                try stdout.print("  {d}. {s}\n", .{ idx, key.* });
            }
        }
    }.func;
}

fn getComponentArguments(component: type) fn () anyerror!void {
    return struct {
        fn func() !void {
            const padding: [32]u8 = @splat(' ');
            const pair = comptime getComponentPair(component);
            var component_name: []const u8 = "";

            var parser = try ArgParser.init(
                allocator,
                &.{
                    .{ .name = pair.name, .ptr = .{ .str = &component_name } },
                },
            );
            defer parser.deinit();

            parser.parse(args[2..]) catch |err| switch (err) {
                ArgParser.Error.HelpRequested => {
                    var buffer: [32]u8 = undefined;
                    const name = std.ascii.lowerString(buffer[0..], pair.name);
                    try stdout.print("Usage: {s} {s} <{s}-name>\n", .{ args[0], args[1], name });
                    // try stdout.print("\n", .{});
                    // try stdout.print("Global Options:\n", .{});
                    // const options = "-h,  --help";
                    // const description = "Show usage message and exit";
                    // try stdout.print("  {s}{s}{s}\n", .{ options, padding[0 .. padding.len - options.len], description });
                    return;
                },
                else => return err,
            };

            if (pair.map.get(component_name)) |factory| {
                const cargs = factory.getArguments();
                if (cargs.len == 0) {
                    try stdout.print("'{s}' has no arguments\n", .{component_name});
                    return;
                }
                try stdout.print("Arguments for {s}:\n", .{component_name});
                for (cargs, 1..) |carg, idx| {
                    const type_slug = switch (carg.value) {
                        .u => "<integer>",
                        .i => "<integer>",
                        .f => "<float>",
                        .s => "<string>",
                    };
                    try stdout.print("  {d}. {s} {s} {s}{s}\n", .{ idx, carg.name, type_slug, padding[0 .. padding.len - carg.name.len - type_slug.len - 3], carg.description });
                }
            } else {
                try stderr.print("Error: unknown {s}: '{s}'\n", .{ pair.name, component_name });
                return Error.UnknownComponent;
            }

            return;
        }
    }.func;
}

fn createComponent(component: type, name: []const u8, cargs: []const []const u8) anyerror!component {
    const pair = getComponentPair(component);
    const factory = pair.map.get(name) orelse {
        try stderr.print("Error: unknown {s}: '{s}'\n", .{ pair.name, name });
        return Error.UnknownComponent;
    };

    var arg_map = ArgumentMap.init(allocator);
    defer arg_map.deinit();

    const fargs = factory.getArguments();
    const iargs = try allocator.alloc(ds.Argument, fargs.len);
    defer allocator.free(iargs);

    for (0..iargs.len) |i| {
        iargs[i] = fargs[i];
        try arg_map.put(iargs[i].name, &iargs[i]);
    }

    for (cargs) |carg| {
        if (std.mem.indexOfScalar(u8, carg, '=')) |idx| {
            const aname = carg[0..idx];
            const avalue = carg[idx + 1 ..];
            if (arg_map.get(aname)) |arg_ptr| {
                _ = arg_map.remove(aname);
                switch (arg_ptr.value) {
                    .u => |*u| {
                        u.* = std.fmt.parseInt(usize, avalue, 10) catch {
                            try stderr.print("Error: invalid {s} argument '{s}': it must be a non-negative integer, got '{s}'\n", .{ pair.name, aname, avalue });
                            return Error.InvalidArgument;
                        };
                    },
                    .i => |*i| {
                        i.* = std.fmt.parseInt(isize, avalue, 10) catch {
                            try stderr.print("Error: invalid {s} argument '{s}': it must be an integer, got '{s}'\n", .{ pair.name, aname, avalue });
                            return Error.InvalidArgument;
                        };
                    },
                    .f => |*f| {
                        f.* = std.fmt.parseFloat(f64, avalue) catch {
                            try stderr.print("Error: invalid {s} argument '{s}': it must be a float, got '{s}'\n", .{ pair.name, aname, avalue });
                            return Error.InvalidArgument;
                        };
                    },
                    .s => |*s| {
                        s.* = avalue;
                    },
                }
            } else {
                try stderr.print("Error: unknown {s} argument '{s}'\n", .{ pair.name, aname });
                return Error.UnknownArgument;
            }
        } else {
            try stderr.print("Error: invalid {s} argument '{s}': it must be in the format 'name=value'\n", .{ pair.name, carg });
            return Error.InvalidArgument;
        }
    }
    var iter = arg_map.keyIterator();
    while (iter.next()) |key| {
        try stderr.print("Error: missing {s} argument '{s}'\n", .{ pair.name, key.* });
        return Error.MissingArgument;
    }

    return factory.init(allocator, iargs);
}

fn run() anyerror!void {
    const padding: [32]u8 = @splat(' ');

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
        allocator,
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

    parser.parse(args[2..]) catch |err| switch (err) {
        ArgParser.Error.HelpRequested => {
            try stdout.print("Usage: {s} {s} [arguments] [options]\n", .{ args[0], args[1] });
            try stdout.print("\n", .{});

            try stdout.print("Arguments:\n", .{});
            for ([_]struct { name: []const u8, description: []const u8 }{
                .{ .name = "-ode <ode-name>", .description = "ODE to solve." },
                .{ .name = "-ode-arg <name=value>", .description = "ODE argument. This is a list of 'name=value' pairs." },
                .{ .name = "-t <float>", .description = "ODE's initial time." },
                .{ .name = "-x <float>", .description = "ODE's initial state vector. This is a list of floats." },
                .{ .name = "-p <float>", .description = "ODE's parameter vector. This is a list of floats.\n" },
                .{ .name = "-solver <solver-name>", .description = "Solver to use." },
                .{ .name = "-solver-arg <name=value>", .description = "Solver argument. This is a list of 'name=value' pairs.\n" },
                .{ .name = "-job <job-name>", .description = "Job to run." },
                .{ .name = "-job-arg <name=value>", .description = "Job argument. This is a list of 'name=value' pairs.\n" },
            }) |arg| {
                try stdout.print("  {s}{s}{s}\n", .{ arg.name, padding[0 .. padding.len - arg.name.len], arg.description });
            }

            try stdout.print("Output Options:\n", .{});
            for ([_]struct { name: []const u8, description: []const u8 }{
                .{ .name = "--float-precision <precision>", .description = "Float precision. Default is 5." },
                .{ .name = "--float-mode <mode>", .description = "Float mode. Possible values are 'decimal' and 'scientific'. Default is decimal." },
                .{ .name = "--separator <character>", .description = "Separator character. Default is space." },
                .{ .name = "--file <path>", .description = "Output file path. Default is '<ode-name>/<job-name>.txt'. Specify '-' to output to stdout.\n" },
            }) |arg| {
                try stdout.print("  {s}{s}{s}\n", .{ arg.name, padding[0 .. padding.len - arg.name.len], arg.description });
            }

            try stdout.print("Global Options:\n", .{});
            const options = "-h,  --help";
            const description = "Show usage message and exit";
            try stdout.print("  {s}{s}{s}\n", .{ options, padding[0 .. padding.len - options.len], description });

            try stdout.print("\n", .{});
            try stdout.print("Usage example:\n", .{});
            try stdout.print("{s} {s} \\\n", .{ args[0], args[1] });
            try stdout.print("  -ode linear \\\n", .{});
            try stdout.print("  -ode-arg n=2 \\\n", .{});
            try stdout.print("  -t 0 \\\n", .{});
            try stdout.print("  -x 0 -x 1 \\\n", .{});
            try stdout.print("  -p 0 -p 1 -p -1 -p 0 \\\n", .{});
            try stdout.print("  -solver rk4 \\\n", .{});
            try stdout.print("  -solver-arg h_max=0.01 \\\n", .{});
            try stdout.print("  -job portrait \\\n", .{});
            try stdout.print("  -job-arg t_step=0.1 -job-arg t_end=10.0 \n", .{});
            try stdout.print("\n", .{});

            return;
        },
        else => return err,
    };
    if (ode_name.len == 0) {
        try stderr.print("Error: missing -ode option\n", .{});
        return Error.MissingArgument;
    }
    var ode = try createComponent(Ode, ode_name, ode_args);
    defer ode.deinit();
    if (ode_t.len == 0) {
        try stderr.print("Error: missing -t option\n", .{});
        return Error.MissingArgument;
    }
    if (ode.getXDim() != ode_x.len) {
        try stderr.print("Error: expected {d} initial state values, got {d}\n", .{ ode.getXDim(), ode_x.len });
        return Error.InvalidArgument;
    }
    if (ode.getPDim() != ode_p.len) {
        try stderr.print("Error: expected {d} parameter values, got {d}\n", .{ ode.getPDim(), ode_p.len });
        return Error.InvalidArgument;
    }
    ode.setT(std.fmt.parseFloat(f64, ode_t) catch {
        try stderr.print("Error: invalid -t value: expected a float, got '{s}'\n", .{ode_t});
        return Error.InvalidArgument;
    });
    for (0..ode.getXDim()) |i| {
        ode.setX(i, std.fmt.parseFloat(f64, ode_x[i]) catch {
            try stderr.print("Error: invalid -x value: expected a float, got '{s}'\n", .{ode_x[i]});
            return Error.InvalidArgument;
        });
    }
    for (0..ode.getPDim()) |i| {
        ode.setP(i, std.fmt.parseFloat(f64, ode_p[i]) catch {
            try stderr.print("Error: invalid -p value: expected a float, got '{s}'\n", .{ode_p[i]});
            return Error.InvalidArgument;
        });
    }

    if (solver_name.len == 0) {
        try stderr.print("Error: missing -solver option\n", .{});
        return Error.MissingArgument;
    }
    var solver = try createComponent(Solver, solver_name, solver_args);
    defer solver.deinit();

    if (job_name.len == 0) {
        try stderr.print("Error: missing -job option\n", .{});
        return Error.MissingArgument;
    }
    var job = try createComponent(Job, job_name, job_args);
    defer job.deinit();

    const job_options = Job.Options{
        .separator = blk: {
            if (separator.len != 1) {
                try stderr.print("Error: invalid --separator value: expected a single character, got '{s}'\n", .{separator});
                return Error.InvalidArgument;
            }
            break :blk separator[0];
        },
        .float = .{ .precision = std.fmt.parseInt(usize, float_precision, 10) catch {
            try stderr.print("Error: invalid --float-precision value: expected a non-negative integer, got '{s}'\n", .{float_precision});
            return Error.InvalidArgument;
        }, .mode = blk: {
            if (std.mem.eql(u8, float_mode, "decimal")) break :blk .decimal;
            if (std.mem.eql(u8, float_mode, "scientific")) break :blk .scientific;
            try stderr.print("Error: invalid --float-mode value: expected 'decimal' or 'scientific', got '{s}'\n", .{float_mode});
            return Error.InvalidArgument;
        } },
    };
    if (std.mem.eql(u8, file, "-")) {
        try job.run(&solver, &ode, stdout, job_options);
        return;
    }

    const cwd = std.fs.cwd();
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

    if (std.fs.path.dirname(file)) |dir| {
        try cwd.makePath(dir);
    }

    var f = try cwd.createFile(file, .{});
    defer f.close();
    var fw = std.fs.File.writer(f, &buffer);
    const w = &fw.interface;
    defer w.flush() catch {};

    try job.run(&solver, &ode, w, job_options);
}

fn loadCommands() !void {
    try commands.put("list-odes", listComponents(Ode));
    try commands.put("list-solvers", listComponents(Solver));
    try commands.put("list-jobs", listComponents(Job));
    try commands.put("get-ode-args", getComponentArguments(Ode));
    try commands.put("get-solver-args", getComponentArguments(Solver));
    try commands.put("get-job-args", getComponentArguments(Job));
    try commands.put("run", run);
}

fn printUsage() !void {
    const CommandAndDescription = struct {
        command: []const u8,
        description: []const u8 = "",
    };

    const padding: [32]u8 = @splat(' ');

    try stdout.print("Usage: {s} <command> [options]\n", .{args[0]});
    try stdout.print("\n", .{});

    try stdout.print("Commands:\n", .{});

    for ([_]CommandAndDescription{
        .{ .command = "run", .description = "Run a dynamical system simulation\n" },
        .{ .command = "list-odes", .description = "List available ODEs" },
        .{ .command = "list-solvers", .description = "List available solvers" },
        .{ .command = "list-jobs", .description = "List available jobs\n" },
        .{ .command = "get-ode-args", .description = "Get arguments for an ODE" },
        .{ .command = "get-solver-args", .description = "Get arguments for a solver" },
        .{ .command = "get-job-args", .description = "Get arguments for a job\n" },
    }) |cnd| {
        try stdout.print("  {s}{s}{s}\n", .{ cnd.command, padding[0 .. padding.len - cnd.command.len], cnd.description });
    }

    try stdout.print("General Options:\n", .{});
    const options = "-h,  --help";
    const description = "Show usage message and exit";
    try stdout.print("  {s}{s}{s}\n", .{ options, padding[0 .. padding.len - options.len], description });
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    allocator = arena.allocator();

    const stdout_file = std.fs.File.stdout();
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_fw = std.fs.File.writer(stdout_file, stdout_buffer[0..]);
    stdout = &stdout_fw.interface;
    defer stdout.flush() catch {};

    const stderr_file = std.fs.File.stderr();
    var stderr_buffer: [4096]u8 = undefined;
    var stderr_fw = std.fs.File.writer(stderr_file, stderr_buffer[0..]);
    stderr = &stderr_fw.interface;
    defer stderr.flush() catch {};

    var arg_list = try std.ArrayList([]const u8).initCapacity(allocator, 64);
    defer arg_list.deinit(allocator);

    var arg_iterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();

    while (arg_iterator.next()) |arg| {
        try arg_list.append(allocator, arg);
    }
    args = arg_list.items;

    dyn_libs = try DynLibs.initCapacity(allocator, 8);
    defer {
        for (dyn_libs.items) |*lib| {
            lib.close();
        }
        dyn_libs.deinit(allocator);
    }

    commands = CommandMap.init(allocator);
    defer commands.deinit();
    odes = OdeMap.init(allocator);
    defer {
        var iter = odes.keyIterator();
        while (iter.next()) |key| {
            allocator.free(key.*);
        }
        odes.deinit();
    }
    solvers = SolverMap.init(allocator);
    defer {
        var iter = solvers.keyIterator();
        while (iter.next()) |key| {
            allocator.free(key.*);
        }
        solvers.deinit();
    }
    jobs = JobMap.init(allocator);
    defer {
        var iter = jobs.keyIterator();
        while (iter.next()) |key| {
            allocator.free(key.*);
        }
        jobs.deinit();
    }

    try loadCommands();
    try loadComponent(Ode);
    try loadComponent(Solver);
    try loadComponent(Job);

    if (args.len < 2) {
        try stderr.print("Error: missing command\n", .{});
        return Error.MissingCommand;
    }

    const command = commands.get(args[1]) orelse {
        if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help")) {
            try printUsage();
            return;
        }
        try stderr.print("Error: unknown command: '{s}'\n", .{args[1]});
        return Error.UnknownCommand;
    };

    return try command();
}

test {
    _ = ArgParser;
}
