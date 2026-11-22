//! A page as plain Markdown that any reader or generator takes: no front
//! matter, wiki links as relative links to `.md` files, callouts as bold
//! labels in block quotes. Code is left as it is.

const std = @import("std");
const content = @import("content.zig");

const Page = content.Page;

/// How a link to another page is written.
pub const LinkStyle = enum {
    /// `[words](../dir/page.md#heading)`, for any Markdown reader.
    relative_markdown,
    /// `[words]($link.page('dir/page').id('heading'))`, for Zine.
    zine,
};

/// What `render` could not resolve.
pub const Report = struct {
    unresolved: usize = 0,
};

/// The text of `page`, headed by its title. `pages` is the whole site, for
/// the targets of links. Allocated from `arena`.
pub fn render(arena: std.mem.Allocator, pages: []const Page, page: Page, report: *Report) error{OutOfMemory}![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try put(w, "# ");
    try put(w, page.title);
    try put(w, "\n\n");

    var in_fence = false;
    var lines = std.mem.splitScalar(u8, page.body, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " ");
        if (std.mem.startsWith(u8, trimmed, "```") or std.mem.startsWith(u8, trimmed, "~~~")) in_fence = !in_fence;
        if (in_fence or std.mem.startsWith(u8, trimmed, "```") or std.mem.startsWith(u8, trimmed, "~~~")) {
            try put(w, line);
        } else {
            const text = try calloutAsBold(arena, line);
            try writeInline(w, pages, page, text, .relative_markdown, report);
        }
        try put(w, "\n");
    }
    return out.written();
}

fn put(w: *std.Io.Writer, text: []const u8) error{OutOfMemory}!void {
    w.writeAll(text) catch return error.OutOfMemory;
}

/// A callout opening, `> [!warning]- Draft`: its kind and title (empty if none).
pub const Callout = struct { kind: []const u8, title: []const u8 };

/// The callout a line opens, or null.
pub fn parseCallout(line: []const u8) ?Callout {
    const marker = "> [!";
    if (!std.mem.startsWith(u8, line, marker)) return null;
    const close = std.mem.findScalar(u8, line, ']') orelse return null;
    const rest = std.mem.trimStart(u8, line[close + 1 ..], "+- ");
    return .{ .kind = line[marker.len..close], .title = std.mem.trim(u8, rest, " ") };
}

// `> [!warning] Draft` becomes `> **Warning: Draft**`; other lines are returned as they are
fn calloutAsBold(arena: std.mem.Allocator, line: []const u8) error{OutOfMemory}![]const u8 {
    const callout = parseCallout(line) orelse return line;
    var label = try arena.dupe(u8, callout.kind);
    if (label.len > 0) label[0] = std.ascii.toUpper(label[0]);
    if (callout.title.len == 0) return std.fmt.allocPrint(arena, "> **{s}**", .{label});
    return std.fmt.allocPrint(arena, "> **{s}: {s}**", .{ label, callout.title });
}

/// `text` with its wiki links written as `style` says; code spans are left alone.
pub fn writeInline(w: *std.Io.Writer, pages: []const Page, page: Page, text: []const u8, style: LinkStyle, report: *Report) error{OutOfMemory}!void {
    var in_code = false;
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (c == '`') in_code = !in_code;
        if (!in_code and std.mem.startsWith(u8, text[i..], "[[")) {
            if (std.mem.find(u8, text[i + 2 ..], "]]")) |len| {
                try writeWikiLink(w, pages, page, text[i + 2 .. i + 2 + len], style, report);
                i += len + 4;
                continue;
            }
        }
        w.writeByte(c) catch return error.OutOfMemory;
        i += 1;
    }
}

// `inner` is what stands between the brackets: `target`, `target|words`,
// `target#heading|words`; a table writes the bar as `\|`.
fn writeWikiLink(w: *std.Io.Writer, pages: []const Page, page: Page, inner: []const u8, style: LinkStyle, report: *Report) error{OutOfMemory}!void {
    var target = inner;
    var alias: ?[]const u8 = null;
    if (std.mem.findScalar(u8, inner, '|')) |bar| {
        target = std.mem.trimEnd(u8, inner[0..bar], "\\");
        alias = std.mem.trim(u8, inner[bar + 1 ..], " ");
    }
    var heading: ?[]const u8 = null;
    if (std.mem.findScalar(u8, target, '#')) |hash| {
        heading = target[hash + 1 ..];
        target = target[0..hash];
    }
    const found = if (target.len == 0) page else resolve(pages, page, target) orelse {
        report.unresolved += 1;
        std.debug.print("warning: {s}: no page for [[{s}]]\n", .{ page.slug, inner });
        try put(w, alias orelse target);
        return;
    };
    try put(w, "[");
    try put(w, alias orelse if (heading != null and target.len == 0) heading.? else found.title);
    switch (style) {
        .relative_markdown => {
            try put(w, "](");
            if (target.len != 0) try writeRelative(w, page, found);
            if (heading) |h| {
                try put(w, "#");
                try writeAnchor(w, h);
            }
            try put(w, ")");
        },
        .zine => {
            if (target.len == 0) {
                try put(w, "]($link.ref('");
                try writeAnchor(w, heading.?);
                try put(w, "'))");
                return;
            }
            try put(w, "]($link.page('");
            try put(w, siteSlug(found));
            try put(w, "')");
            if (heading) |h| {
                try put(w, ".id('");
                try writeAnchor(w, h);
                try put(w, "')");
            }
            try put(w, ")");
        },
    }
}

/// The path of the page on the site: an index page is its directory.
pub fn siteSlug(page: Page) []const u8 {
    if (std.mem.eql(u8, page.basename(), "index")) return page.dir();
    return page.slug;
}

/// The page a wiki link names: by its path without the extension, else by
/// the end of its path, else by its file name.
pub fn resolve(pages: []const Page, from: Page, target: []const u8) ?Page {
    const name = if (std.mem.endsWith(u8, target, ".md")) target[0 .. target.len - 3] else target;
    for (pages) |p| {
        if (std.mem.eql(u8, p.slug, name)) return p;
    }
    for (pages) |p| {
        if (p.slug.len > name.len and std.mem.endsWith(u8, p.slug, name) and p.slug[p.slug.len - name.len - 1] == '/') return p;
    }
    // the same directory first, as Quartz's shortest links prefer
    for (pages) |p| {
        if (std.mem.eql(u8, p.dir(), from.dir()) and std.mem.eql(u8, p.basename(), name)) return p;
    }
    return null;
}

/// `to` as a path relative to the directory of `from`, ending in `.md`.
pub fn writeRelative(w: *std.Io.Writer, from: Page, to: Page) error{OutOfMemory}!void {
    var from_dirs: [16][]const u8 = undefined;
    var to_dirs: [16][]const u8 = undefined;
    const from_n = segments(from.dir(), &from_dirs);
    const to_n = segments(to.dir(), &to_dirs);
    var shared: usize = 0;
    while (shared < from_n and shared < to_n and std.mem.eql(u8, from_dirs[shared], to_dirs[shared])) shared += 1;
    for (shared..from_n) |_| try put(w, "../");
    for (to_dirs[shared..to_n]) |segment| {
        try put(w, segment);
        try put(w, "/");
    }
    try put(w, to.basename());
    try put(w, ".md");
}

fn segments(path: []const u8, out: *[16][]const u8) usize {
    var n: usize = 0;
    var it = std.mem.tokenizeScalar(u8, path, '/');
    while (it.next()) |segment| : (n += 1) {
        if (n == out.len) break;
        out[n] = segment;
    }
    return n;
}

/// The id a heading gets on GitHub: lower case, spaces to hyphens, punctuation dropped.
pub fn writeAnchor(w: *std.Io.Writer, heading: []const u8) error{OutOfMemory}!void {
    for (heading) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '_' or c == '-') {
            w.writeByte(std.ascii.toLower(c)) catch return error.OutOfMemory;
        } else if (c == ' ') {
            w.writeByte('-') catch return error.OutOfMemory;
        }
    }
}
