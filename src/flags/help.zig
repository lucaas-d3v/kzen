const std = @import("std");
const colors = @import("../ui/color.zig");
const styles = @import("../ui/styles.zig");

pub fn help(writer: *std.Io.Writer) !void {
    try writer.print("{s}{s}Usage{s}: kz {s}{s}<command>{s} [options]\n\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Commands{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  {s}{s}cut{s}               Cut segment from a video\n", .{ styles.DIM, colors.SECONDARY, colors.RESET });
    try writer.print("  {s}{s}info{s}              Show data from a video\n\n", .{ styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Options{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  {s}{s}-h{s}, {s}{s}--help{s}        Show this help message\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });
    try writer.print("  {s}{s}-v{s}, {s}{s}--version{s}     Show version\n\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Example{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  kz cut input.mp4 00:34 01:00 -o output.mp4\n", .{});

    _ = writer.flush() catch {};
}

// sub-helps
pub fn helpCut(writer: *std.Io.Writer) !void {
    try writer.print("{s}{s}Usage{s}: kz {s}{s}cut{s} <input_file> <start> <end> [-o outname]\n\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Example{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  kz {s}{s}cut{s} input.mp4 00:34 01:00 -o output.mp4\n\n", .{ styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Options{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  {s}{s}-h{s}, {s}{s}--help{s}        Show this help message\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });

    _ = writer.flush() catch {};
}

pub fn helpInfo(writer: *std.Io.Writer) !void {
    try writer.print("{s}{s}Usage{s}: kz {s}{s}info{s} <input_file>\n\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Example{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  kz {s}{s}info{s} input.mp4\n\n", .{ styles.DIM, colors.SECONDARY, colors.RESET });

    try writer.print("{s}{s}Options{s}:\n", .{ styles.BOLD, colors.PRIMARY, colors.RESET });
    try writer.print("  {s}{s}-h{s}, {s}{s}--help{s}        Show this help message\n", .{ styles.DIM, colors.SECONDARY, colors.RESET, styles.DIM, colors.SECONDARY, colors.RESET });

    _ = writer.flush() catch {};
}
