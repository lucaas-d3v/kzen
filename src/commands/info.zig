const std = @import("std");

const styles = @import("../ui/styles.zig");
const colors = @import("../ui/color.zig");
const checker = @import("../utils/checker.zig");
const help = @import("../flags/help.zig");

pub fn info(init: std.process.Init, writer: *std.Io.Writer, args: []const []const u8) !void {
    const maybe_flags = try parseInfoFlagsFromArgs(writer, args);
    const info_flags = maybe_flags orelse return;

    // basic validate
    if (!(try checker.validadeVideoFile(info_flags.input_file))) {
        try writer.print("\n{s}{s}Error{s}: The info command need a media input file (e.g .mp4).\n", .{ styles.BOLD, colors.ERROR, colors.RESET });
        return error.NoInputFile;
    }

    const alloc = init.arena.allocator();
    const ffmpeg_args = try getFFprobeArgs(alloc, info_flags);
    defer alloc.free(ffmpeg_args);

    var child = try init.io.vtable.processSpawn(init.io.userdata, .{
        .argv = ffmpeg_args,
        .stdin = .pipe,
        .stdout = .inherit,
        .stderr = .inherit,
    });

    if (child.stdin) |s| {
        init.io.vtable.fileClose(init.io.userdata, &.{s});
        child.stdin = null;
    }

    try writer.print("{s}{s}File{s}: {s}\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, info_flags.input_file });
    try writer.flush();

    const term = try init.io.vtable.childWait(init.io.userdata, &child);

    switch (term) {
        .exited => |code| if (code != 0) {
            try writer.print("{s}✖{s} Info failed\n", .{ colors.ERROR, colors.RESET });
            try writer.flush();

            return error.ProcessFailed;
        },
        else => return error.ProcessTerminatedUnexpectedly,
    }

    std.debug.print("DEBUG:\n", .{});
    std.debug.print("  input file: {s}\n", .{info_flags.input_file});
}

const InfoFlags = struct {
    input_file: []const u8,
};

fn getFFprobeArgs(alloc: std.mem.Allocator, info_flags: InfoFlags) ![]const []const u8 {
    // reference: ffprobe -v error -print_format json -show_format -show_streams input.mp4
    var args = std.ArrayList([]const u8).empty;

    try args.append(alloc, "ffprobe");

    try args.append(alloc, "-v");
    try args.append(alloc, "error");

    try args.append(alloc, "-print_format");
    try args.append(alloc, "json");

    try args.append(alloc, "-show_format");
    try args.append(alloc, "-show_streams");

    try args.append(alloc, info_flags.input_file);

    return args.toOwnedSlice(alloc);
}

fn parseInfoFlagsFromArgs(writer: *std.Io.Writer, args: []const []const u8) !?InfoFlags {
    var info_flags: InfoFlags = .{
        .input_file = "",
    };

    var has_input_file = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (checker.flagsEql(arg, &.{ "-h", "--help" })) {
            try help.helpInfo(writer);
            return null;
        }

        if (!has_input_file) {
            has_input_file = true;
            info_flags.input_file = arg;
            continue;
        }
    }

    return info_flags;
}
