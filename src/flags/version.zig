const std = @import("std");
const builtin = @import("build_options");

pub fn version(stdout: *std.Io.Writer) !void {
    try stdout.print("kz {s}\n", .{builtin.kzen_version});
    _ = stdout.flush() catch {};
}
