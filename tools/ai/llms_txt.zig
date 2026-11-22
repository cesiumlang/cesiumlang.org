//! `llms.txt` (llmstxt.org): an H1, a summary, and links in H2 sections that
//! point at the Markdown version of each page.

const std = @import("std");
const content = @import("content.zig");
const plain = @import("plain.zig");

const Page = content.Page;

const Section = struct { prefix: []const u8, heading: []const u8 };

const sections = [_]Section{
    .{ .prefix = "spec/", .heading = "Specification" },
    .{ .prefix = "reference/", .heading = "Language reference" },
    .{ .prefix = "compiler/", .heading = "Compiler" },
    .{ .prefix = "news/", .heading = "News" },
};

pub const summary = "Cesium is a compiled, statically typed systems programming language for mathematical " ++
    "computing, with explicit memory management and C ABI compatibility. The language is still being " ++
    "designed: the specification marks each rule Decided, Provisional or Open, and only Decided rules are settled.";

/// The text of `llms.txt`. `host` is the site's host name, as `cesiumlang.org`.
pub fn render(arena: std.mem.Allocator, pages: []const Page, host: []const u8, skill_name: []const u8) error{OutOfMemory}![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    w.print("# Cesium\n\n> {s}\n\n", .{summary}) catch return error.OutOfMemory;

    for (sections) |section| {
        var first = true;
        for (pages) |page| {
            if (!std.mem.startsWith(u8, page.slug, section.prefix)) continue;
            if (first) w.print("## {s}\n\n", .{section.heading}) catch return error.OutOfMemory;
            first = false;
            const words = try describe(arena, page);
            w.print("- [{s}](https://{s}/{s}.md)", .{ page.title, host, page.slug }) catch return error.OutOfMemory;
            if (words.len > 0) w.print(": {s}", .{words}) catch return error.OutOfMemory;
            w.writeByte('\n') catch return error.OutOfMemory;
        }
        if (!first) w.writeByte('\n') catch return error.OutOfMemory;
    }

    w.print(
        "## Optional\n\n- [Cesium skill for AI models](https://{s}/skill/{s}/SKILL.md): " ++
            "the decided rules in one line each, with the open questions, generated from the specification\n",
        .{ host, skill_name },
    ) catch return error.OutOfMemory;
    return out.written();
}

// the description of the page, or the first sentence of its first paragraph
fn describe(arena: std.mem.Allocator, page: Page) error{OutOfMemory}![]const u8 {
    if (page.description) |d| return d;
    var paragraph: std.ArrayList(u8) = .empty;
    var in_fence = false;
    var lines = std.mem.splitScalar(u8, page.body, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " ");
        if (std.mem.startsWith(u8, trimmed, "```")) in_fence = !in_fence;
        const prose = !in_fence and trimmed.len > 0 and std.mem.findScalar(u8, "#>|-*`", trimmed[0]) == null and
            !std.ascii.isDigit(trimmed[0]);
        if (!prose) {
            if (paragraph.items.len > 0) break;
            continue;
        }
        if (paragraph.items.len > 0) try paragraph.append(arena, ' ');
        try paragraph.appendSlice(arena, trimmed);
    }
    const words = try plain.text(arena, paragraph.items);
    // whole sentences, until there are enough words to tell the page
    var end: usize = 0;
    while (end < words.len and end < 120) {
        end += (std.mem.find(u8, words[end..], ". ") orelse words.len - end) + 1;
    }
    end = @min(end, words.len);
    return if (end > 220) words[0..220] else words[0..end];
}
