//! `site-index.json`: every page with its place in the tree, its order, tags,
//! headings and the start of its text. The explorer and the search of the
//! site read it; nothing in it depends on the generator that builds the pages.

const std = @import("std");
const ai = @import("ai");
const smd = @import("smd.zig");

const Page = ai.content.Page;

pub const Entry = struct {
    page: Page,
    headings: []const smd.Heading,
};

/// How much of a page's text the search can see.
const excerpt_bytes = 4000;

pub fn render(arena: std.mem.Allocator, entries: []const Entry) error{OutOfMemory}![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try put(w, "[\n");
    for (entries, 0..) |entry, i| {
        if (i > 0) try put(w, ",\n");
        const page = entry.page;
        try put(w, "{\"slug\":");
        try string(w, ai.portable.siteSlug(page));
        try put(w, ",\"index\":");
        try put(w, if (std.mem.eql(u8, page.basename(), "index")) "true" else "false");
        try put(w, ",\"title\":");
        try string(w, page.title);
        try put(w, ",\"order\":");
        try number(w, page.sortorder);
        try put(w, ",\"tags\":[");
        for (page.tags, 0..) |tag, t| {
            if (t > 0) try put(w, ",");
            try string(w, tag);
        }
        try put(w, "],\"headings\":[");
        for (entry.headings, 0..) |heading, h| {
            if (h > 0) try put(w, ",");
            try put(w, "{\"depth\":");
            try number(w, heading.depth);
            try put(w, ",\"text\":");
            try string(w, heading.text);
            try put(w, ",\"id\":");
            try string(w, heading.id);
            try put(w, "}");
        }
        try put(w, "],\"text\":");
        try string(w, try excerpt(arena, page));
        try put(w, "}");
    }
    try put(w, "\n]\n");
    return out.written();
}

fn put(w: *std.Io.Writer, text: []const u8) error{OutOfMemory}!void {
    w.writeAll(text) catch return error.OutOfMemory;
}

fn number(w: *std.Io.Writer, value: i64) error{OutOfMemory}!void {
    w.print("{d}", .{value}) catch return error.OutOfMemory;
}

// the prose of a page, without its code, cut at a character boundary
fn excerpt(arena: std.mem.Allocator, page: Page) error{OutOfMemory}![]const u8 {
    var prose: std.ArrayList(u8) = .empty;
    var in_fence = false;
    var lines = std.mem.splitScalar(u8, page.body, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, std.mem.trimStart(u8, line, " "), "```")) {
            in_fence = !in_fence;
            continue;
        }
        if (in_fence) continue;
        try prose.appendSlice(arena, line);
        try prose.append(arena, '\n');
    }
    const words = try ai.plain.text(arena, prose.items);
    var end = @min(words.len, excerpt_bytes);
    while (end > 0 and end < words.len and words[end] & 0xC0 == 0x80) end -= 1;
    return words[0..end];
}

fn string(w: *std.Io.Writer, text: []const u8) error{OutOfMemory}!void {
    try put(w, "\"");
    for (text) |c| {
        switch (c) {
            '"' => try put(w, "\\\""),
            '\\' => try put(w, "\\\\"),
            '\n' => try put(w, "\\n"),
            '\r' => try put(w, "\\r"),
            '\t' => try put(w, "\\t"),
            0...8, 11, 12, 14...31 => w.print("\\u{x:0>4}", .{c}) catch return error.OutOfMemory,
            else => w.writeByte(c) catch return error.OutOfMemory,
        }
    }
    try put(w, "\"");
}
