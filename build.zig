const std = @import("std");

pub fn build(b: *std.Build) void {
    //----------------------------------------
    // config
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const dep_opts = .{ .target = target, .optimize = optimize };
    _ = dep_opts;

    //----------------------------------------
    // define ZTS module
    const datastor_module = b.addModule("zts", .{
        .root_source_file = b.path("src/zts.zig"),
    });

    //----------------------------------------
    // benchmark demo app
    const exe = b.addExecutable(.{
        .name = "ZTS demo app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bench.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("zts", datastor_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("bench", "Run the benchmark app");
    run_step.dependOn(&run_cmd.step);

    //----------------------------------------
    // unit tests
    const test_step = b.step("test", "Run unit tests (redirect stdout to /dev/null)");
    const unit_tests = b.addTest(.{
        .root_module = b.addModule("tests", .{
            .root_source_file = b.path("src/zts.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    test_step.dependOn(&run_unit_tests.step);
}
