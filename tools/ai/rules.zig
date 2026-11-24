//! The rules of the specification chapters, as Skein renders them
//! (`tools/take-spec.sh`): a paragraph or list entry that starts with a label,
//! `<a id="ID"></a>**[ID](#ID)** *(category, status)* text`, and the "Open:"
//! paragraphs, which state what no rule decides. Every rule is `draft` until a
//! proposal accepts it; its kind is the source its text gives: "Decided in",
//! "Direction in", "By use", "Provisional".

const std = @import("std");
const content = @import("content.zig");
const plain = @import("plain.zig");

pub const Kind = enum { decided, direction, by_use, provisional, open, other };

pub const Rule = struct {
    kind: Kind,
    /// The rule's ID; empty for an open point.
    id: []const u8,
    /// Its category and status as the label gives them: `syntax, draft`.
    label: []const u8,
    /// The rule on one line, as plain text.
    text: []const u8,
    /// Whether an issue or a page stands in the text.
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
        if (in_fence or std.mem.startsWith(u8, trimmed, ">")) continue;

        const start = n;
        const label = labelOf(trimmed);
        const open = label == null and std.mem.startsWith(u8, trimmed, "Open");
        if (label == null and !open) continue;
        // the rest of the paragraph or entry: up to a blank line, a new entry or a fence
        var joined: std.ArrayList(u8) = .empty;
        try joined.appendSlice(arena, if (label) |l| l.rest else trimmed);
        while (n + 1 < lines.items.len) {
            const next = std.mem.trimStart(u8, lines.items[n + 1], " ");
            if (next.len == 0 or isItemStart(next) or labelOf(next) != null) break;
            if (std.mem.startsWith(u8, next, "```") or std.mem.startsWith(u8, next, ">") or std.mem.startsWith(u8, next, "|")) break;
            try joined.append(arena, ' ');
            try joined.appendSlice(arena, next);
            n += 1;
        }
        const words = try issues(arena, try plain.text(arena, std.mem.trim(u8, joined.items, " ")));
        // a label with no text is a tested example's, whose code follows
        if (words.len == 0) continue;
        try rules.append(arena, .{
            .kind = if (open) .open else kindOf(words),
            .id = if (label) |l| l.id else "",
            .label = if (label) |l| l.words else "",
            .text = words,
            // an issue, a page named by a link (`[control-flow]`), or the reference
            .cited = std.mem.findScalar(u8, words, '#') != null or std.mem.findScalar(u8, words, '[') != null or
                std.mem.find(u8, words, "the reference") != null,
            .line = start + 1,
        });
    }
    // a part (`lex.keywords.types`) has the source of the rule it is a part of
    for (rules.items, 0..) |*rule, i| {
        if (rule.cited or rule.kind != .other) continue;
        var j = i;
        while (j > 0) {
            j -= 1;
            const whole = rules.items[j];
            if (whole.id.len == 0 or !std.mem.startsWith(u8, rule.id, whole.id) or rule.id.len <= whole.id.len or rule.id[whole.id.len] != '.') continue;
            rule.kind = whole.kind;
            rule.cited = whole.cited;
            break;
        }
    }
    return rules.items;
}

const Label = struct { id: []const u8, words: []const u8, rest: []const u8 };

fn isItemStart(s: []const u8) bool {
    if (std.mem.startsWith(u8, s, "- ") or std.mem.startsWith(u8, s, "* ")) return true;
    var d: usize = 0;
    while (d < s.len and std.ascii.isDigit(s[d])) d += 1;
    return d > 0 and std.mem.startsWith(u8, s[d..], ". ");
}

/// `<a id="ID"></a>**[ID](#ID)** *(words)* rest`, after a list marker if any
fn labelOf(trimmed: []const u8) ?Label {
    var s = trimmed;
    if (isItemStart(s)) s = std.mem.trimStart(u8, s[std.mem.findScalar(u8, s, ' ').? + 1 ..], " ");
    const open = "<a id=\"";
    if (!std.mem.startsWith(u8, s, open)) return null;
    const id_end = std.mem.findPos(u8, s, open.len, "\"></a>") orelse return null;
    const id = s[open.len..id_end];
    var rest = s[id_end + "\"></a>".len ..];
    const bold = std.mem.startsWith(u8, rest, "**");
    if (bold) rest = rest[2..];
    // `[ID](#ID)`
    const link_end = std.mem.find(u8, rest, ")") orelse return null;
    rest = rest[link_end + 1 ..];
    if (bold and std.mem.startsWith(u8, rest, "**")) rest = rest[2..];
    rest = std.mem.trimStart(u8, rest, " ");
    var words: []const u8 = "";
    if (std.mem.startsWith(u8, rest, "*(")) {
        const close = std.mem.find(u8, rest, ")*") orelse return null;
        words = rest[2..close];
        rest = std.mem.trimStart(u8, rest[close + 2 ..], " ");
    }
    return .{ .id = id, .words = words, .rest = rest };
}

/// The chapters cite issues of cesiumlang/cesium as reference links, `[#9]`,
/// whose definitions are elsewhere on the page: `cesium#9` says it alone
fn issues(arena: std.mem.Allocator, text: []const u8) error{OutOfMemory}![]const u8 {
    if (std.mem.find(u8, text, "[#") == null) return text;
    var out: std.ArrayList(u8) = .empty;
    var i: usize = 0;
    while (std.mem.findPos(u8, text, i, "[#")) |at| {
        var end = at + 2;
        while (end < text.len and std.ascii.isDigit(text[end])) end += 1;
        if (end == at + 2 or end >= text.len or text[end] != ']') {
            try out.appendSlice(arena, text[i .. at + 2]);
            i = at + 2;
            continue;
        }
        try out.appendSlice(arena, text[i..at]);
        try out.print(arena, "cesium#{s}", .{text[at + 2 .. end]});
        i = end + 1;
    }
    try out.appendSlice(arena, text[i..]);
    return out.items;
}

/// The source the rule's text gives
fn kindOf(text: []const u8) Kind {
    if (std.mem.find(u8, text, "Provisional") != null) return .provisional;
    if (std.mem.find(u8, text, "Direction in") != null or std.mem.find(u8, text, "direction in") != null) return .direction;
    if (std.mem.find(u8, text, "Decided in") != null) return .decided;
    if (std.mem.find(u8, text, "By use") != null or std.mem.find(u8, text, "by use") != null) return .by_use;
    return .other;
}
