const std = @import("std");
const Io = std.Io;

const kzen = @import("kzen");

pub fn main(init: std.process.Init) !void {
    const exit_code = try kzen.cli(init);

    if (exit_code != 0) {
        std.process.exit(exit_code);
    } else {
        std.process.exit(0);
    }
}
