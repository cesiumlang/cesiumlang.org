const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ai = b.addModule("ai", .{
        .root_source_file = b.path("tools/ai/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "cesium-site-ai",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/ai/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/ai/_test/ai.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "ai", .module = ai }},
        }),
    });
    b.step("test", "Run the tests of the site tools").dependOn(&b.addRunArtifact(tests).step);
}
