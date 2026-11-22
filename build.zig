const std = @import("std");
const zine = @import("zine");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // the units the tools share: pages, links, rules
    const ai = b.addModule("ai", .{
        .root_source_file = b.path("tools/ai/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const highlight = b.dependency("grammar", .{ .target = target, .optimize = optimize }).module("highlight");

    // llms.txt, Markdown pages and the skill, from content/ (cesiumlang.org#25)
    const ai_exe = b.addExecutable(.{
        .name = "cesium-site-ai",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/ai/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(ai_exe);

    // content/ to the input of Zine: site/content, site/assets/site-index.json
    const gen_exe = b.addExecutable(.{
        .name = "cesium-site-gen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/zine/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ai", .module = ai },
                .{ .name = "highlight", .module = highlight },
            },
        }),
    });
    const gen = b.addRunArtifact(gen_exe);
    gen.setCwd(b.path("."));
    gen.has_side_effects = true;
    b.step("gen", "Write the input of Zine from content/").dependOn(&gen.step);

    // the site: zig build, and zig build serve for the live server
    const site = zine.website(b, .{
        .website_root = b.path("site"),
        .output_path = "public",
        .force = true,
    });
    site.step.dependOn(&gen.step);
    b.getInstallStep().dependOn(&site.step);

    const serve = zine.serve(b, .{ .website_root = b.path("site") });
    serve.step.dependOn(&gen.step);
    b.step("serve", "Start the Zine dev server").dependOn(&serve.step);

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
