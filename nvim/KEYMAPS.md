# Neovim Keymaps Cheat Sheet

> **Leader key**: `,` (comma)
> **Space key**: `<Space>` (used for DAP & Telescope shortcuts)

---

## General

| Key | Action |
|-----|--------|
| `,w` | Save file |
| `,q` | Quit |
| `,h` | Clear search highlight |
| `,r` | Toggle relative line numbers |
| `,n` | Toggle line numbers + sign column |
| `,u` | Toggle Undo tree |
| `<F9>` | Remove trailing whitespace |
| `x` | Delete character (without yanking) |

---

## Buffer & Window Navigation

| Key | Action |
|-----|--------|
| `<Shift-l>` | Next buffer |
| `<Shift-h>` | Previous buffer |
| `,c` | Close current buffer |
| `,b` | List open buffers (Telescope) |

---

## File Explorer (nvim-tree)

| Key | Action |
|-----|--------|
| `<C-n>` | Toggle file tree (focus current file) |
| `,e` | Toggle file tree |

### Inside nvim-tree

| Key | Action |
|-----|--------|
| `Enter / o` | Open file or folder |
| `a` | Create file/directory |
| `d` | Delete |
| `r` | Rename |
| `x` | Cut |
| `c` | Copy |
| `p` | Paste |
| `y` | Copy filename |
| `Y` | Copy relative path |
| `gy` | Copy absolute path |
| `s` | Open with system default |
| `q` | Close tree |
| `g?` | Show help |

---

## Telescope (Fuzzy Finder)

### Open Pickers

| Key | Action |
|-----|--------|
| `<Space>f` | Find files |
| `<Space><Space>` | Recent files |
| `<Space>g` | Live grep (search text) |
| `<Space>h` | Help tags |
| `,f` | Find files (dropdown) |
| `,F` | Live grep (ivy theme) |
| `,sr` | Open recent file |
| `,sb` | Git branches |
| `,sc` | Colorschemes |
| `,sh` | Help tags |
| `,sM` | Man pages |
| `,sR` | Registers |
| `,sk` | Keymaps |
| `,sC` | Commands |

### Inside Telescope (Insert mode)

| Key | Action |
|-----|--------|
| `<C-j>` / `<Down>` | Next result |
| `<C-k>` / `<Up>` | Previous result |
| `<C-n>` | Next search history |
| `<C-p>` | Previous search history |
| `<CR>` | Open selected |
| `<C-x>` | Open in horizontal split |
| `<C-v>` | Open in vertical split |
| `<C-t>` | Open in new tab |
| `<C-u>` | Scroll preview up |
| `<C-d>` | Scroll preview down |
| `<Tab>` | Toggle selection & move down |
| `<S-Tab>` | Toggle selection & move up |
| `<C-q>` | Send all results to quickfix |
| `<M-q>` | Send selected to quickfix |
| `<C-/>` | Show key help |
| `<C-c>` | Close |

### Inside Telescope (Normal mode)

| Key | Action |
|-----|--------|
| `j` / `k` | Navigate results |
| `H` / `M` / `L` | Jump to top / middle / bottom |
| `gg` / `G` | First / last result |
| `<CR>` | Open selected |
| `<C-x/v/t>` | Open in split / vsplit / tab |
| `<C-u>` / `<C-d>` | Scroll preview |
| `<Tab>` / `<S-Tab>` | Toggle selection |
| `<C-q>` | Send to quickfix |
| `?` | Show key help |
| `<Esc>` | Close |

---

## Completion (nvim-cmp)

| Key | Action |
|-----|--------|
| `<C-Space>` | Trigger completion menu |
| `<C-j>` / `<Tab>` | Next item |
| `<C-k>` / `<S-Tab>` | Previous item |
| `<C-b>` | Scroll docs up |
| `<C-f>` | Scroll docs down |
| `<CR>` | Confirm selection |
| `<C-e>` | Abort / close completion |
| `<Tab>` | Expand snippet / jump forward in snippet |
| `<S-Tab>` | Jump backward in snippet |

---

## LSP (Language Server)

### Navigation (any buffer with LSP)

| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gI` | Go to implementation |
| `gr` | List references |
| `K` | Show hover documentation |
| `gl` | Open diagnostic float (current line) |

### Leader LSP mappings

| Key | Action |
|-----|--------|
| `,la` | Code action |
| `,lr` | Rename symbol |
| `,lf` | Format buffer |
| `,ls` | Signature help |
| `,ld` | Document diagnostics (Telescope) |
| `,lw` | Workspace diagnostics (Telescope) |
| `,lj` | Next diagnostic |
| `,lk` | Previous diagnostic |
| `,lq` | Send diagnostics to quickfix |
| `,ll` | Run code lens |
| `,lS` | Workspace symbols |
| `,li` | LSP info |
| `,lI` | Mason (manage LSP servers) |

---

## Git (Gitsigns + Telescope)

| Key | Action |
|-----|--------|
| `,gj` | Next hunk |
| `,gk` | Previous hunk |
| `,gs` | Stage hunk |
| `,gu` | Undo stage hunk |
| `,gr` | Reset hunk |
| `,gR` | Reset entire buffer |
| `,gp` | Preview hunk |
| `,gl` | Blame current line |
| `,gd` | Diff against HEAD |
| `,gg` | Open Lazygit |
| `,go` | Changed files (Telescope) |
| `,gb` | Git branches (Telescope) |
| `,gc` | Git commits (Telescope) |

---

## Debugger (DAP)

> Note: uses `<Space>` prefix

| Key | Action |
|-----|--------|
| `<Space>b` | Toggle breakpoint |
| `<Space>l` | Add log point (with message prompt) |
| `<Space>c` | Continue / start debugging |
| `<Space>n` | Step over |
| `<Space>s` | Step into |
| `<Space>m` | Run to cursor |
| `<Space>h` | Hover variable value |
| `<Space>=` | Evaluate expression |
| `<Space><Esc>` | Terminate session |
| `<Space><Space>` | Pause |

### In DAP float windows

| Key | Action |
|-----|--------|
| `q` / `<Esc>` | Close float |

---

## Folding (nvim-ufo)

| Key | Action |
|-----|--------|
| `zR` | Open all folds |
| `zM` | Close all folds |
| `zo` | Open fold under cursor |
| `zc` | Close fold under cursor |
| `za` | Toggle fold under cursor |

---

## Terminal (ToggleTerm)

| Key | Action |
|-----|--------|
| `,tf` | Floating terminal |
| `,th` | Horizontal terminal (size 10) |
| `,tv` | Vertical terminal (size 80) |
| `,tn` | Node REPL |
| `,tp` | Python REPL |
| `,tu` | NCDU (disk usage) |
| `,tt` | Htop |

### Inside terminal

| Key | Action |
|-----|--------|
| `<C-\><C-n>` | Exit terminal mode to normal mode |

---

## Indent Guides (indent-blankline)

| Key | Action |
|-----|--------|
| `<C-i>` | Toggle indent guides |

---

## Autopairs

| Key | Action |
|-----|--------|
| `<M-e>` | Fast wrap — wrap word/selection with nearest bracket or quote |

---

## Which-Key

> Press `,` (leader) and pause to see available keys in a popup.

| Key | Action |
|-----|--------|
| `,` then pause | Open which-key popup for leader mappings |
| `<C-d>` (in popup) | Scroll popup down |
| `<C-u>` (in popup) | Scroll popup up |

---

## Colorscheme Auto-Switch

> No keymaps needed — the theme is chosen automatically at startup.

| Condition | Theme | Background |
|-----------|-------|------------|
| Pacific Time 07:00 – 18:59 | `dayfox` | light |
| Pacific Time 19:00 – 06:59 | `nightfox` | dark |

**How it works:**
- On startup, Neovim reads the current time as **Pacific Time (PST/PDT)** using
  `TZ='America/Los_Angeles' date +'%H'` — works correctly on any host timezone.
- Daylight saving time (PDT/PST) is handled automatically by the OS timezone database.
- Falls back to **UTC − 8** (standard PST, DST ignored) if the `date` command is unavailable.

**Manual override** — set the env var before launching Neovim:

```bash
TERMCOLORHUE=light nvim   # force dayfox (light)
TERMCOLORHUE=dark  nvim   # force nightfox (dark)
```

Or export it persistently in your shell rc:

```bash
export TERMCOLORHUE=dark
```

To switch theme interactively without restarting, use `,sc` (Telescope colorscheme picker).

---

## Packer / Lazy groups

| Key | Action |
|-----|--------|
| `,pc` | PackerCompile |
| `,pi` | PackerInstall |
| `,ps` | PackerSync |
| `,pS` | PackerStatus |
| `,pu` | PackerUpdate |

---

## Native Vim Essentials (reference)

| Key | Action |
|-----|--------|
| `u` | Undo |
| `<C-r>` | Redo |
| `yy` | Yank line |
| `dd` | Delete line |
| `p` / `P` | Paste after / before |
| `ciw` | Change inner word |
| `di"` | Delete inside quotes |
| `va{` | Select around braces |
| `%` | Jump to matching bracket |
| `*` / `#` | Search word under cursor forward / back |
| `<C-o>` / `<C-i>` | Jump list back / forward |
| `<C-w>h/j/k/l` | Move between splits |
| `<C-w>v` | Vertical split |
| `<C-w>s` | Horizontal split |
| `<C-w>=` | Equalize split sizes |
| `:e <file>` | Open file |
| `:bd` | Close buffer |
| `q:` | Command history window |
