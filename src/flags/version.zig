const std = @import("std");
const builtin = @import("build_options");

pub fn version(writer: *std.Io.Writer) !void {
    try writer.print("kz {s}\n", .{builtin.kzen_version});
    _ = writer.flush() catch {};
}
