# codereview.nvim

Annotate diffs in diffview, write notes to `.review/review.md`, send to Claude CLI.

---

## Quick Start

```
vim review main          # working tree vs main
vim review main HEAD     # committed range
:ReviewPick              # telescope branch/commit picker
```

Opens diffview on top with a notes buffer (`review.md`) at the bottom.
All file buffers are automatically **read-only** during the session.

Write notes, then:

```
:w                       # save from the notes buffer (or :w from any file buffer)
<leader>rA               # send review.md to Claude CLI in a terminal split
:ReviewClose             # end the session, restore all buffers
```

---

## Annotating

| In file buffer | Action |
|---|---|
| `<Enter>` | Jump to notes, insert `### file:line` + code snippet + diff hunk |
| `<Enter>` (visual) | Same for selected range |
| `<leader>ra` | Same as `<Enter>` (global fallback) |

When you press `<Enter>` on a line, the notes buffer gets:

```markdown
### path/to/file.py:42
```python
    def forward(self, x):
```
```diff
@@ -40,6 +40,8 @@ class Foo:
-    def forward(self, x):
+    def forward(self, x, mask=None):
```

← type your note here
```

The diff hunk gives the agent context to find the block even after line numbers shift.

---

## Navigation

| In notes buffer | Action |
|---|---|
| `<Enter>` on `### file:line` | Jump back to that file and line in the diff |
| `<Enter>` elsewhere | Normal Enter |

---

## Keymaps

| Key | Action |
|---|---|
| `<Enter>` | Annotate current line → notes buffer |
| `<leader>ra` | Annotate current line (or visual selection) |
| `<leader>rs` | Generate structured `review.md` from annotations |
| `<leader>rA` | Ask Claude CLI (`claude < review.md` in terminal split) |
| `<leader>rq` | Close review session (restore buffers, close diffview) |
| `<leader>ri` | Status — session info and annotation counts |
| `<leader>rp` | Toggle diffview file panel |
| `<leader>rR` | Refresh — archive round, advance head, stale-check |
| `<leader>rl` | List annotations in quickfix |
| `<leader>rz` | Resolve an annotation |
| `<leader>rx` | Delete an annotation |
| `<leader>ru` | Re-anchor a stale annotation to cursor |
| `<leader>rf` | Mark file: export full content in structured output |
| `<leader>re` | Mark file: extended diff context (prompts for N lines) |
| `<leader>rd` | Mark file: reset to default context |
| `<leader>rS` | Set status on current line's annotation (IMPLEMENTED / ANSWERED / DEFERRED) |
| `<leader>rI` | Open status summary float (grouped by status, `<Enter>` jumps to source) |

> Press `<leader>r` to see all keys in which-key.

---

## Commands

| Command | Description |
|---|---|
| `:ReviewDiff [base] [head]` | Open diffview + notes. Omit `head` for working tree. |
| `:ReviewPick` | Telescope picker for base branch/commit |
| `:ReviewClose` | End session — restore buffers, close diffview and notes |
| `:ReviewSave` | Generate structured `review.md` from annotations |
| `:ReviewRefresh` | Archive round, drop resolved, stale-check carried |
| `:ReviewAsk` | Terminal split: `claude < review.md` |
| `:ReviewList` | Open quickfix with all annotations |
| `:ReviewStatus` | One-line session summary with per-status counts |
| `:ReviewDelete` | Delete an annotation |
| `:ReviewSetStatus` | Set status for annotation at cursor (IMPLEMENTED / ANSWERED / DEFERRED) |
| `:ReviewSummary` | Floating window: all annotations grouped by status |

---

## Modes: Working Tree vs Committed

| Usage | Diffview opens | Git diff uses |
|---|---|---|
| `vim review main` | `DiffviewOpen main` | `git diff main` (working tree) |
| `:ReviewDiff main HEAD` | `DiffviewOpen main..HEAD` | `git diff main..HEAD` |
| `:ReviewDiff main abc123` | `DiffviewOpen main..abc123` | `git diff main..abc123` |

---

## Read-Only Mode

All file buffers are set read-only when entered during a review session.
`:w` in any file buffer redirects to saving the notes buffer.
`:ReviewClose` (`<leader>rq`) restores all buffers to their original state.

---

## Notes Buffer Layout

```
+-----------------------------------+
|                                   |
|   diffview (diff navigation)      |
|                                   |
+-----------------------------------+
|   .review/review.md  (notes)      |
+-----------------------------------+
```

The notes buffer is a regular markdown file — write freely.
`:w` saves it. `<Enter>` on a `### file:line` line jumps to that location.

---

## Status Tracking

After Claude answers your questions, mark each annotation with a status:

| Status | Key | Meaning |
|--------|-----|---------|
| IMPLEMENTED | `<leader>rS` → implemented | Code change was made |
| ANSWERED | `<leader>rS` → answered | Question was answered (prompts for the answer) |
| DEFERRED | `<leader>rS` → deferred | Skipped for now (prompts for reason) |
| open | `<leader>rS` → open (reset) | Back to default |

Statuses are stored in `.review/session.json` and shown as virtual text on source lines:
- ` ● Qn` — open
- ` ✔ Qn IMPL` / ` ✔ Qn ANS` — done
- ` ↷ Qn DEF` — deferred

`<leader>rI` / `:ReviewSummary` opens a float with all annotations grouped by status.
`<Enter>` in the float jumps to the annotation's source line.

When you type **"work on review"** in Claude Code, `.review/review.md` is automatically injected as context.

---

## Structured Export (Legacy / Claude batch mode)

`<leader>rs` / `:ReviewSave` generates a structured `review.md` from the
annotation system (vim.ui.input-based Q&A format). Useful for batch Claude review.

---

## Session Files

`.review/` is auto-created and auto-added to `.gitignore`.

| File | Contents |
|---|---|
| `.review/session.json` | Annotations, rounds, file context settings |
| `.review/review.md` | Notes buffer — edit directly and send to Claude |

---

## Config Options

```lua
require("codereview").setup({
  default_base = "main",
  default_context_lines = 10,   -- diff -U lines for full review export
  annotation_hunk_lines = 3,    -- diff -U lines for inline annotation hunks
  review_dir = ".review",
  gitignore = true,
  notes_height = 15,            -- height of notes split in lines
  stale_search_radius = 15,
  full_diff_skip_annotated = false,
})
```

---

## Typical Workflow

```
1. vim review main          open working tree diff + notes buffer
2. <Enter>                  annotate a line → code + diff hunk appear in notes
3. type your note, <Esc>    write the note
4. <Enter> on ### ref       jump back to that line in the diff
5. :w                       save notes
6. <leader>rA               send to Claude CLI
7. <leader>rq               close when done
```
