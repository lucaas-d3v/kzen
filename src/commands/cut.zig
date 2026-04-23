const std = @import("std");

const colors = @import("../ui/color.zig");
const styles = @import("../ui/styles.zig");

const checker = @import("../utils/checker.zig");
const help = @import("../flags/help.zig");

pub fn cut(init: std.process.Init, alloc: std.mem.Allocator, writer: *std.Io.Writer, args: []const []const u8) !void {
    const maybe_flags = try argsToCutFlags(writer, args);
    const cut_flags = maybe_flags orelse return;

    const ffmpeg_args = try getFFmpegArgs(alloc, cut_flags);
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

    try writer.print("{s}{s}➜ Cutting video...{s}\n", .{ styles.DIM, colors.SECONDARY, colors.RESET });
    try writer.flush();

    const term = try init.io.vtable.childWait(init.io.userdata, &child);

    switch (term) {
        .exited => |code| if (code != 0) {
            try writer.print("{s}✖{s} Cut failed\n", .{ colors.ERROR, colors.RESET });
            try writer.flush();

            return error.ProcessFailed;
        },
        else => return error.ProcessTerminatedUnexpectedly,
    }

    try writer.print("{s}✔{s} Cut completed: {s}{s}{s}\n", .{ colors.SUCCESS, colors.RESET, colors.PRIMARY, cut_flags.output_name, colors.RESET });
    try writer.flush();
}

fn getFFmpegArgs(alloc: std.mem.Allocator, cut_flags: CutFlags) ![]const []const u8 {
    // reference: ffmpeg -ss 00:00:34 -to 00:01:00 -i input.mp4 -c copy output.mp4
    var args = std.ArrayList([]const u8).empty;

    try args.append(alloc, "ffmpeg");

    try args.append(alloc, "-hide_banner");

    try args.append(alloc, "-loglevel");
    try args.append(alloc, "error");

    try args.append(alloc, "-ss");

    const start = try std.fmt.allocPrint(alloc, "{d}:{d}:{d}", .{ cut_flags.start.hour, cut_flags.start.min, cut_flags.start.secs });
    try args.append(alloc, start);

    try args.append(alloc, "-to");

    const end = try std.fmt.allocPrint(alloc, "{d}:{d}:{d}", .{ cut_flags.end.hour, cut_flags.end.min, cut_flags.end.secs });
    try args.append(alloc, end);

    try args.append(alloc, "-i");
    try args.append(alloc, cut_flags.input_file_name);
    try args.append(alloc, "-c");
    try args.append(alloc, "copy");
    try args.append(alloc, cut_flags.output_name);

    try args.append(alloc, "-y");
    return args.toOwnedSlice(alloc);
}

fn argsToCutFlags(writer: *std.Io.Writer, args: []const []const u8) !?CutFlags {
    var cut_flags: CutFlags = .{
        .input_file_name = "",
        .output_name = "",
        .start = .{
            .hour = 0,
            .min = 0,
            .secs = 0,
        },
        .end = .{
            .hour = 0,
            .min = 0,
            .secs = 0,
        },
    };

    // suport
    var has_input_file = false;
    var has_start = false;
    var has_end = false;

    var i: u8 = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (checker.flagsEql(arg, &.{ "-h", "--help" })) {
            try help.helpCut(writer);
            return null;
        }

        // output name definition
        if (checker.flagsEql(arg, &.{ "-o", "--output" })) {
            i += 1;
            if (i < args.len) cut_flags.updateOutName(args[i]);
            continue;
        }

        // input file
        if (!has_input_file and checker.argEndsWithSome(arg, FormsSupported.getValues())) {
            cut_flags.input_file_name = arg;
            if (cut_flags.output_name.len == 0) cut_flags.updateOutName(arg);
            has_input_file = true;
            continue;
        }

        // start|end
        if (!has_start) {
            cut_flags.start = try Time.parse(arg);
            has_start = true;
            continue;
        }

        if (!has_end) {
            cut_flags.end = try Time.parse(arg);
            has_end = true;
            continue;
        }
    }

    return cut_flags;
}

// local utils
const CutFlags = struct {
    input_file_name: []const u8,
    output_name: []const u8,
    start: Time,
    end: Time,

    pub inline fn updateOutName(self: *CutFlags, new_name: []const u8) void {
        self.output_name = new_name;
    }
};

const Time = struct {
    hour: u8,
    min: u8,
    secs: u8,

    pub fn parse(arg: []const u8) !Time {
        var time = Time{ .hour = 0, .min = 0, .secs = 0 };
        const count = std.mem.count(u8, arg, ":") + 1;

        if (count > 3 or count < 1) return error.InvalidFormat;

        var it = std.mem.splitScalar(u8, arg, ':');

        // maps pointers to fill backwards if necessary
        // if count is 1 (seconds only), we start at index 2 of the 'parts' array
        const parts = [_]*u8{ &time.hour, &time.min, &time.secs };
        var i: usize = 3 - count;

        while (it.next()) |part| : (i += 1) {
            parts[i].* = try std.fmt.parseInt(u8, part, 10);
        }

        return time;
    }
};

const FormsSupported = enum {
    mp4,
    mkv,
    avi,

    pub fn getValues() []const []const u8 {
        const fields = std.enums.values(FormsSupported);
        return comptime blk: {
            var names: [fields.len][]const u8 = undefined;
            for (fields, 0..) |field, i| {
                names[i] = "." ++ @tagName(field);
            }
            const static_names = names;
            break :blk &static_names;
        };
    }
};
