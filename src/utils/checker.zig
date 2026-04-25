const std = @import("std");
const VideoFormatsSupported = @import("../media_formats/formats_supported.zig").VideoFormatsSupported;

pub inline fn argEql(arg: []const u8, target: []const u8) bool {
    return std.mem.eql(u8, arg, target);
}

pub inline fn flagsEql(flag: []const u8, targets: []const []const u8) bool {
    for (targets) |target| {
        if (std.mem.eql(u8, flag, target)) return true;
    }

    return false;
}

pub inline fn argEnds(arg: []const u8, needed: []const u8) bool {
    return std.mem.endsWith(u8, arg, needed);
}

pub inline fn argEndsWithSome(arg: []const u8, needs: []const []const u8) bool {
    for (needs) |needed| {
        if (std.mem.endsWith(u8, arg, needed)) return true;
    }

    return false;
}

pub inline fn argStartsWithSome(arg: []const u8, needs: []const []const u8) bool {
    for (needs) |needed| {
        if (std.mem.startsWith(u8, arg, needed)) return true;
    }

    return false;
}

pub inline fn validadeVideoFile(file: []const u8) !bool {
    const is_media_file = argEndsWithSome(file, VideoFormatsSupported.getValues());
    const has_name = file.len > 0;

    return is_media_file and has_name;
}
