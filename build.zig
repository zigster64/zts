const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zts", .{
        .source_file = .{ .path = "src/zts.zig" },
    });

    // Tests
    {
        const lib_test = b.addTest(.{
            .root_source_file = .{ .path = "src/zts.zig" },
            .target = target,
            .optimize = optimize,
        });
        const run_test = b.addRunArtifact(lib_test);
        run_test.has_side_effects = true;

        const test_step = b.step("test", "Run tests");
        test_step.dependOn(&run_test.step);
    }

    // benchmark - use zig build bench to create the bench, then zig-out/bin/zts-bench to run
    {
        const bench = b.addExecutable(.{
            .name = "zts-bench",
            .root_source_file = .{ .path = "src/bench.zig" },
            .target = target,
            .optimize = optimize,
        });

        b.installArtifact(bench);
    }
}
