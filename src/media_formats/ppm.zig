const std = @import("std");

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
    pub fn load(init: std.process.Init, alloc: std.mem.Allocator, file_path: []const u8) !Image {
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

    /// Aplica um Box Blur com raio configurável.
    /// radius 1 = 3x3 (fraco), radius 5 = 11x11 (médio), radius 15 = 31x31 (forte)
    pub fn blur(self: *Image, radius: usize) !void {
        // Se passar raio 0, não faz nada
        if (radius == 0) return;

        const temp_pixels = try self.alloc.alloc(Pixel, self.pixels.len);
        defer self.alloc.free(temp_pixels);
        @memcpy(temp_pixels, self.pixels);

        const w = self.width;
        const h = self.height;

        // Calcula a área da janela (ex: raio 5 = 11x11 = 121 pixels pra somar)
        const window_size = radius * 2 + 1;
        const window_area = @as(u32, @intCast(window_size * window_size));

        // Evita crash se o raio for gigante
        if (radius >= w / 2 or radius >= h / 2) return;

        for (radius..h - radius) |y| {
            for (radius..w - radius) |x| {
                var sum_r: u32 = 0;
                var sum_g: u32 = 0;
                var sum_b: u32 = 0;

                // Percorre a vizinhança dinâmica
                for (0..window_size) |dy| {
                    for (0..window_size) |dx| {
                        // Acha o pixel vizinho compensando o raio
                        const ny = y + dy - radius;
                        const nx = x + dx - radius;

                        const p = temp_pixels[ny * w + nx];

                        sum_r += p.r();
                        sum_g += p.g();
                        sum_b += p.b();
                    }
                }

                // Tira a média usando a área total da janela
                const out_idx = y * w + x;
                self.pixels[out_idx] = Pixel{ .rgb = .{
                    @as(u8, @intCast(sum_r / window_area)),
                    @as(u8, @intCast(sum_g / window_area)),
                    @as(u8, @intCast(sum_b / window_area)),
                } };
            }
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();

    var img = try Image.load(init, alloc, "local_tests/input.ppm");
    defer img.deinit();

    try img.blur(5);
    try img.save(init.io, "saida.ppm");
}
