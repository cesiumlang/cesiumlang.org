//! The tag pages: `tags/index` lists the tags, `tags/NAME` the pages that
//! carry one.

const std = @import("std");
const ai = @import("ai");
const smd = @import("smd.zig");

const Page = ai.content.Page;

pub const TagPage = struct {
    slug: []const u8,
    text: []const u8,
};

/// The tag pages for `pages`, as SuperMD with the given date. Allocated
/// from `arena`.
pub fn render(arena: std.mem.Allocator, pages: []const Page, date: []const u8) error{OutOfMemory}![]TagPage {
    var names: std.ArrayList([]const u8) = .empty;
    for (pages) |page| {
        for (page.tags) |tag| {
            if (!contains(names.items, tag)) try names.append(arena, tag);
        }
    }
    std.mem.sort([]const u8, names.items, {}, lessThan);

    var result: std.ArrayList(TagPage) = .empty;
    var all: std.Io.Writer.Allocating = .init(arena);
    try head(&all.writer, "Tags", date);
    for (names.items) |name| {
        var one: std.Io.Writer.Allocating = .init(arena);
        const title = try std.fmt.allocPrint(arena, "Tag: {s}", .{name});
        try head(&one.writer, title, date);
        var count: usize = 0;
        for (pages) |page| {
            if (!contains(page.tags, name)) continue;
            count += 1;
            one.writer.print("- [{s}]($link.page('{s}'))\n", .{ page.title, ai.portable.siteSlug(page) }) catch return error.OutOfMemory;
        }
        const slug = try tagSlug(arena, name);
        try result.append(arena, .{ .slug = try std.fmt.allocPrint(arena, "tags/{s}", .{slug}), .text = one.written() });
        all.writer.print("- [{s}]($link.page('tags/{s}')) ({d})\n", .{ name, slug, count }) catch return error.OutOfMemory;
    }
    try result.append(arena, .{ .slug = "tags/index", .text = all.written() });
    return result.items;
}

fn head(w: *std.Io.Writer, title: []const u8, date: []const u8) error{OutOfMemory}!void {
    w.writeAll("---\n.title = ") catch return error.OutOfMemory;
    try smd.ziggyString(w, title);
    w.print(",\n.date = .date(\"{s}\"),\n.layout = \"page.shtml\",\n---\n\n", .{date}) catch return error.OutOfMemory;
}

fn contains(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |item| {
        if (std.mem.eql(u8, item, needle)) return true;
    }
    return false;
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// A tag as a file name: lower case, anything but letters and digits a hyphen.
fn tagSlug(arena: std.mem.Allocator, tag: []const u8) error{OutOfMemory}![]const u8 {
    const slug = try arena.dupe(u8, tag);
    for (slug) |*c| c.* = if (std.ascii.isAlphanumeric(c.*)) std.ascii.toLower(c.*) else '-';
    return slug;
}
