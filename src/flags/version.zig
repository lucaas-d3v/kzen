const std = @import("std");
const builtin = @import("build_options");

const colors = @import("../ui/color.zig");
const styles = @import("../ui/styles.zig");

pub fn version(writer: *std.Io.Writer) !void {
    try writer.print("kz {s}{s}{s}{s}\n", .{ styles.BOLD, colors.PRIMARY, builtin.kzen_version, colors.RESET });
    _ = writer.flush() catch {};
}
