//! A page as Zine reads it (SuperMD): Ziggy front matter, headings with
//! explicit ids, callouts as blocks, links as `$link.page`, and every code
//! block as finished HTML, Cesium highlighted by the Tree-sitter grammar.

const std = @import("std");
const ai = @import("ai");
const highlight = @import("highlight");

const Page = ai.content.Page;

pub const Heading = struct {
    depth: u8,
    text: []const u8,
    id: []const u8,
};

pub const Rendered = struct {
    text: []const u8,
    headings: []const Heading,
};

pub const Error = error{OutOfMemory};

/// `date` is `YYYY-MM-DDTHH:MM:SS`. Allocated from `arena`.
pub fn render(
    arena: std.mem.Allocator,
    pages: []const Page,
    page: Page,
    date: []const u8,
    highlighter: *highlight.Highlighter,
    report: *ai.portable.Report,
) Error!Rendered {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try frontMatter(w, page, date);

    var headings: std.ArrayList(Heading) = .empty;
    var ids: std.StringHashMapUnmanaged(void) = .empty;
    var code: std.ArrayList(u8) = .empty;
    var lang: []const u8 = "";
    var in_fence = false;
    // what stands before a fence inside a block quote: `> `
    var quote: []const u8 = "";

    var lines = std.mem.splitScalar(u8, page.body, '\n');
    while (lines.next()) |line| {
        const prefix = quotePrefix(line);
        const trimmed = std.mem.trimStart(u8, line[prefix.len..], " ");
        if (std.mem.startsWith(u8, trimmed, "```")) {
            if (!in_fence) {
                in_fence = true;
                quote = prefix;
                lang = std.mem.trim(u8, trimmed[3..], " ");
                if (std.mem.findScalar(u8, lang, ' ')) |space| lang = lang[0..space];
                code.clearRetainingCapacity();
            } else {
                in_fence = false;
                var block: std.Io.Writer.Allocating = .init(arena);
                try codeBlock(arena, &block.writer, highlighter, lang, std.mem.trimEnd(u8, code.items, "\n"));
                var block_lines = std.mem.splitScalar(u8, std.mem.trimEnd(u8, block.written(), "\n"), '\n');
                while (block_lines.next()) |block_line| {
                    try put(w, quote);
                    try put(w, block_line);
                    try put(w, "\n");
                }
            }
            continue;
        }
        if (in_fence) {
            try code.appendSlice(arena, line[@min(quotePrefix(line).len, quote.len)..]);
            try code.append(arena, '\n');
            continue;
        }
        if (headingLevel(line)) |level| {
            const text = std.mem.trim(u8, line[level..], " ");
            const words = try ai.plain.text(arena, text);
            const id = try uniqueId(arena, &ids, words);
            try headings.append(arena, .{ .depth = @intCast(level), .text = words, .id = id });
            try put(w, line[0..level]);
            try put(w, " [");
            try ai.portable.writeInline(w, pages, page, text, true, report);
            try put(w, "]($section.id('");
            try put(w, id);
            try put(w, "'))\n");
            continue;
        }
        if (ai.portable.parseCallout(line)) |callout| {
            // a block's class is one word; the label is the kind, capitalized
            try put(w, "># [");
            if (callout.kind.len > 0) {
                w.writeByte(std.ascii.toUpper(callout.kind[0])) catch return error.OutOfMemory;
                try put(w, callout.kind[1..]);
            }
            if (callout.title.len > 0) {
                try put(w, ": ");
                try put(w, callout.title);
            }
            try put(w, "]($block.attrs('callout-");
            try put(w, callout.kind);
            try put(w, "'))\n");
            continue;
        }
        try ai.portable.writeInline(w, pages, page, try skeinAnchors(arena, line), true, report);
        try put(w, "\n");
    }
    return .{ .text = out.written(), .headings = headings.items };
}

/// Skein's labels (`skein render --format markdown`) in SuperMD, which has no
/// HTML: `<a id="X"></a>**[X](#X)**` becomes `**[X]($text.id('X'))**`, the
/// ID carrying its anchor; an anchor without that label is dropped.
fn skeinAnchors(arena: std.mem.Allocator, line: []const u8) Error![]const u8 {
    const open = "<a id=\"";
    const close = "\"></a>";
    if (std.mem.find(u8, line, open) == null) return line;
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (std.mem.findPos(u8, line, i, open)) |at| {
        const id_start = at + open.len;
        const id_end = std.mem.findPos(u8, line, id_start, close) orelse break;
        const id = line[id_start..id_end];
        try out.appendSlice(arena, line[i..at]);
        i = id_end + close.len;
        const bold = std.mem.startsWith(u8, line[i..], "**");
        const label = try std.fmt.allocPrint(arena, "[{s}](#{s})", .{ id, id });
        const after = i + @as(usize, if (bold) 2 else 0);
        if (std.mem.startsWith(u8, line[after..], label)) {
            try out.appendSlice(arena, line[i..after]);
            try out.print(arena, "[{s}]($text.id('{s}'))", .{ id, id });
            i = after + label.len;
        }
    }
    try out.appendSlice(arena, line[i..]);
    return out.items;
}

test skeinAnchors {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expectEqualStrings("**[lex.x]($text.id('lex.x'))** *(syntax, draft)* Text.", try skeinAnchors(a, "<a id=\"lex.x\"></a>**[lex.x](#lex.x)** *(syntax, draft)* Text."));
    try std.testing.expectEqualStrings("- [a.b]($text.id('a.b')) part", try skeinAnchors(a, "- <a id=\"a.b\"></a>[a.b](#a.b) part"));
    try std.testing.expectEqualStrings("plain [x](#y)", try skeinAnchors(a, "plain [x](#y)"));
    try std.testing.expectEqualStrings("lone ", try skeinAnchors(a, "lone <a id=\"z\"></a>"));
}

fn put(w: *std.Io.Writer, text: []const u8) Error!void {
    w.writeAll(text) catch return error.OutOfMemory;
}

/// The depth of an ATX heading line, or null.
fn headingLevel(line: []const u8) ?usize {
    var n: usize = 0;
    while (n < line.len and line[n] == '#') n += 1;
    if (n == 0 or n > 6 or n >= line.len or line[n] != ' ') return null;
    return n;
}

// the GitHub id of a heading, made unique within the page
fn uniqueId(arena: std.mem.Allocator, ids: *std.StringHashMapUnmanaged(void), words: []const u8) Error![]const u8 {
    var buffer: std.Io.Writer.Allocating = .init(arena);
    try ai.portable.writeAnchor(&buffer.writer, words);
    var id: []const u8 = buffer.written();
    if (id.len == 0) id = "section";
    var n: usize = 0;
    while (ids.contains(id)) {
        n += 1;
        id = try std.fmt.allocPrint(arena, "{s}-{d}", .{ buffer.written(), n });
    }
    try ids.put(arena, id, {});
    return id;
}

fn frontMatter(w: *std.Io.Writer, page: Page, date: []const u8) Error!void {
    try put(w, "---\n.title = ");
    try ziggyString(w, page.title);
    try put(w, ",\n");
    if (page.description) |description| {
        try put(w, ".description = ");
        try ziggyString(w, description);
        try put(w, ",\n");
    }
    try put(w, ".date = .date(\"");
    try put(w, date);
    try put(w, "\"),\n.layout = \"page.shtml\",\n");
    if (page.tags.len > 0) {
        try put(w, ".tags = [");
        for (page.tags, 0..) |tag, i| {
            if (i > 0) try put(w, ", ");
            try ziggyString(w, tag);
        }
        try put(w, "],\n");
    }
    if (page.aliases.len > 0) {
        try put(w, ".aliases = [");
        for (page.aliases, 0..) |alias, i| {
            if (i > 0) try put(w, ", ");
            try ziggyString(w, alias);
        }
        try put(w, "],\n");
    }
    try put(w, "---\n");
}

pub fn ziggyString(w: *std.Io.Writer, text: []const u8) Error!void {
    try put(w, "\"");
    for (text) |c| {
        switch (c) {
            '"' => try put(w, "\\\""),
            '\\' => try put(w, "\\\\"),
            '\n' => try put(w, "\\n"),
            else => w.writeByte(c) catch return error.OutOfMemory,
        }
    }
    try put(w, "\"");
}

// A block of code as HTML. Cesium, and code with no language, is highlighted.
fn codeBlock(arena: std.mem.Allocator, w: *std.Io.Writer, highlighter: *highlight.Highlighter, lang: []const u8, code: []const u8) Error!void {
    const is_cesium = lang.len == 0 or std.mem.eql(u8, lang, "cesium") or std.mem.eql(u8, lang, "csm");
    try put(w, "```=html\n<pre class=\"highlight\"><code class=\"language-");
    try put(w, if (is_cesium) "cesium" else if (lang.len > 0) lang else "text");
    try put(w, "\">");
    if (is_cesium) {
        var buffer: std.Io.Writer.Allocating = .init(arena);
        if (highlighter.writeHtml(arena, code, &buffer.writer)) {
            try put(w, buffer.written());
            try put(w, "</code></pre>\n```\n");
            return;
        } else |_| {}
    }
    try escaped(w, code);
    try put(w, "</code></pre>\n```\n");
}

pub fn escaped(w: *std.Io.Writer, text: []const u8) Error!void {
    for (text) |c| {
        switch (c) {
            '&' => try put(w, "&amp;"),
            '<' => try put(w, "&lt;"),
            '>' => try put(w, "&gt;"),
            else => w.writeByte(c) catch return error.OutOfMemory,
        }
    }
}

// the `> ` marks at the start of a line of a block quote
fn quotePrefix(line: []const u8) []const u8 {
    var n: usize = 0;
    while (n < line.len and (line[n] == '>' or (line[n] == ' ' and n > 0 and line[n - 1] == '>'))) n += 1;
    return line[0..n];
}
