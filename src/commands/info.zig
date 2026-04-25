const std = @import("std");

const styles = @import("../ui/styles.zig");
const colors = @import("../ui/color.zig");
const checker = @import("../utils/checker.zig");
const help = @import("../flags/help.zig");

pub fn info(init: *const std.process.Init, writer: *std.Io.Writer, args: []const []const u8) !void {
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
        .stdin = .close,
        .stdout = .pipe,
        .stderr = .inherit,
    });

    const max_size = 1024 * 1024;
    const buf = try alloc.alloc(u8, max_size);
    errdefer alloc.free(buf);

    var fifo_buf: [4096]u8 = undefined;
    var reader = child.stdout.?.reader(init.io, &fifo_buf);

    const actual_len = try reader.interface.readSliceShort(buf);

    const stdout_output = buf[0..actual_len];
    defer alloc.free(buf);

    const term = try init.io.vtable.childWait(init.io.userdata, &child);

    switch (term) {
        .exited => |code| if (code != 0) {
            try writer.print("{s}✖{s} Info failed (code {d})\n", .{ colors.ERROR, colors.RESET, code });
            try writer.flush();
            return error.ProcessFailed;
        },
        else => return error.ProcessTerminatedUnexpectedly,
    }

    if (info_flags.show_json) {
        const parsed = try std.json.parseFromSlice(std.json.Value, alloc, stdout_output, .{});
        defer parsed.deinit();

        var s: std.json.Stringify = .{
            .writer = writer,
            .options = .{ .whitespace = .indent_4 },
        };

        try s.write(parsed.value);

        try writer.print("\n", .{});
        try writer.flush();

        return;
    }

    try writer.print("{s}File{s}: {s}{s}{s}\n", .{ colors.PRIMARY, colors.RESET, colors.TEXT, info_flags.input_file, colors.RESET });
    try writer.flush();

    const parsed = try std.json.parseFromSlice(FfprobeOutput, alloc, stdout_output, .{
        .ignore_unknown_fields = true,
    });
    defer parsed.deinit();

    const ffprobe_data = parsed.value;

    if (ffprobe_data.format.format_name) |f_name| {
        const format = blk: {
            var parts = std.mem.splitScalar(u8, f_name, ',');

            break :blk parts.next() orelse f_name;
        };

        try writer.print("{s}Format{s}: {s}{s}{s}\n", .{ colors.PRIMARY, colors.RESET, colors.TEXT, format, colors.RESET });
    }

    if (ffprobe_data.format.duration) |d_str| {
        const duration = try parseDuration(d_str);
        try writer.print("{s}Duration{s}: {s}\n", .{ colors.PRIMARY, colors.RESET, humanizeDuration(alloc, duration) });
    }

    if (ffprobe_data.format.bit_rate) |br_str| {
        try writer.print("{s}Bitrate{s}: {s}{d:.2}{s} kb/s\n", .{ colors.PRIMARY, colors.RESET, colors.TEXT, try humanizeBitrate(br_str), colors.RESET });
    }

    // streams
    for (ffprobe_data.streams) |stream| {
        if (std.mem.eql(u8, stream.codec_type, "video")) {
            try writer.print("\n{s}Video{s}:\n", .{ colors.PRIMARY, colors.RESET });
            if (stream.codec_name) |codec| try writer.print("  {s}{s}Codec{s}: {s}{s}{s}\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, colors.TEXT, codec, colors.RESET });

            if (stream.width) |w| if (stream.height) |h| {
                try writer.print("{s}{s}Resolution{s}: {s}{d}x{d}{s}\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, colors.TEXT, w, h, colors.RESET });
            };

            if (stream.avg_frame_rate) |fps_str| {
                const fps = try parseFps(fps_str);
                try writer.print("  {s}{s}FPS{s}: {s}{d:.2}{s}\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, colors.TEXT, fps, colors.RESET });
            }
        } else if (std.mem.eql(u8, stream.codec_type, "audio")) {
            try writer.print("\n{s}Audio{s}:\n", .{ colors.PRIMARY, colors.RESET });
            if (stream.codec_name) |codec| try writer.print("  {s}{s}Codec{s}: {s}{s}{s}\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, colors.TEXT, codec, colors.RESET });
        }
    }
}

fn humanizeDuration(alloc: std.mem.Allocator, brute_seconds: f32) []const u8 {
    const total_secs = @as(u32, @intFromFloat(brute_seconds));

    const hours = total_secs / 3600;
    const minutes = (total_secs % 3600) / 60;
    const seconds = total_secs % 60;

    const r = std.fmt.allocPrint(alloc, "{s}{d:0>2}{s}:{s}{d:0>2}{s}:{s}{d:0>2}{s}", .{ colors.TEXT, hours, colors.RESET, colors.TEXT, minutes, colors.RESET, colors.TEXT, seconds, colors.RESET }) catch "00:00:00";

    return r;
}

fn humanizeBitrate(bitrate: []const u8) !f32 {
    return try std.fmt.parseFloat(f32, bitrate) / 1000;
}

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
        .show_json = false,
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

        if (checker.flagsEql(arg, &.{ "-j", "--json" })) {
            info_flags.show_json = true;
            continue;
        }

        if (!has_input_file) {
            has_input_file = true;
            info_flags.input_file = arg;
            continue;
        }
    }

    return info_flags;
}

// converts to f32
fn parseFps(fps_str: []const u8) !f32 {
    var it = std.mem.splitScalar(u8, fps_str, '/');
    const num_str = it.next() orelse return error.InvalidFpsFormat;
    const den_str = it.next() orelse "1"; // falback

    const num = try std.fmt.parseFloat(f32, num_str);
    const den = try std.fmt.parseFloat(f32, den_str);

    if (den == 0.0) return 0.0;
    return num / den;
}

// converts to f32
fn parseDuration(duration_str: []const u8) !f32 {
    return std.fmt.parseFloat(f32, duration_str);
}

const InfoFlags = struct {
    show_json: bool,
    input_file: []const u8,
};

const FfprobeStream = struct {
    codec_type: []const u8,
    codec_name: ?[]const u8 = null,
    width: ?u32 = null,
    height: ?u32 = null,
    avg_frame_rate: ?[]const u8 = null,
};

const FfprobeFormat = struct {
    format_name: ?[]const u8 = null,
    duration: ?[]const u8 = null,
    bit_rate: ?[]const u8 = null,
};

const FfprobeOutput = struct {
    streams: []FfprobeStream,
    format: FfprobeFormat,
};
