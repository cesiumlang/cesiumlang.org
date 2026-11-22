//! A page as plain Markdown that any reader or generator takes: no front
//! matter, and callouts as bold labels in block quotes. Links are relative
//! links to `.md` files already and are left as they are. Code is left as it is.

const std = @import("std");
const content = @import("content.zig");
const links = @import("links.zig");

const Page = content.Page;

/// What was found that does not resolve, and optionally where the page links.
pub const Report = struct {
    /// Links to a `.md` file that is not a page of the site.
    unresolved: usize = 0,
    /// If set, the site path of every page linked is added (once).
    targets: ?*std.ArrayList([]const u8) = null,
    /// For the list of targets.
    arena: ?std.mem.Allocator = null,
};

/// The text of `page`, headed by its title. `pages` is the whole site, for
/// the check of its links. Allocated from `arena`.
pub fn render(arena: std.mem.Allocator, pages: []const Page, page: Page, report: *Report) error{OutOfMemory}![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try put(w, "# ");
    try put(w, page.title);
    try put(w, "\n\n");

    var in_fence = false;
    var lines = std.mem.splitScalar(u8, page.body, '\n');
    while (lines.next()) |line| {
        if (isFence(line)) in_fence = !in_fence;
        if (in_fence or isFence(line)) {
            try put(w, line);
        } else {
            const text = try calloutAsBold(arena, line);
            try writeInline(w, pages, page, text, false, report);
        }
        try put(w, "\n");
    }
    return out.written();
}

/// The site paths of the pages that `page` links to, each once. Allocated
/// from `arena`.
pub fn linkTargets(arena: std.mem.Allocator, pages: []const Page, page: Page) error{OutOfMemory}![]const []const u8 {
    var targets: std.ArrayList([]const u8) = .empty;
    var report: Report = .{ .targets = &targets, .arena = arena };
    var sink: std.Io.Writer.Discarding = .init(&.{});
    var in_fence = false;
    var lines = std.mem.splitScalar(u8, page.body, '\n');
    while (lines.next()) |line| {
        if (isFence(line)) in_fence = !in_fence;
        if (!in_fence and !isFence(line)) try writeInline(&sink.writer, pages, page, line, false, &report);
    }
    return targets.items;
}

fn isFence(line: []const u8) bool {
    const trimmed = std.mem.trimStart(u8, line, " ");
    return std.mem.startsWith(u8, trimmed, "```") or std.mem.startsWith(u8, trimmed, "~~~");
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

/// `text` as it is, but with the links to other pages written as Zine wants
/// them (`[words]($link.page('dir/page').id('heading'))`) when `for_zine`.
/// The links found are counted and listed in `report`; code spans are left alone.
pub fn writeInline(w: *std.Io.Writer, pages: []const Page, page: Page, text: []const u8, for_zine: bool, report: *Report) error{OutOfMemory}!void {
    var in_code = false;
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (c == '`') in_code = !in_code;
        if (!in_code and c == ']') {
            if (links.at(pages, page, text, i)) |link| {
                if (link.page) |target| {
                    try note(report, target);
                    if (for_zine) {
                        try writeZineTarget(w, target, link.anchor);
                        i = link.end;
                        continue;
                    }
                } else {
                    report.unresolved += 1;
                    std.debug.print("warning: {s}: no page for {s}\n", .{ page.slug, text[i..link.end] });
                }
            }
        }
        w.writeByte(c) catch return error.OutOfMemory;
        i += 1;
    }
}

fn note(report: *Report, target: Page) error{OutOfMemory}!void {
    const list = report.targets orelse return;
    const slug = siteSlug(target);
    for (list.items) |known| {
        if (std.mem.eql(u8, known, slug)) return;
    }
    try list.append(report.arena.?, slug);
}

fn writeZineTarget(w: *std.Io.Writer, target: Page, anchor: ?[]const u8) error{OutOfMemory}!void {
    try put(w, "]($link.page('");
    try put(w, siteSlug(target));
    try put(w, "')");
    if (anchor) |id| {
        try put(w, ".id('");
        try put(w, id);
        try put(w, "')");
    }
    try put(w, ")");
}

/// The path of the page on the site: an index page is its directory.
pub fn siteSlug(page: Page) []const u8 {
    if (std.mem.eql(u8, page.basename(), "index")) return page.dir();
    return page.slug;
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
