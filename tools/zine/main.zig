//! cesium-site-gen [--content DIR] [--site DIR]
//!
//! Turns the Markdown pages of the site (`content/`) into what Zine builds:
//! SuperMD files in `SITE/content/`, the tag pages, the images in
//! `SITE/assets/img/`, and `SITE/assets/site-index.json` for the explorer and
//! the search. Everything it writes is generated; the layouts and styles in
//! SITE are written by hand.

const std = @import("std");
const ai = @import("ai");
const highlight = @import("highlight");
const site_json = @import("site_json.zig");
const smd = @import("smd.zig");
const tags = @import("tags.zig");

const usage = "usage: cesium-site-gen [--content DIR] [--site DIR]\n";

/// The date of a page that git does not know yet.
const fallback_date = "2025-09-01T00:00:00";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var arena_state: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var content_dir: []const u8 = "content";
    var site_dir: []const u8 = "site";
    var i: usize = 1;
    while (i < args.len) : (i += 2) {
        if (i + 1 < args.len and std.mem.eql(u8, args[i], "--content")) {
            content_dir = args[i + 1];
        } else if (i + 1 < args.len and std.mem.eql(u8, args[i], "--site")) {
            site_dir = args[i + 1];
        } else {
            try std.Io.File.stderr().writeStreamingAll(io, usage);
            std.process.exit(2);
        }
    }

    const pages = try ai.content.load(arena, io, content_dir);
    var highlighter = try highlight.Highlighter.init();
    defer highlighter.deinit();
    var report: ai.portable.Report = .{};

    const generated = try std.fmt.allocPrint(arena, "{s}/content", .{site_dir});
    std.Io.Dir.cwd().deleteTree(io, generated) catch {};

    // the compiler version the pages are of, as tools/take-spec.sh wrote it
    // (cesiumlang.org#42); none for a site built without it
    const version_path = try std.fmt.allocPrint(arena, "{s}/cesium-version.txt", .{content_dir});
    const version: ?[]const u8 = if (std.Io.Dir.cwd().readFileAlloc(io, version_path, arena, .limited(1 << 12))) |text|
        std.mem.trim(u8, text, " \r\n")
    else |_|
        null;

    var entries: std.ArrayList(site_json.Entry) = .empty;
    for (pages) |page| {
        const date = try gitDate(arena, io, content_dir, page);
        const rendered = try smd.render(arena, pages, page, date, version, &highlighter, &report);
        try write(io, arena, generated, try std.fmt.allocPrint(arena, "{s}.smd", .{page.slug}), rendered.text);
        try entries.append(arena, .{
            .page = page,
            .headings = rendered.headings,
            .links = try ai.portable.linkTargets(arena, pages, page),
        });
    }
    for (try tags.render(arena, pages, fallback_date)) |tag_page| {
        try write(io, arena, generated, try std.fmt.allocPrint(arena, "{s}.smd", .{tag_page.slug}), tag_page.text);
    }
    const assets = try std.fmt.allocPrint(arena, "{s}/assets", .{site_dir});
    try write(io, arena, assets, "site-index.json", try site_json.render(arena, entries.items));
    try copyImages(io, arena, try std.fmt.allocPrint(arena, "{s}/assets", .{content_dir}), assets);

    std.debug.print("{d} pages, {d} unresolved links\n", .{ pages.len, report.unresolved });
}

fn write(io: std.Io, arena: std.mem.Allocator, dir: []const u8, path: []const u8, data: []const u8) !void {
    const full = try std.fmt.allocPrint(arena, "{s}/{s}", .{ dir, path });
    if (std.mem.findScalarLast(u8, full, '/')) |slash| try std.Io.Dir.cwd().createDirPath(io, full[0..slash]);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = full, .data = data });
}

// the files of content/assets, as site/assets/img/
fn copyImages(io: std.Io, arena: std.mem.Allocator, from: []const u8, assets: []const u8) !void {
    var dir = std.Io.Dir.cwd().openDir(io, from, .{ .iterate = true }) catch return;
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        const data = try entry.dir.readFileAlloc(io, entry.basename, arena, .limited(1 << 26));
        try write(io, arena, try std.fmt.allocPrint(arena, "{s}/img", .{assets}), entry.path, data);
    }
}

// the date of the last commit that touched the page, as Zine writes dates
fn gitDate(arena: std.mem.Allocator, io: std.Io, content_dir: []const u8, page: ai.content.Page) ![]const u8 {
    const path = try std.fmt.allocPrint(arena, "{s}/{s}.md", .{ content_dir, page.slug });
    const result = std.process.run(arena, io, .{
        .argv = &.{ "git", "log", "-1", "--format=%cI", "--", path },
        .stdout_limit = .limited(256),
    }) catch return fallback_date;
    const text = std.mem.trim(u8, result.stdout, " \r\n");
    if (!result.term.success() or text.len < 19) return fallback_date;
    return try arena.dupe(u8, text[0..19]);
}
