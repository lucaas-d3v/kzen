const std = @import("std");
const Io = std.Io;
const colors = @import("./ui/color.zig");

// utilitys
const checker = @import("./utils/checker.zig");
const kz_writer = @import("./utils/kz_writer.zig");

// flags
const version = @import("./flags/version.zig");
const help = @import("./flags/help.zig");

// commands
const cut = @import("./commands/cut.zig");
const info = @import("./commands/info.zig");
const filter = @import("./commands/filter.zig");

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
            // +1 because of the 'cut' argument
            cut.cut(&init, alloc, writer.stdout, args[i + 1 ..]) catch |err| {
                switch (err) {
                    error.ProcessFailed => return 1,
                    else => {
                        try help.helpCut(writer.stderr);
                        return 1;
                    },
                }
            };

            return 0;
        }

        if (checker.argEql(arg, "info")) {
            // +1 because of the 'info' argument
            info.info(&init, writer.stdout, args[i + 1 ..]) catch {
                try help.helpInfo(writer.stderr);
                return 1;
            };

            return 0;
        }

        if (checker.argEql(arg, "filter")) {
            // +1 because of the 'filter' argument
            filter.filter(&init, writer.stdout, args[i + 1 ..]) catch {
                try help.helpFilter(writer.stderr);
                return 1;
            };

            return 0;
        }

        // print help in stderr
        try help.help(writer.stderr);
        try writer.stderr.print("\n{s}Unknown command{s}: '{s}'\n", .{ colors.ERROR, colors.RESET, arg });
        return 1;
    }

    try help.help(writer.stdout);
    return 0;
}
