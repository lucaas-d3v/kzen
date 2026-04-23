const std = @import("std");
const builtin = @import("build_options");

const colors = @import("../ui/color.zig");

pub fn version(writer: *std.Io.Writer) !void {
    try writer.print("kz {s}{s}{s}\n", .{ colors.PRIMARY, builtin.kzen_version, colors.RESET });
    _ = writer.flush() catch {};
}
