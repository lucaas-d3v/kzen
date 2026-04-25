const std = @import("std");

const styles = @import("../ui/styles.zig");
const colors = @import("../ui/color.zig");

const checker = @import("../utils/checker.zig");
const help = @import("../flags/help.zig");

const ImageFormatsSupported = @import("../media_formats/formats_supported.zig").ImageFormatsSupported;

pub fn filter(init: *const std.process.Init, writer: *std.Io.Writer, args: []const []const u8) !void {
    const alloc = init.arena.allocator();

    const maybe_flags = try argsToFilterFlags(writer, alloc, args);
    const filter_flags = maybe_flags orelse return;

    var img = try Image.load(init, alloc, filter_flags.input_name);
    defer img.deinit();

    // aply filter
    for (filter_flags.filters) |f| {
        if (checker.argEql(f.name, "grayscale")) {
            try writer.print("Applying grayscale...\n", .{});
            try writer.flush();

            img.grayscale();
            continue;
        }

        if (checker.argEql(f.name, "invert")) {
            try writer.print("Applying invert...\n", .{});
            try writer.flush();

            img.invert();
            continue;
        }

        if (checker.argEql(f.name, "blur")) {
            try writer.print("Applying blur...\n", .{});
            try writer.flush();

            if (f.params.len > 0) {
                for (f.params) |v| {
                    try img.blur(try std.fmt.parseInt(u8, v, 10), pool);
                }
            } else {
                try img.blur(5, pool);
            }
        }
    }

    try img.save(init.io, filter_flags.out_name);

    // debug
    std.debug.print("\n\n\n", .{});
    std.debug.print("DEBUG:\n", .{});
    std.debug.print("  input file: {s}\n", .{filter_flags.input_name});
    std.debug.print("  out name: {s}\n", .{filter_flags.out_name});

    std.debug.print("  filters:\n", .{});
    for (filter_flags.filters) |f| {
        std.debug.print("    name: {s}\n", .{f.name});
        std.debug.print("      params:", .{});

        for (f.params) |p| {
            std.debug.print(" {s},", .{p});
        }
        std.debug.print("\n", .{});
    }
}

fn argsToFilterFlags(writer: *std.Io.Writer, alloc: std.mem.Allocator, args: []const []const u8) !?FilterFlags {
    var filter_flags: FilterFlags = .{
        .input_name = "",
        .out_name = "",
        .filters = &.{},
    };

    var filters_list = std.ArrayList(Filter).empty;
    var has_input_file = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (checker.flagsEql(arg, &.{ "-h", "--help" })) {
            try help.helpFilter(writer);
            return null;
        }

        if (checker.flagsEql(arg, &.{ "-o", "--output" })) {
            i += 1;
            if (i < args.len) {
                filter_flags.updateOutName(args[i]);
            } else {
                try writer.print("{s}{s}Error{s}: Missing output file name after '{s}' flag.\n", .{ styles.BOLD, colors.ERROR, colors.RESET, arg });
                return null;
            }
            continue;
        }

        if (!has_input_file and checker.argEndsWithSome(arg, ImageFormatsSupported.getValues())) {
            filter_flags.input_name = arg;
            if (filter_flags.out_name.len == 0) filter_flags.updateOutName(arg);
            has_input_file = true;
            continue;
        }

        if (checker.argEql(arg, "grayscale") or checker.argEql(arg, "blur") or checker.argEql(arg, "invert")) {
            var params = std.ArrayList([]const u8).empty;

            while (i + 1 < args.len) {
                const next_arg = args[i + 1];

                if (std.mem.startsWith(u8, next_arg, "-")) break;
                if (checker.argEql(next_arg, "grayscale") or checker.argEql(next_arg, "blur") or checker.argEql(next_arg, "invert")) break;
                if (!has_input_file and checker.argEndsWithSome(next_arg, ImageFormatsSupported.getValues())) break;

                try params.append(alloc, next_arg);
                i += 1;
            }

            try filters_list.append(alloc, .{
                .name = arg,
                .params = try params.toOwnedSlice(alloc),
            });
            continue;
        }
    }

    filter_flags.filters = try filters_list.toOwnedSlice(alloc);

    return filter_flags;
}

const FilterFlags = struct {
    input_name: []const u8,
    out_name: []const u8,
    filters: []Filter,

    pub inline fn updateOutName(self: *FilterFlags, name: []const u8) void {
        self.out_name = name;
    }
};

const Filter = struct {
    name: []const u8,
    params: []const []const u8,
};

// filters

/// It is based on arrays to avoid memory padding
pub const Pixel = struct {
    rgb: [3]u8, // rgb[0] = R, rgb[1] = G, rgb[2] = B

    // helpers
    pub inline fn r(self: Pixel) u8 {
        return self.rgb[0];
    }
    pub inline fn g(self: Pixel) u8 {
        return self.rgb[1];
    }
    pub inline fn b(self: Pixel) u8 {
        return self.rgb[2];
    }
};

pub const Image = struct {
    width: usize,
    height: usize,
    pixels: []Pixel,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Image) void {
        self.alloc.free(self.pixels);
    }

    /// read .ppm (P6) file
    pub fn load(init: *const std.process.Init, alloc: std.mem.Allocator, file_path: []const u8) !Image {
        const file_content = try std.Io.Dir.cwd().readFileAlloc(init.io, file_path, alloc, std.Io.Limit.limited(50 * 1024 * 1024));
        defer alloc.free(file_content);

        var i: usize = 0;

        // check it is relay P6 file
        if (file_content.len < 3 or file_content[0] != 'P' or file_content[1] != '6') return error.InvalidFormat;
        i += 2;

        // skip whatever spaces, newline and ffmpef comments
        while (i < file_content.len) {
            if (std.ascii.isWhitespace(file_content[i])) {
                i += 1;
            } else if (file_content[i] == '#') {
                while (i < file_content.len and file_content[i] != '\n') i += 1;
            } else {
                break;
            }
        }

        // read width
        const w_start = i;
        while (i < file_content.len and !std.ascii.isWhitespace(file_content[i])) i += 1;
        const width = try std.fmt.parseInt(usize, file_content[w_start..i], 10);

        while (i < file_content.len and std.ascii.isWhitespace(file_content[i])) i += 1;

        // read height
        const h_start = i;
        while (i < file_content.len and !std.ascii.isWhitespace(file_content[i])) i += 1;
        const height = try std.fmt.parseInt(usize, file_content[h_start..i], 10);

        while (i < file_content.len and std.ascii.isWhitespace(file_content[i])) i += 1;

        // read max color
        while (i < file_content.len and !std.ascii.isWhitespace(file_content[i])) i += 1;

        // only ONE and EXACTLY ONE space character separates the header from the binary data.
        i += 1;

        const total_pixels = width * height;
        const pixels = try alloc.alloc(Pixel, total_pixels);

        const expected_bytes = total_pixels * 3;
        if (i + expected_bytes > file_content.len) return error.IncompleteData;

        const pixel_bytes = std.mem.sliceAsBytes(pixels);
        @memcpy(pixel_bytes, file_content[i .. i + expected_bytes]);

        return Image{
            .width = width,
            .height = height,
            .pixels = pixels,
            .alloc = alloc,
        };
    }

    // save the image as new .ppm (p6)
    pub fn save(self: Image, io: std.Io, file_path: []const u8) !void {
        var file = try std.Io.Dir.cwd().createFile(io, file_path, .{});
        defer file.close(io);

        var bufered_writer: [1024]u8 = undefined;
        var writer = file.writer(io, &bufered_writer);

        // write header of p6
        try writer.interface.print("P6\n{d} {d}\n255\n", .{ self.width, self.height });

        // write the pixels
        const pixel_bytes = std.mem.sliceAsBytes(self.pixels);
        try writer.interface.writeAll(pixel_bytes);

        try writer.interface.flush();
    }

    pub fn invert(self: *Image) void {
        for (self.pixels) |*p| {
            p.rgb = .{ 255 - p.r(), 255 - p.g(), 255 - p.b() };
        }
    }

    pub fn grayscale(self: *Image) void {
        for (self.pixels) |*p| {
            const r = @as(u32, p.r());
            const g = @as(u32, p.g());
            const b = @as(u32, p.b());

            const lum = (r * 299 + g * 587 + b * 114) / 1000;
            const gray = @as(u8, @intCast(lum));

            p.rgb = .{ gray, gray, gray };
        }
    }

    pub fn blur(self: *Image, radius: usize, pool: *std.Thread.Pool) !void {
        if (radius == 0) return;

        const w = self.width;
        const h = self.height;

        if (radius >= w / 2 or radius >= h / 2) return;

        const temp_pixels = try self.alloc.alloc(Pixel, self.pixels.len);
        defer self.alloc.free(temp_pixels);
        @memcpy(temp_pixels, self.pixels);

        const window_size = @as(u32, @intCast(radius * 2 + 1));

        const num_tasks = 8;

        var wg = std.Thread.WaitGroup{};

        // width
        var chunk = h / num_tasks;
        for (0..num_tasks) |i| {
            const start_y = i * chunk;
            const end_y = if (i == num_tasks - 1) h else (i + 1) * chunk;

            pool.spawnWg(&wg, blurHorizontalWorker, .{
                self.pixels, temp_pixels, w, start_y, end_y, radius, window_size,
            });
        }

        wg.wait();

        // height
        const active_h = h - (radius * 2);
        chunk = active_h / num_tasks;

        for (0..num_tasks) |i| {
            const start_y = radius + (i * chunk);
            const end_y = if (i == num_tasks - 1) h - radius else start_y + chunk;

            pool.spawnWg(&wg, blurVerticalWorker, .{
                self.pixels, temp_pixels, w, start_y, end_y, radius, window_size,
            });
        }

        wg.wait();
    }
};

// thread workers
fn blurHorizontalWorker(pixels: []Pixel, temp: []Pixel, w: usize, start_y: usize, end_y: usize, radius: usize, window_size: u32) void {
    for (start_y..end_y) |y| {
        for (radius..w - radius) |x| {
            var sum_r: u32 = 0;
            var sum_g: u32 = 0;
            var sum_b: u32 = 0;

            for (0..window_size) |dx| {
                const nx = x + dx - radius;
                const p = pixels[y * w + nx];
                sum_r += p.r();
                sum_g += p.g();
                sum_b += p.b();
            }

            temp[y * w + x] = Pixel{ .rgb = .{
                @as(u8, @intCast(sum_r / window_size)),
                @as(u8, @intCast(sum_g / window_size)),
                @as(u8, @intCast(sum_b / window_size)),
            } };
        }
    }
}

fn blurVerticalWorker(pixels: []Pixel, temp: []Pixel, w: usize, start_y: usize, end_y: usize, radius: usize, window_size: u32) void {
    for (start_y..end_y) |y| {
        for (0..w) |x| {
            var sum_r: u32 = 0;
            var sum_g: u32 = 0;
            var sum_b: u32 = 0;

            for (0..window_size) |dy| {
                const ny = y + dy - radius;
                const p = temp[ny * w + x];
                sum_r += p.r();
                sum_g += p.g();
                sum_b += p.b();
            }

            pixels[y * w + x] = Pixel{ .rgb = .{
                @as(u8, @intCast(sum_r / window_size)),
                @as(u8, @intCast(sum_g / window_size)),
                @as(u8, @intCast(sum_b / window_size)),
            } };
        }
    }
}
