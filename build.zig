const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opts = b.addOptions();
    opts.addOption([]const u8, "kzen_version", "0.0.1-dev");

    const mod = b.addModule("kzen", .{
        .root_source_file = b.path("src/cli.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "build_options", .module = opts.createModule() },
        },
    });

    const exe = b.addExecutable(.{
        .name = "kzen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "kzen", .module = mod },
            },
        }),
    });

    // optimization for final kzen binary
    if (optimize != .Debug) {
        exe.root_module.strip = true;
        exe.lto = .full;
        exe.link_gc_sections = true;

        exe.stack_size = 1 * 1024 * 1024;
        exe.compress_debug_sections = .zstd;
        exe.root_module.unwind_tables = .none;

        exe.root_module.strip = true;
        exe.link_gc_sections = true;
        exe.lto = .full;
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
