//! cesium-site-ai --out DIR [--content DIR] [--host HOST] [--strict]
//!
//! Writes, from the Markdown pages of the site: `llms.txt`, a plain Markdown
//! version of every page (`PAGE.md` beside its HTML), and the Cesium skill
//! under `skill/cesium-language/` (cesiumlang/cesiumlang.org#25). The files
//! do not depend on the site generator; run it after the site is built, with
//! its output directory as DIR.

const std = @import("std");
const content = @import("content.zig");
const llms_txt = @import("llms_txt.zig");
const portable = @import("portable.zig");
const skill = @import("skill.zig");

const usage = "usage: cesium-site-ai --out DIR [--content DIR] [--host HOST] [--strict]\n";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena_state: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var content_dir: []const u8 = "content";
    var out_dir: ?[]const u8 = null;
    var host: []const u8 = "cesiumlang.org";
    var strict = false;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--strict")) {
            strict = true;
        } else if (i + 1 < args.len and std.mem.eql(u8, arg, "--content")) {
            i += 1;
            content_dir = args[i];
        } else if (i + 1 < args.len and std.mem.eql(u8, arg, "--out")) {
            i += 1;
            out_dir = args[i];
        } else if (i + 1 < args.len and std.mem.eql(u8, arg, "--host")) {
            i += 1;
            host = args[i];
        } else {
            try std.Io.File.stderr().writeStreamingAll(io, usage);
            std.process.exit(2);
        }
    }
    const out = out_dir orelse {
        try std.Io.File.stderr().writeStreamingAll(io, usage);
        std.process.exit(2);
    };

    const pages = try content.load(arena, io, content_dir);
    var report: portable.Report = .{};

    for (pages) |page| {
        const text = try portable.render(arena, pages, page, &report);
        try write(io, arena, out, try std.fmt.allocPrint(arena, "{s}.md", .{page.slug}), text);
        if (std.mem.startsWith(u8, page.slug, "spec/") or std.mem.startsWith(u8, page.slug, "reference/")) {
            const copy = try std.fmt.allocPrint(arena, "skill/{s}/references/{s}.md", .{ skill.name, page.slug });
            try write(io, arena, out, copy, text);
        }
    }
    try write(io, arena, out, "llms.txt", try llms_txt.render(arena, pages, host, skill.name));

    const result = try skill.render(arena, pages, host);
    try write(io, arena, out, "skill/" ++ skill.name ++ "/SKILL.md", result.text);

    std.debug.print("{d} pages, SKILL.md {d} lines, {d} unresolved links, {d} uncited rules\n", .{
        pages.len, result.lines, report.unresolved, result.uncited,
    });
    if (result.lines > skill.max_lines) {
        std.debug.print("error: SKILL.md has more than {d} lines\n", .{skill.max_lines});
        std.process.exit(1);
    }
    if (strict and (result.uncited > 0 or report.unresolved > 0)) std.process.exit(1);
}

fn write(io: std.Io, arena: std.mem.Allocator, out: []const u8, path: []const u8, data: []const u8) !void {
    const full = try std.fmt.allocPrint(arena, "{s}/{s}", .{ out, path });
    if (std.mem.findScalarLast(u8, full, '/')) |slash| try std.Io.Dir.cwd().createDirPath(io, full[0..slash]);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = full, .data = data });
}
