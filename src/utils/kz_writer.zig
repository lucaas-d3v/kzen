const std = @import("std");

pub const KzWriter = struct {
    stdout: *std.Io.Writer,
    stderr: *std.Io.Writer,

    pub fn init(initer: std.process.Init) !KzWriter {
        const allocator = initer.arena.allocator();

        const stdout_ptr = try allocator.create(std.Io.File.Writer);
        const stderr_ptr = try allocator.create(std.Io.File.Writer);

        const out_buf = try allocator.alloc(u8, 1024);
        const err_buf = try allocator.alloc(u8, 1024);

        stdout_ptr.* = .init(.stdout(), initer.io, out_buf);
        stderr_ptr.* = .init(.stderr(), initer.io, err_buf);

        return .{
            .stdout = &stdout_ptr.interface,
            .stderr = &stderr_ptr.interface,
        };
    }

    pub fn flush(self: KzWriter) !void {
        try self.stdout.flush();
        try self.stderr.flush();
    }
};
