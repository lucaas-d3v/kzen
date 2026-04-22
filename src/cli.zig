const std = @import("std");
const Io = std.Io;

// utilitys
const checker = @import("./utils/checker.zig");
const kz_writer = @import("./utils/kz_writer.zig");

// flags
const version = @import("./flags/version.zig");
const help = @import("./flags/help.zig");

// commands
const cut = @import("./commands/cut.zig");

pub fn cli(init: std.process.Init) !u8 {
    const alloc = init.arena.allocator();

    const writer = try kz_writer.KzWriter.init(init);

    defer writer.flush() catch {};

    const args_origin = try init.minimal.args.toSlice(alloc);

    const args = if (args_origin.len > 1) args_origin[1..] else &[_][]const u8{"err"};

    // if no arguments have been passed, it shows help and exits
    if (checker.argEql(args[0], "err")) {
        try help.help(writer.stderr);
        return 1;
    }

    var i: u8 = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        // flags
        if (checker.flagsEql(arg, &.{ "-h", "--help" })) {
            try help.help(writer.stdout);
            return 0;
        }

        if (checker.flagsEql(arg, &.{ "-v", "--version" })) {
            try version.version(writer.stdout);
            return 0;
        }

        // commands
        if (checker.argEql(arg, "cut")) {
            try cut.cut(writer.stdout, args[i + 1 ..]); // +1 because of the 'cut' argument
            return 0;
        }

        // print help in stderr
        try help.help(writer.stderr);
        try writer.stderr.print("\nUnknown command: '{s}'\n", .{arg});
        return 1;
    }

    try help.help(writer.stdout);
    return 0;
}
