const std = @import("std");

pub fn help(writer: *std.Io.Writer) !void {
    try writer.print("Usage: kz <command> [options]\n\n", .{});

    try writer.print("Commands:\n", .{});
    try writer.print("  cut               Cut segment from a video\n\n", .{});

    try writer.print("Options:\n", .{});
    try writer.print("  -h, --help        Show this help message\n", .{});
    try writer.print("  -v, --version     Show version\n\n", .{});

    try writer.print("Example:\n", .{});
    try writer.print("  kz cut input.mp4 00:34 01:00 -o output.mp4\n", .{});

    _ = writer.flush() catch {};
}
