//! The Cesium skill for AI models: a `SKILL.md` that lists every rule of the
//! specification in one line, by the source it gives, with what is open, and
//! links to the pages (as plain Markdown) that a model reads only when it needs
//! them.

const std = @import("std");
const content = @import("content.zig");
const llms_txt = @import("llms_txt.zig");
const rules_mod = @import("rules.zig");

const Page = content.Page;
const Rule = rules_mod.Rule;

pub const name = "cesium-language";

/// The most lines a skill's main file should have.
pub const max_lines = 500;

pub const Result = struct {
    text: []const u8,
    /// Rules that name no source: defects of the specification.
    uncited: usize,
    lines: usize,
};

/// `SKILL.md`. The rules come from the pages under `spec/`; `references/`
/// holds the same pages, so the links between them stay relative.
pub fn render(arena: std.mem.Allocator, pages: []const Page, host: []const u8) error{OutOfMemory}!Result {
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try print(w,
        \\---
        \\name: {s}
        \\description: Writing, reading or reviewing Cesium source (.csm, .csi files). The rules of the language in one line each, with where each comes from and what is still open. Generated from the specification at {s}; use before writing Cesium code or answering a question that depends on its syntax or semantics.
        \\paths:
        \\  - "**/*.csm"
        \\  - "**/*.csi"
        \\---
        \\
        \\# Cesium
        \\
        \\{s}
        \\
        \\No model was trained on Cesium. Do not guess its syntax from C, Zig or C++: check every construct against the rules below and the pages in `references/`.
        \\
        \\## How to read the rules
        \\
        \\Every rule is a draft: it becomes final only through an accepted proposal (cesiumlang/cesium, `proposals/`). Each names its ID (`lex.comment.line`), its category (`syntax`, `legality`, `static`, `dynamic`) and its source:
        \\
        \\- **Decided:** recorded in a `decision` issue of cesiumlang/cesium (`#11` is cesiumlang/cesium#11) or in the language reference. The firmest; still to be carried by a proposal.
        \\- **Direction:** an answer of the project's owner on a design issue, with its date. Follow it, but it is not yet a decision.
        \\- **By use:** what every example does, with no record behind it.
        \\- **Provisional:** a recommendation of the editors, not a decision.
        \\- **Open** points are not decided: there is no rule. Never invent one; say that it is open and cite the issue.
        \\
        \\Only the S0 subset compiles today: `references/spec/s0.md`, whose last section says where the compiler `cesium0` differs.
        \\
    , .{ name, host, llms_txt.summary });

    var uncited: usize = 0;
    var section: usize = 0;
    const statuses = [_]struct { kind: rules_mod.Kind, heading: []const u8 }{
        .{ .kind = .decided, .heading = "Decided" },
        .{ .kind = .direction, .heading = "Direction: not yet decided" },
        .{ .kind = .by_use, .heading = "By use" },
        .{ .kind = .other, .heading = "Other rules" },
        .{ .kind = .provisional, .heading = "Provisional: not decided" },
        .{ .kind = .open, .heading = "Open: not decided" },
    };
    for (statuses) |status| {
        section += 1;
        try print(w, "\n## {s}\n", .{status.heading});
        for (pages) |page| {
            if (!std.mem.startsWith(u8, page.slug, "spec/")) continue;
            const rules = try rules_mod.extract(arena, page);
            var heading_written = false;
            for (rules) |rule| {
                if (rule.kind != status.kind) continue;
                if (!heading_written) {
                    try print(w, "\n### {s} (`references/{s}.md`)\n\n", .{ page.title, page.slug });
                    heading_written = true;
                }
                if (rule.kind != .open and !rule.cited) {
                    uncited += 1;
                    std.debug.print("warning: {s}.md:{d}: {s}: a rule that names no source\n", .{ page.slug, rule.line, rule.id });
                }
                if (rule.id.len > 0) {
                    try print(w, "- `{s}` ({s}): {s}\n", .{ rule.id, rule.label, rule.text });
                } else {
                    try print(w, "- {s}\n", .{rule.text});
                }
            }
        }
    }

    try print(w,
        \\
        \\## Examples that compile
        \\
        \\In [cesiumlang/cesium](https://github.com/cesiumlang/cesium):
        \\
        \\- `bootstrap/tests/s0/*.csm`: S0 programs with their expected output; `bootstrap/tests/s0/errors/` holds programs that must be rejected, with the message.
        \\- `bootstrap/stage1/*.csm`: `cesium1`, written in S0, the largest Cesium program there is.
        \\- The examples of the specification (`spec/`, code blocks marked `%example`), each accepted or rejected as it says.
        \\
        \\## Checking code
        \\
        \\- Build the compilers from a clone of cesiumlang/cesium: `bash tools/fetch-devkit.sh`, then `.devkit/zig/zig build` installs `cesium0` and `cesium1` to `zig-out/bin`.
        \\- `cesium0 --emit-mir -o out.mir a.csm b.csm` checks S0 and reports every error as `file:line:col: error[E0304]: message`; the code is explained in `bootstrap/diagnostics.md`.
        \\- `cat a.csm b.csm | cesium1` checks the same unit and stops at the first error; its line numbers count from the start of the joined input.
        \\- In an editor with the Cesium extension or agent plugin, the language server `zcsls` reports the same errors as diagnostics.
        \\- A Cesium change is not done until a compiler accepts it, or rejects it with the expected message for an error test.
        \\
    , .{});
    try print(w, "\n## Pages\n\nExamples and explanation, not rules; their \"Open\" callouts mark what is undecided.\n\n", .{});
    for (pages) |page| {
        if (!std.mem.startsWith(u8, page.slug, "reference/") and !std.mem.startsWith(u8, page.slug, "spec/")) continue;
        try print(w, "- [{s}](references/{s}.md)\n", .{ page.title, page.slug });
    }

    const text = out.written();
    return .{ .text = text, .uncited = uncited, .lines = std.mem.count(u8, text, "\n") };
}

fn print(w: *std.Io.Writer, comptime fmt: []const u8, args: anytype) error{OutOfMemory}!void {
    w.print(fmt, args) catch return error.OutOfMemory;
}
