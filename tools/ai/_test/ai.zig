const std = @import("std");
const ai = @import("ai");

const Page = ai.content.Page;

fn page(slug: []const u8, title: []const u8, body: []const u8) Page {
    return .{ .slug = slug, .title = title, .description = null, .sortorder = 0, .body = body };
}

const site = [_]Page{
    page("spec/index", "Specification", ""),
    page("spec/lexical", "Lexical", ""),
    page("reference/memory-management", "Memory Management", ""),
};

test "a page of an edition knows its release; the site's own pages have none" {
    try std.testing.expectEqualStrings("0.1.0", page("v0.1.0/spec/lexical", "", "").edition().?);
    try std.testing.expectEqualStrings("12.3.45", page("v12.3.45/index", "", "").edition().?);
    try std.testing.expect(page("spec/lexical", "", "").edition() == null);
    try std.testing.expect(page("v0.1/spec", "", "").edition() == null);
    try std.testing.expect(page("vision/index", "", "").edition() == null);
    try std.testing.expect(page("v0.1.x/spec", "", "").edition() == null);
}

test "a callout becomes a bold label; links to pages are left as they are" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var report: ai.portable.Report = .{};
    const from = page(
        "spec/lexical",
        "Lexical",
        "See [the introduction](index.md) and [memory](../reference/memory-management.md#open-questions).\n> [!warning] Draft\n> text\n",
    );
    const text = try ai.portable.render(arena.allocator(), &site, from, &report);
    try std.testing.expectEqualStrings(
        "# Lexical\n\nSee [the introduction](index.md) and [memory](../reference/memory-management.md#open-questions).\n" ++
            "> **Warning: Draft**\n> text\n\n",
        text,
    );
    try std.testing.expectEqual(0, report.unresolved);
}

test "a link to a file that is no page is counted" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var report: ai.portable.Report = .{};
    const from = page("spec/lexical", "Lexical", "[gone](missing.md) and [web](https://x.y/a.md) and [here](#top)\n");
    _ = try ai.portable.render(arena.allocator(), &site, from, &report);
    try std.testing.expectEqual(1, report.unresolved);
}

test "code is left alone" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var report: ai.portable.Report = .{};
    const p = page("a", "A", "```cesium\nx = [a](b.md);\n```\nand `[c](d.md)`\n");
    const text = try ai.portable.render(arena.allocator(), &.{p}, p, &report);
    try std.testing.expectEqualStrings("# A\n\n```cesium\nx = [a](b.md);\n```\nand `[c](d.md)`\n\n", text);
    try std.testing.expectEqual(0, report.unresolved);
}

test "links as Zine writes them" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var out: std.Io.Writer.Allocating = .init(arena.allocator());
    var report: ai.portable.Report = .{};
    const from = site[1];
    try ai.portable.writeInline(
        &out.writer,
        &site,
        from,
        "[intro](index.md), [memory](../reference/memory-management.md#open-questions), [web](https://a.b/c)",
        true,
        &report,
    );
    try std.testing.expectEqualStrings(
        "[intro]($link.page('spec')), [memory]($link.page('reference/memory-management').ref('open-questions')), [web](https://a.b/c)",
        out.written(),
    );
}

test "the pages a page links to, once each" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const from = page("spec/lexical", "Lexical", "[a](index.md) [b](index.md#x) [c](../reference/memory-management.md)\n```\n[d](index.md)\n```\n");
    const targets = try ai.portable.linkTargets(arena.allocator(), &site, from);
    try std.testing.expectEqual(2, targets.len);
    try std.testing.expectEqualStrings("spec", targets[0]);
    try std.testing.expectEqualStrings("reference/memory-management", targets[1]);
}

test "links, emphasis and line ends become plain text" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try ai.plain.text(arena.allocator(), "**Decided.** See [the issue](https://x.y/1) and [the\nintroduction](index.md), `a [b](c)`.");
    try std.testing.expectEqualStrings("Decided. See the issue and the introduction, `a [b](c)`.", got);
}

test "Skein's labels: rules by their source, parts, open points, examples left out" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const p = page(
        "spec/x",
        "X",
        "<a id=\"lex.ext\"></a>**[lex.ext](#lex.ext)** *(syntax, draft)* A file has the extension `.csm`.\nNothing else. Decided in [#14].\n\n" ++
            "- <a id=\"lex.kw.types\"></a>**[lex.kw.types](#lex.kw.types)** *(syntax, draft)* Types. Direction in [#50], 2026-11-22.\n" ++
            "<a id=\"lex.ws\"></a>**[lex.ws](#lex.ws)** *(syntax, draft)* White space. Provisional ([#57]).\n\n" ++
            "<a id=\"lex.ws.ex\"></a>**[lex.ws.ex](#lex.ws.ex)** *(accepts)*\n```cesium\n// <a id=\"no\"></a>\n```\n\n" ++
            "Open: the encoding ([#39]).\n\n> Open: in a quote, not a point.\n",
    );
    const rules = try ai.rules.extract(arena.allocator(), p);
    try std.testing.expectEqual(4, rules.len);
    try std.testing.expectEqual(ai.rules.Kind.decided, rules[0].kind);
    try std.testing.expectEqualStrings("lex.ext", rules[0].id);
    try std.testing.expectEqualStrings("syntax, draft", rules[0].label);
    try std.testing.expect(rules[0].cited);
    try std.testing.expectEqualStrings("A file has the extension `.csm`. Nothing else. Decided in cesium#14.", rules[0].text);
    try std.testing.expectEqual(ai.rules.Kind.direction, rules[1].kind);
    try std.testing.expectEqualStrings("lex.kw.types", rules[1].id);
    try std.testing.expectEqual(ai.rules.Kind.provisional, rules[2].kind);
    try std.testing.expectEqual(ai.rules.Kind.open, rules[3].kind);
}
