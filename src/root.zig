const std = @import("std");
const Io = std.Io;

pub fn cli(stdout: *std.Io.Writer) !void {
    try stdout.print("kzen 0.0.1\n", .{});
}
