const std = @import("std");
const checker = @import("../utils/checker.zig");

pub fn cut(writer: *std.Io.Writer, args: []const []const u8) !void {
    const cut_flags = try argsToCutFlags(args);

    try writer.print("start = {any}\n", .{cut_flags.start});
    try writer.print("end = {any}\n", .{cut_flags.end});
    try writer.print("input name = {s}\n", .{cut_flags.input_file_name});
    try writer.print("out name = {s}\n", .{cut_flags.output_name});
    try writer.flush();
}

fn argsToCutFlags(args: []const []const u8) !CutFlags {
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
