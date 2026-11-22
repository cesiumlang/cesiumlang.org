const std = @import("std");
const ai = @import("ai");

const Page = ai.content.Page;

fn page(slug: []const u8, title: []const u8, body: []const u8) Page {
    return .{ .slug = slug, .title = title, .description = null, .sortorder = 0, .body = body };
}

test "wiki links in the same and another directory, and a callout" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const pages = [_]Page{
        page("spec/index", "Specification", ""),
        page("reference/memory-management", "Memory Management", ""),
    };
    var report: ai.portable.Report = .{};
    const lexical = page(
        "spec/lexical",
        "Lexical",
        "See [[spec/index|the introduction]] and [[memory-management#Open Questions]].\n> [!warning] Draft\n> text\n",
    );
    const text = try ai.portable.render(arena.allocator(), &pages, lexical, &report);
    try std.testing.expectEqualStrings(
        "# Lexical\n\nSee [the introduction](index.md) and " ++
            "[Memory Management](../reference/memory-management.md#open-questions).\n> **Warning: Draft**\n> text\n\n",
        text,
    );
    try std.testing.expectEqual(0, report.unresolved);
}

test "code is left alone" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var report: ai.portable.Report = .{};
    const p = page("a", "A", "```cesium\nx = [[1]];\n```\nand `[[code]]`\n");
    const text = try ai.portable.render(arena.allocator(), &.{p}, p, &report);
    try std.testing.expectEqualStrings("# A\n\n```cesium\nx = [[1]];\n```\nand `[[code]]`\n\n", text);
}

test "links, emphasis and line ends become plain text" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const got = try ai.plain.text(arena.allocator(), "**Decided.** See [the issue](https://x.y/1) and [[spec/index|the\nintroduction]], `a [b](c)`.");
    try std.testing.expectEqualStrings("Decided. See the issue and the introduction, `a [b](c)`.", got);
}

test "a decided item with a continuation, and a provisional callout" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const p = page(
        "spec/x",
        "X",
        "1. **Decided.** A file has the extension `.csm`.\n   Nothing else. `[cesium#14]`\n2. **Open.** The encoding.\n\n" ++
            "> [!warning] Provisional — not decided (cesiumlang/cesium#57)\n> This draft assumes more.\n> 1. **Decided.** not a rule\n",
    );
    const rules = try ai.rules.extract(arena.allocator(), p);
    try std.testing.expectEqual(3, rules.len);
    try std.testing.expectEqual(ai.rules.Kind.decided, rules[0].kind);
    try std.testing.expect(rules[0].cited);
    try std.testing.expectEqualStrings("A file has the extension `.csm`. Nothing else. `[cesium#14]`", rules[0].text);
    try std.testing.expectEqual(ai.rules.Kind.open, rules[1].kind);
    try std.testing.expectEqual(ai.rules.Kind.provisional, rules[2].kind);
}
