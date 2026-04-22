const std = @import("std");

pub inline fn arg_eql(arg: []const u8, target: []const u8) bool {
    return std.mem.eql(u8, arg, target);
}

pub inline fn flags_eql(flag: []const u8, targets: []const []const u8) bool {
    for (targets) |target| {
        if (std.mem.eql(u8, flag, target)) return true;
    }

    return false;
}
