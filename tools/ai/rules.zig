//! The rules of the specification chapters: the list items that begin with a
//! status in bold (`**Decided.**`, `**Open.**`), and the Provisional callouts.
//! A rule has the status it is written with; a block quote is never a rule,
//! so what a Provisional callout recommends is not taken for decided.

const std = @import("std");
const content = @import("content.zig");
const plain = @import("plain.zig");

pub const Kind = enum { decided, open, provisional, other };

pub const Rule = struct {
    kind: Kind,
    /// The label as written: `Decided by use`.
    label: []const u8,
    /// The rule on one line, as plain text.
    text: []const u8,
    /// Whether a citation in square brackets stands in the text.
    cited: bool,
    line: usize,
};

/// The rules of `page`, in order. Allocated from `arena`.
pub fn extract(arena: std.mem.Allocator, page: content.Page) error{OutOfMemory}![]Rule {
    var rules: std.ArrayList(Rule) = .empty;
    var lines: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, page.body, '\n');
    while (it.next()) |line| try lines.append(arena, line);

    var in_fence = false;
    var n: usize = 0;
    while (n < lines.items.len) : (n += 1) {
        const line = lines.items[n];
        const trimmed = std.mem.trimStart(u8, line, " ");
        if (std.mem.startsWith(u8, trimmed, "```") or std.mem.startsWith(u8, trimmed, "~~~")) {
            in_fence = !in_fence;
            continue;
        }
        if (in_fence) continue;

        if (std.mem.startsWith(u8, line, "> [!") and std.mem.find(u8, line, "Provisional") != null) {
            const body = if (n + 1 < lines.items.len) std.mem.trimStart(u8, lines.items[n + 1], "> ") else "";
            const joined = try std.fmt.allocPrint(arena, "{s} {s}", .{ line[std.mem.findScalar(u8, line, ']').? + 1 ..], body });
            const words = try plain.text(arena, joined);
            try rules.append(arena, .{
                .kind = .provisional,
                .label = "Provisional",
                .text = words,
                .cited = std.mem.findScalar(u8, words, '#') != null,
                .line = n + 1,
            });
            continue;
        }
        if (std.mem.startsWith(u8, trimmed, ">")) continue;

        const item = itemLabel(trimmed) orelse continue;
        // the rest of the item: the lines up to the next blank line or item
        var joined: std.ArrayList(u8) = .empty;
        try joined.appendSlice(arena, item.rest);
        while (n + 1 < lines.items.len) {
            const next = lines.items[n + 1];
            const next_trimmed = std.mem.trimStart(u8, next, " ");
            if (next_trimmed.len == 0 or itemLabel(next_trimmed) != null or isItemStart(next_trimmed)) break;
            if (std.mem.startsWith(u8, next_trimmed, "```") or std.mem.startsWith(u8, next_trimmed, ">")) break;
            try joined.append(arena, ' ');
            try joined.appendSlice(arena, next_trimmed);
            n += 1;
        }
        const words = try plain.text(arena, joined.items);
        try rules.append(arena, .{
            .kind = kindOf(item.label),
            .label = item.label,
            .text = words,
            .cited = std.mem.findScalar(u8, words, '[') != null,
            .line = n + 1,
        });
    }
    return rules.items;
}

const Item = struct { label: []const u8, rest: []const u8 };

fn isItemStart(s: []const u8) bool {
    if (std.mem.startsWith(u8, s, "- ") or std.mem.startsWith(u8, s, "* ")) return true;
    var d: usize = 0;
    while (d < s.len and std.ascii.isDigit(s[d])) d += 1;
    return d > 0 and std.mem.startsWith(u8, s[d..], ". ");
}

// `1. **Decided.** text` or `- **Open.** text`: the label without its closing dot, and the text
fn itemLabel(trimmed: []const u8) ?Item {
    if (!isItemStart(trimmed)) return null;
    const after_marker = std.mem.trimStart(u8, trimmed[std.mem.findScalar(u8, trimmed, ' ').? + 1 ..], " ");
    if (!std.mem.startsWith(u8, after_marker, "**")) return null;
    const close = std.mem.find(u8, after_marker[2..], "**") orelse return null;
    const label = std.mem.trimEnd(u8, after_marker[2 .. 2 + close], ".");
    return .{ .label = label, .rest = std.mem.trimStart(u8, after_marker[2 + close + 2 ..], " ") };
}

fn kindOf(label: []const u8) Kind {
    if (std.mem.startsWith(u8, label, "Decided")) return .decided;
    if (std.mem.startsWith(u8, label, "Open")) return .open;
    return .other;
}
