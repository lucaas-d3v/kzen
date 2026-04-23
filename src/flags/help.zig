const std = @import("std");
const colors = @import("../ui/color.zig");
const styles = @import("../ui/styles.zig");

pub fn help(writer: *std.Io.Writer) !void {
    try writer.print("{s}{s}Usage{s}: kz {s}<command>{s} [options]\n\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Commands{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  {s}cut{s}               Cut segment from a video\n\n", .{ colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Options{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  {s}-h{s}, {s}--help{s}        Show this help message\n", .{ colors.SECONDARY, colors.RESET, colors.SECONDARY, colors.RESET });
    try writer.print("  {s}-v{s}, {s}--version{s}     Show version\n\n", .{ colors.SECONDARY, colors.RESET, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Example{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  kz cut input.mp4 00:34 01:00 -o output.mp4\n", .{});

    _ = writer.flush() catch {};
}
