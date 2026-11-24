//! The pages of the site: the Markdown files of the content directory, with
//! the few front matter fields the tools read.

const std = @import("std");

pub const Page = struct {
    /// Path without the extension, with forward slashes: `spec/lexical`.
    slug: []const u8,
    title: []const u8,
    description: ?[]const u8,
    sortorder: i64,
    tags: []const []const u8 = &.{},
    /// Further output paths of the page, `/spec/s0-grammar/index.html`: Zine writes it there too.
    aliases: []const []const u8 = &.{},
    /// The text after the front matter, with LF line ends.
    body: []const u8,

    /// The directory of the page: `spec` for `spec/lexical`, empty at the top.
    pub fn dir(self: Page) []const u8 {
        const slash = std.mem.findScalarLast(u8, self.slug, '/') orelse return "";
        return self.slug[0..slash];
    }

    pub fn basename(self: Page) []const u8 {
        const slash = std.mem.findScalarLast(u8, self.slug, '/') orelse return self.slug;
        return self.slug[slash + 1 ..];
    }

    fn lessThan(_: void, a: Page, b: Page) bool {
        if (a.sortorder != b.sortorder) return a.sortorder < b.sortorder;
        return std.mem.lessThan(u8, a.slug, b.slug);
    }
};

pub const LoadError = error{ OutOfMemory, ContentUnreadable };

/// Reads every `.md` file under `content_dir`, except those in
/// `private/`, `templates/` and `.obsidian/`, and the drafts. Sorted by `sortorder`, then by
/// path. Everything is allocated from `arena`.
pub fn load(arena: std.mem.Allocator, io: std.Io, content_dir: []const u8) LoadError![]Page {
    var dir = std.Io.Dir.cwd().openDir(io, content_dir, .{ .iterate = true }) catch return error.ContentUnreadable;
    defer dir.close(io);
    var walker = try dir.walk(arena);
    defer walker.deinit();

    var pages: std.ArrayList(Page) = .empty;
    while (walker.next(io) catch return error.ContentUnreadable) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.path, ".md")) continue;
        const path = try arena.dupe(u8, entry.path);
        std.mem.replaceScalar(u8, path, '\\', '/');
        if (ignored(path)) continue;
        const raw = entry.dir.readFileAlloc(io, entry.basename, arena, .limited(1 << 24)) catch
            return error.ContentUnreadable;
        const text = try std.mem.replaceOwned(u8, arena, raw, "\r\n", "\n");
        const page = try parse(arena, path[0 .. path.len - 3], text) orelse continue;
        try pages.append(arena, page);
    }
    std.mem.sort(Page, pages.items, {}, Page.lessThan);
    return pages.items;
}

fn ignored(path: []const u8) bool {
    for ([_][]const u8{ "private/", "templates/", ".obsidian/" }) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

/// Null for a draft.
fn parse(arena: std.mem.Allocator, slug: []const u8, text: []const u8) error{OutOfMemory}!?Page {
    var page: Page = .{ .slug = slug, .title = slug, .description = null, .sortorder = std.math.maxInt(i32), .body = text };
    if (std.mem.startsWith(u8, text, "---\n")) {
        const end = std.mem.find(u8, text[4..], "\n---") orelse return page;
        const header = text[4 .. 4 + end];
        const after = 4 + end + 4;
        page.body = std.mem.trimStart(u8, text[@min(after, text.len)..], "\n");
        var lines = std.mem.splitScalar(u8, header, '\n');
        while (lines.next()) |line| {
            const colon = std.mem.findScalar(u8, line, ':') orelse continue;
            const key = std.mem.trim(u8, line[0..colon], " ");
            const value = unquote(std.mem.trim(u8, line[colon + 1 ..], " "));
            if (std.mem.eql(u8, key, "title")) {
                page.title = try arena.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "description")) {
                page.description = try arena.dupe(u8, value);
            } else if (std.mem.eql(u8, key, "tags")) {
                page.tags = try parseTags(arena, value);
            } else if (std.mem.eql(u8, key, "aliases")) {
                page.aliases = try parseTags(arena, value);
            } else if (std.mem.eql(u8, key, "sortorder")) {
                page.sortorder = std.fmt.parseInt(i64, value, 10) catch page.sortorder;
            } else if (std.mem.eql(u8, key, "draft") and std.mem.eql(u8, value, "true")) {
                return null;
            }
        }
    }
    return page;
}

// `tags: "a"` or `tags: ["a", "b"]`
fn parseTags(arena: std.mem.Allocator, value: []const u8) error{OutOfMemory}![]const []const u8 {
    const inner = std.mem.trim(u8, value, "[]");
    var tags: std.ArrayList([]const u8) = .empty;
    var parts = std.mem.splitScalar(u8, inner, ',');
    while (parts.next()) |part| {
        const tag = unquote(std.mem.trim(u8, part, " "));
        if (tag.len > 0) try tags.append(arena, try arena.dupe(u8, tag));
    }
    return tags.items;
}

fn unquote(value: []const u8) []const u8 {
    if (value.len >= 2 and (value[0] == '"' or value[0] == '\'') and value[value.len - 1] == value[0]) {
        return value[1 .. value.len - 1];
    }
    return value;
}
