const std = @import("std");

pub const VideoFormatsSupported = enum {
    mp4,
    mkv,
    avi,

    pub fn getValues() []const []const u8 {
        const fields = std.enums.values(VideoFormatsSupported);
        return comptime blk: {
            var names: [fields.len][]const u8 = undefined;
            for (fields, 0..) |field, i| {
                names[i] = "." ++ @tagName(field);
            }
            const static_names = names;
            break :blk &static_names;
        };
    }
};

pub const ImageFormatsSupported = enum {
    ppm,

    pub fn getValues() []const []const u8 {
        const fields = std.enums.values(ImageFormatsSupported);
        return comptime blk: {
            var names: [fields.len][]const u8 = undefined;
            for (fields, 0..) |field, i| {
                names[i] = "." ++ @tagName(field);
            }
            const static_names = names;
            break :blk &static_names;
        };
    }
};
