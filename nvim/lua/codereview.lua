local M = {}

M.config = {
  default_base = "main",
  default_context_lines = 10,
  annotation_hunk_lines = 3,
  review_dir = ".review",
  gitignore = true,
  stale_search_radius = 15,
  full_diff_skip_annotated = false,
  notes_height = 15,
}

-- head = "" means working tree (uncommitted changes)
M.state = {
  base = nil,
  head = nil,
  annotations = {},
  rounds = {},
  file_context = {},
  status_map = {},  -- maps "file:line" -> {status, note}
}

-- Paths

local function review_dir()
  return vim.fn.getcwd() .. "/" .. M.config.review_dir
end

local function session_path()
  return review_dir() .. "/session.json"
end

local function review_path()
  return review_dir() .. "/review.md"
end

local function ensure_dir()
  local dir = review_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
    if M.config.gitignore then
      local gi = vim.fn.getcwd() .. "/.gitignore"
      local entry = M.config.review_dir .. "/"
      local found = false
      if vim.fn.filereadable(gi) == 1 then
        for _, line in ipairs(vim.fn.readfile(gi)) do
          if line == entry then found = true; break end
        end
      end
      if not found then
        local f = io.open(gi, "a")
        if f then f:write("\n" .. entry .. "\n"); f:close() end
      end
    end
  end
end

-- Git helpers: head="" means working tree

local function is_working_tree()
  return M.state.head == "" or M.state.head == nil
end

local function head_label()
  return is_working_tree() and "working tree" or M.state.head
end

local function git_diff(base, head, flags, path)
  flags = flags or ""
  path = path and ("-- " .. path) or ""
  if head == "" or head == nil then
    return vim.fn.systemlist(string.format("git diff %s %s %s", flags, base, path))
  else
    return vim.fn.systemlist(string.format("git diff %s %s..%s %s", flags, base, head, path))
  end
end

local function file_content(head, file)
  if head == "" or head == nil then
    local path = vim.fn.getcwd() .. "/" .. file
    local f = io.open(path, "r")
    if not f then return {} end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    return lines
  else
    return vim.fn.systemlist(string.format("git show %s:%s 2>/dev/null", head, file))
  end
end

local function current_head()
  return vim.fn.systemlist("git rev-parse --short HEAD")[1] or "HEAD"
end

-- Session persistence

local function save_session()
  ensure_dir()
  local f = io.open(session_path(), "w")
  if f then
    f:write(vim.fn.json_encode(M.state))
    f:close()
  end
end

local function load_session()
  local path = session_path()
  if vim.fn.filereadable(path) == 0 then return false end
  local f = io.open(path, "r")
  if not f then return false end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.fn.json_decode, content)
  if ok and data then
    M.state = data
    if vim.tbl_isempty(M.state.file_context or {}) then
      M.state.file_context = vim.empty_dict()
    end
    if not M.state.annotations then M.state.annotations = {} end
    if not M.state.rounds then M.state.rounds = {} end
    if not M.state.status_map then M.state.status_map = {} end
    return true
  end
  return false
end

-- Parse ### file:line refs from the notes buffer

local function parse_notes_refs()
  local path = review_path()
  if vim.fn.filereadable(path) == 0 then return {} end
  local refs = {}
  local cur, in_block = nil, false
  for _, l in ipairs(vim.fn.readfile(path)) do
    if l:match("^```") then
      in_block = not in_block
    elseif not in_block then
      local f, ln = l:match("^### ([^:]+):(%d+)")
      if f then
        cur = { file = f, line = tonumber(ln), key = f .. ":" .. ln, notes = {} }
        table.insert(refs, cur)
      elseif cur and l ~= "" then
        table.insert(cur.notes, l)
      end
    end
  end
  return refs
end

-- Virtual text signs

local ns = vim.api.nvim_create_namespace("codereview")

local function status_label(key, prefix)
  local st = M.state.status_map and M.state.status_map[key]
  if st then
    if st.status == "implemented" then return prefix .. " IMPL", "DiagnosticOk" end
    if st.status == "answered"    then return prefix .. " ANS",  "DiagnosticOk" end
    if st.status == "deferred"    then return prefix .. " DEF",  "DiagnosticWarn" end
  end
  return prefix, "DiagnosticHint"
end

function M.refresh_signs()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.fn.expand("%:.")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  -- Notes-based refs (primary workflow)
  local refs = parse_notes_refs()
  local seen_lines = {}
  for i, ref in ipairs(refs) do
    if ref.file == file then
      seen_lines[ref.line] = true
      local label, hl = status_label(ref.key, string.format(" ● Q%d", i))
      vim.api.nvim_buf_set_extmark(buf, ns, ref.line - 1, 0, {
        virt_text = {{ label, hl }},
        virt_text_pos = "eol",
      })
    end
  end

  -- Legacy structured annotations
  for i, ann in ipairs(M.state.annotations) do
    if ann.file == file and not seen_lines[ann.line_start] then
      local label, hl
      if ann.resolved then
        label = string.format(" ✓ Q%d", i)
        hl = "DiagnosticOk"
      elseif ann.stale then
        label = string.format(" ⚠ Q%d stale", i)
        hl = "DiagnosticWarn"
      else
        label, hl = status_label(ann.file .. ":" .. ann.line_start, string.format(" ● Q%d", i))
      end
      vim.api.nvim_buf_set_extmark(buf, ns, ann.line_start - 1, 0, {
        virt_text = {{ label, hl }},
        virt_text_pos = "eol",
      })
    end
  end
end

-- Review-mode buffer management: make file buffers read-only and redirect :w

local _review_bufs = {}
local _panel_win = nil

local function notes_abspath()
  return vim.fn.fnamemodify(review_path(), ":p")
end

local function save_notes_buf()
  local rpath = notes_abspath()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_name(b) == rpath then
      vim.api.nvim_buf_call(b, function() vim.cmd("silent write") end)
      return true
    end
  end
  return false
end

local function setup_buf_for_review(buf)
  if _review_bufs[buf] then return end
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" or name == notes_abspath() then return end
  if vim.bo[buf].buftype ~= "" then return end
  if vim.fn.filereadable(name) == 0 then return end

  _review_bufs[buf] = {
    readonly   = vim.bo[buf].readonly,
    modifiable = vim.bo[buf].modifiable,
  }
  vim.bo[buf].readonly   = true
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "acwrite"

  -- <Enter> to annotate current line
  vim.keymap.set("n", "<CR>", function() M.add_annotation() end,
    { buffer = buf, noremap = true, silent = true, desc = "Add review note" })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer   = buf,
    callback = function()
      if not save_notes_buf() then
        vim.notify("[review] review notes not open — use :ReviewSave", vim.log.levels.WARN)
      else
        vim.notify("[review] saved → " .. review_path(), vim.log.levels.INFO)
      end
      vim.bo[buf].modified = false
    end,
  })
end

function M.teardown_review_bufs()
  for buf, saved in pairs(_review_bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.bo[buf].buftype    = ""
      vim.bo[buf].readonly   = saved.readonly
      vim.bo[buf].modifiable = saved.modifiable
    end
  end
  _review_bufs = {}
end

-- Notes window

local function find_notes_win()
  local rpath = notes_abspath()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf) == rpath then
      return win
    end
  end
  return nil
end

local function open_notes_win()
  local win = find_notes_win()
  if win then return win end
  ensure_dir()
  if vim.fn.filereadable(review_path()) == 0 then
    local f = io.open(review_path(), "w")
    if f then
      f:write(string.format("# Review: %s → %s\nDate: %s\n\n",
        M.state.base or "?",
        is_working_tree() and "working tree" or (M.state.head or "?"),
        os.date("%Y-%m-%d")))
      f:close()
    end
  end
  vim.cmd("botright " .. M.config.notes_height .. "split " .. vim.fn.fnameescape(review_path()))
  local winid = vim.api.nvim_get_current_win()
  -- <CR> on a ### reference line jumps to source
  local buf = vim.api.nvim_get_current_buf()
  vim.keymap.set("n", "<CR>", function()
    local line = vim.api.nvim_get_current_line()
    if line:match("^### [^:]+:%d+") then
      M.jump_to_source()
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
    end
  end, { buffer = buf, noremap = true, silent = true, desc = "Jump to source reference" })
  -- When the notes panel is closed, jump back to the previous source window
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern  = tostring(winid),
    once     = true,
    callback = function()
      vim.schedule(function() pcall(vim.cmd, "wincmd p") end)
    end,
  })
  return winid
end

-- Extract base-version lines that correspond to new-file [line1, line2].
-- Returns a list of lines, or nil if the selection has no changes (before == after).
local function get_selection_before(base, head, file, line1, line2)
  local diff = git_diff(base, head, "-U999999", file)
  if #diff == 0 then return nil end

  local before_lines = {}
  local new_line = 0
  local pending_removed = {}
  local in_hunk = false
  local has_change = false  -- true if any change (add/remove) falls within [line1,line2]

  local function in_range(n) return n >= line1 and n <= line2 end

  for _, dl in ipairs(diff) do
    if dl:match("^diff ") or dl:match("^index ") or dl:match("^%-%-%-") or dl:match("^%+%+%+") then
      -- skip header lines
    elseif dl:match("^@@") then
      if #pending_removed > 0 and in_range(new_line) then
        has_change = true
        vim.list_extend(before_lines, pending_removed)
      end
      pending_removed = {}
      in_hunk = true
      new_line = (tonumber(dl:match("%+(%d+)")) or 1) - 1
    elseif in_hunk then
      local prefix = dl:sub(1, 1)
      local content = dl:sub(2)
      if prefix == " " then
        new_line = new_line + 1
        if in_range(new_line) then
          if #pending_removed > 0 then has_change = true end
          vim.list_extend(before_lines, pending_removed)
          table.insert(before_lines, content)
        end
        pending_removed = {}
      elseif prefix == "-" then
        table.insert(pending_removed, content)
      elseif prefix == "+" then
        new_line = new_line + 1
        if in_range(new_line) then
          if #pending_removed > 0 then has_change = true end
          vim.list_extend(before_lines, pending_removed)
          has_change = true
        end
        pending_removed = {}
      end
    end
  end
  if #pending_removed > 0 and in_range(new_line) then
    has_change = true
    vim.list_extend(before_lines, pending_removed)
  end

  return (has_change and #before_lines > 0) and before_lines or nil
end

-- Jump to notes buffer, inserting file:line header + before/after code blocks

function M.add_annotation(line1, line2)
  if not M.state.base then
    vim.notify("[review] no active session — run :ReviewDiff first", vim.log.levels.WARN)
    return
  end
  line1 = line1 or vim.api.nvim_win_get_cursor(0)[1]
  line2 = line2 or line1
  local file = vim.fn.expand("%:.")
  local ext  = file:match("%.([^%.]+)$") or ""

  local after_lines  = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  local before_lines = get_selection_before(M.state.base, M.state.head, file, line1, line2)

  local notes_win = open_notes_win()
  vim.api.nvim_set_current_win(notes_win)

  local buf  = vim.api.nvim_win_get_buf(notes_win)
  local last = vim.api.nvim_buf_line_count(buf)
  local prev = last > 0 and vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] or ""

  local ref = line1 == line2
    and string.format("### %s:%d", file, line1)
    or  string.format("### %s:%d-%d", file, line1, line2)

  local block = { ref }
  if before_lines then
    table.insert(block, "```diff")
    for _, l in ipairs(before_lines) do table.insert(block, "-" .. l) end
    for _, l in ipairs(after_lines)  do table.insert(block, "+" .. l) end
    table.insert(block, "```")
  else
    table.insert(block, "```" .. ext)
    vim.list_extend(block, after_lines)
    table.insert(block, "```")
  end
  table.insert(block, "")

  local insert = prev ~= "" and vim.list_extend({ "" }, block) or block
  vim.api.nvim_buf_set_lines(buf, last, last, false, insert)
  vim.api.nvim_win_set_cursor(notes_win, { vim.api.nvim_buf_line_count(buf), 0 })
  vim.cmd("startinsert")
end

-- Jump from a ### file:line reference in the notes buffer back to source

function M.jump_to_source()
  local line = vim.api.nvim_get_current_line()
  local file, lnum = line:match("^### ([^:]+):(%d+)")
  if not file or not lnum then
    vim.notify("[review] not a file reference line", vim.log.levels.WARN)
    return
  end
  lnum = tonumber(lnum)
  -- Find a window that already shows the file (prefer diffview windows)
  local target_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match(vim.pesc(file) .. "$") then
      target_win = win
      break
    end
  end
  if target_win then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(file))
  end
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  vim.cmd("normal! zz")
end

-- Close review session

function M.close()
  M.teardown_review_bufs()
  -- Close notes window
  local nwin = find_notes_win()
  if nwin then
    vim.api.nvim_win_close(nwin, true)
  end
  -- Close diffview if open
  pcall(vim.cmd, "DiffviewClose")
  M.state.base = nil
  vim.notify("[review] session closed", vim.log.levels.INFO)
end

function M.delete_annotation()
  if #M.state.annotations == 0 then
    vim.notify("[review] no annotations", vim.log.levels.WARN)
    return
  end
  local items = {}
  for i, ann in ipairs(M.state.annotations) do
    local tag = ann.resolved and "✓ " or (ann.stale and "⚠ " or "")
    table.insert(items, string.format("[Q%d] %s%s:%d — %s", i, tag, ann.file, ann.line_start, ann.note))
  end
  vim.ui.select(items, { prompt = "Delete annotation:" }, function(_, idx)
    if not idx then return end
    table.remove(M.state.annotations, idx)
    save_session()
    M.refresh_signs()
    vim.notify("[review] annotation deleted", vim.log.levels.INFO)
  end)
end

-- Mark annotation as resolved

function M.resolve_annotation()
  local active = {}
  for i, ann in ipairs(M.state.annotations) do
    if not ann.resolved then
      table.insert(active, { idx = i, ann = ann })
    end
  end
  if #active == 0 then
    vim.notify("[review] no open annotations", vim.log.levels.INFO)
    return
  end
  local items = {}
  for _, e in ipairs(active) do
    local tag = e.ann.stale and "⚠ " or ""
    table.insert(items, string.format("[Q%d] %s%s:%d — %s", e.idx, tag, e.ann.file, e.ann.line_start, e.ann.note))
  end
  vim.ui.select(items, { prompt = "Resolve annotation:" }, function(_, sel_idx)
    if not sel_idx then return end
    local idx = active[sel_idx].idx
    M.state.annotations[idx].resolved = true
    M.state.annotations[idx].stale = false
    save_session()
    M.refresh_signs()
    vim.notify(string.format("[review] Q%d marked resolved ✓", idx), vim.log.levels.INFO)
  end)
end

-- Re-anchor a stale annotation to the current cursor position

function M.reanchor()
  local file = vim.fn.expand("%:.")
  local line = vim.api.nvim_win_get_cursor(0)[1]

  local best_idx, best_dist = nil, math.huge
  for i, ann in ipairs(M.state.annotations) do
    if ann.file == file and ann.stale and not ann.resolved then
      local dist = math.abs(ann.line_start - line)
      if dist < best_dist then best_idx, best_dist = i, dist end
    end
  end

  if not best_idx then
    vim.notify("[review] no stale annotation for this file", vim.log.levels.WARN)
    return
  end

  local ann = M.state.annotations[best_idx]
  local span = ann.line_end - ann.line_start
  local new_end = math.min(line + span, vim.api.nvim_buf_line_count(0))
  local content = table.concat(
    vim.api.nvim_buf_get_lines(0, line - 1, new_end, false), "\n"
  )

  M.state.annotations[best_idx].line_start = line
  M.state.annotations[best_idx].line_end = new_end
  M.state.annotations[best_idx].content = content
  M.state.annotations[best_idx].stale = false
  save_session()
  M.refresh_signs()
  vim.notify(string.format("[review] Q%d re-anchored to line %d", best_idx, line), vim.log.levels.INFO)
end

-- Per-file context level

function M.set_full()
  local file = vim.fn.expand("%:.")
  M.state.file_context[file] = "full"
  save_session()
  vim.notify("[review] " .. file .. ": export full file", vim.log.levels.INFO)
end

function M.set_extended()
  local file = vim.fn.expand("%:.")
  vim.ui.input({ prompt = "Context lines: ", default = "40" }, function(input)
    local n = tonumber(input)
    if not n then return end
    M.state.file_context[file] = n
    save_session()
    vim.notify(string.format("[review] %s: export diff -U%d", file, n), vim.log.levels.INFO)
  end)
end

function M.set_default_context()
  local file = vim.fn.expand("%:.")
  M.state.file_context[file] = nil
  if vim.tbl_isempty(M.state.file_context) then
    M.state.file_context = vim.empty_dict()
  end
  save_session()
  vim.notify("[review] " .. file .. ": reset to default context", vim.log.levels.INFO)
end

-- Set status for the annotation at the current file:line

function M.set_status()
  if not M.state.base then
    vim.notify("[review] no active session — run :ReviewDiff first", vim.log.levels.WARN)
    return
  end
  local file = vim.fn.expand("%:.")
  local line  = vim.api.nvim_win_get_cursor(0)[1]
  local key   = file .. ":" .. line
  local cur   = M.state.status_map[key]
  local choices = { "implemented", "answered", "deferred", "open (reset)" }
  vim.ui.select(choices, { prompt = "Status for " .. key .. ":" }, function(choice)
    if not choice then return end
    if choice == "open (reset)" then
      M.state.status_map[key] = nil
      save_session(); M.refresh_signs()
      vim.notify("[review] " .. key .. " → open", vim.log.levels.INFO)
      return
    end
    if choice == "answered" or choice == "deferred" then
      local def = (cur and cur.note) or ""
      local prompt = choice == "answered" and "Answer: " or "Deferral reason: "
      vim.ui.input({ prompt = prompt, default = def }, function(note)
        if note == nil then return end
        M.state.status_map[key] = { status = choice, note = note }
        save_session(); M.refresh_signs()
        vim.notify(string.format("[review] %s → %s", key, choice), vim.log.levels.INFO)
      end)
    else
      M.state.status_map[key] = { status = choice, note = "" }
      save_session(); M.refresh_signs()
      vim.notify(string.format("[review] %s → %s", key, choice), vim.log.levels.INFO)
    end
  end)
end

-- Floating summary window grouped by status

function M.review_summary()
  if not M.state.base then
    vim.notify("[review] no active session", vim.log.levels.WARN)
    return
  end
  local refs = parse_notes_refs()
  if #refs == 0 then
    vim.notify("[review] no annotations in notes buffer", vim.log.levels.INFO)
    return
  end

  local groups = { open = {}, implemented = {}, answered = {}, deferred = {} }
  for i, ref in ipairs(refs) do
    local st = M.state.status_map[ref.key]
    local bucket = (st and st.status) or "open"
    local note_text = ref.notes[1] or ""
    -- strip markdown emphasis from the first note line
    note_text = note_text:gsub("%*%*?([^*]+)%*%*?", "%1")
    local extra = (st and st.note ~= "" and st.note) and ("  (" .. st.note .. ")") or ""
    table.insert(groups[bucket], {
      i = i, file = ref.file, line = ref.line,
      desc = note_text .. extra,
    })
  end

  local lines, locations = {}, {}
  local function section(title, key)
    local items = groups[key]
    if #items == 0 then return end
    table.insert(lines, title .. " (" .. #items .. ")")
    for _, e in ipairs(items) do
      local l = string.format("  Q%-3d %s:%d  — %s", e.i, e.file, e.line, e.desc)
      table.insert(lines, l)
      table.insert(locations, { file = e.file, line = e.line, row = #lines })
    end
    table.insert(lines, "")
  end

  section("OPEN",        "open")
  section("IMPLEMENTED", "implemented")
  section("ANSWERED",    "answered")
  section("DEFERRED",    "deferred")

  local width  = math.min(vim.o.columns - 10, 100)
  local height = math.min(#lines + 1, vim.o.lines - 6)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype   = "markdown"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width    = width,
    height   = height,
    row      = math.floor((vim.o.lines - height) / 2),
    col      = math.floor((vim.o.columns - width) / 2),
    border   = "rounded",
    title    = " Review Summary ",
    title_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  local close = function() vim.api.nvim_win_close(win, true) end
  local function jump()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    for _, loc in ipairs(locations) do
      if loc.row == row then
        close()
        local found = nil
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
          if name:match(vim.pesc(loc.file) .. "$") then found = w; break end
        end
        if found then
          vim.api.nvim_set_current_win(found)
        else
          vim.cmd("edit " .. vim.fn.fnameescape(loc.file))
        end
        vim.api.nvim_win_set_cursor(0, { loc.line, 0 })
        vim.cmd("normal! zz")
        return
      end
    end
  end

  local o = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "q",     close, o)
  vim.keymap.set("n", "<Esc>", close, o)
  vim.keymap.set("n", "<CR>",  jump,  o)
end

-- Session status

function M.status()
  if not M.state.base then
    vim.notify("[review] no active session", vim.log.levels.WARN)
    return
  end
  local counts = { open = 0, implemented = 0, answered = 0, deferred = 0 }
  local refs = parse_notes_refs()
  for _, ref in ipairs(refs) do
    local st = M.state.status_map[ref.key]
    local bucket = (st and st.status) or "open"
    counts[bucket] = (counts[bucket] or 0) + 1
  end
  -- also count legacy annotations not in notes
  local stale, resolved = 0, 0
  for _, ann in ipairs(M.state.annotations) do
    if ann.resolved then resolved = resolved + 1
    elseif ann.stale then stale = stale + 1 end
  end
  vim.notify(string.format(
    "[review] %s → %s | %d open | %d impl | %d ans | %d def | round %d",
    M.state.base, head_label(),
    counts.open, counts.implemented, counts.answered, counts.deferred,
    #M.state.rounds + 1
  ), vim.log.levels.INFO)
end

-- Quickfix list

function M.list_annotations()
  if #M.state.annotations == 0 then
    vim.notify("[review] no annotations yet", vim.log.levels.WARN)
    return
  end
  local qf = {}
  for i, ann in ipairs(M.state.annotations) do
    local tag = ann.resolved and "✓ " or (ann.stale and "⚠ stale " or "")
    table.insert(qf, {
      filename = ann.file,
      lnum = ann.line_start,
      col = 1,
      text = string.format("[Q%d] %s%s", i, tag, ann.note),
    })
  end
  vim.fn.setqflist(qf)
  vim.cmd("copen")
end

-- Send review.md to Claude CLI in a terminal split

function M.ask()
  local path = review_path()
  if vim.fn.filereadable(path) == 0 then
    vim.notify("[review] no review.md yet — run :ReviewSave first", vim.log.levels.WARN)
    return
  end
  vim.cmd("split | terminal claude < " .. vim.fn.shellescape(path))
end

-- Stale detection: search ±radius lines for stored content

local function check_stale(ann)
  local lines = file_content("", ann.file)
  if #lines == 0 then return true end
  local first_stored = vim.trim(ann.content:match("^([^\n]+)") or "")
  if first_stored == "" then return false end
  local radius = M.config.stale_search_radius
  local lo = math.max(1, ann.line_start - radius)
  local hi = math.min(#lines, ann.line_end + radius)
  for i = lo, hi do
    if vim.trim(lines[i]) == first_stored then return false end
  end
  return true
end

-- Refresh: archive round, update head, run stale detection

function M.refresh()
  if not M.state.base then
    vim.notify("[review] no active review session", vim.log.levels.ERROR)
    return
  end

  if #M.state.annotations > 0 then
    table.insert(M.state.rounds, {
      head = M.state.head,
      head_label = head_label(),
      timestamp = os.date("%Y-%m-%d %H:%M"),
      annotations = vim.deepcopy(M.state.annotations),
    })
  end

  local carried = {}
  for _, ann in ipairs(M.state.annotations) do
    if not ann.resolved then
      table.insert(carried, ann)
    end
  end
  M.state.annotations = carried

  local new_head = is_working_tree() and "" or current_head()
  M.state.head = new_head

  local stale_count = 0
  for _, ann in ipairs(M.state.annotations) do
    ann.stale = check_stale(ann)
    if ann.stale then stale_count = stale_count + 1 end
  end

  save_session()
  M.refresh_signs()

  local mode = is_working_tree() and "working tree" or new_head
  if stale_count > 0 then
    vim.notify(string.format(
      "[review] refreshed to %s — %d annotation(s) may be stale (⚠), check with <leader>rl",
      mode, stale_count
    ), vim.log.levels.WARN)
  else
    vim.notify(string.format("[review] refreshed to %s — all annotations still valid", mode), vim.log.levels.INFO)
  end

  local base = M.state.base
  if is_working_tree() then
    vim.cmd("DiffviewOpen " .. base)
  else
    vim.cmd(string.format("DiffviewOpen %s..%s", base, new_head))
  end
end

-- Export review.md (structured output from annotations)

local function write_file_section(out, file, base, head, ctx)
  local ext = file:match("%.([^%.]+)$") or ""
  table.insert(out, "### " .. file)
  table.insert(out, "")
  if ctx == "full" then
    local content = file_content(head, file)
    if #content > 0 then
      table.insert(out, "```" .. ext)
      for _, l in ipairs(content) do table.insert(out, l) end
      table.insert(out, "```")
    end
  else
    local u = type(ctx) == "number" and ctx or M.config.default_context_lines
    local diff = git_diff(base, head, string.format("-U%d", u), file)
    if #diff > 0 then
      table.insert(out, "```diff")
      for _, l in ipairs(diff) do table.insert(out, l) end
      table.insert(out, "```")
    end
  end
  table.insert(out, "")
end

local function write_annotations(out, annotations, by_file, file)
  if not by_file[file] then return end
  local ext = file:match("%.([^%.]+)$") or ""
  for i, ann in ipairs(by_file[file]) do
    local loc = ann.line_start == ann.line_end
      and string.format("line %d", ann.line_start)
      or  string.format("lines %d-%d", ann.line_start, ann.line_end)
    local tag = ann.resolved and " ✓ resolved" or (ann.stale and " ⚠ stale" or "")
    table.insert(out, string.format("**Q%d** (%s%s):", i, loc, tag))
    table.insert(out, "```" .. ext)
    table.insert(out, ann.content)
    table.insert(out, "```")
    table.insert(out, ann.note)
    table.insert(out, "")
  end
end

function M.save()
  if not M.state.base then
    vim.notify("[review] no active review session", vim.log.levels.ERROR)
    return
  end

  ensure_dir()
  local base, head = M.state.base, M.state.head
  local head_str = is_working_tree() and "working tree" or head
  local out = {}

  table.insert(out, string.format(
    "You are reviewing code changes from `%s` to `%s`. Answer each question marked with **Q:** using the file context provided.\n",
    base, head_str
  ))
  table.insert(out, string.format("# Code Review: %s → %s", base, head_str))
  table.insert(out, "Date: " .. os.date("%Y-%m-%d %H:%M"))
  if #M.state.rounds > 0 then
    table.insert(out, string.format("Round: %d (see History section for previous rounds)", #M.state.rounds + 1))
  end
  table.insert(out, "")

  table.insert(out, "## Summary")
  table.insert(out, "```")
  for _, l in ipairs(git_diff(base, head, "--stat")) do table.insert(out, l) end
  table.insert(out, "```")
  table.insert(out, "")

  local seen = {}
  local all_files = {}
  local by_file = {}
  for _, ann in ipairs(M.state.annotations) do
    if not seen[ann.file] then
      seen[ann.file] = true
      table.insert(all_files, ann.file)
      by_file[ann.file] = {}
    end
    table.insert(by_file[ann.file], ann)
  end
  for f in pairs(M.state.file_context) do
    if not seen[f] then seen[f] = true; table.insert(all_files, f) end
  end

  if #all_files > 0 then
    table.insert(out, "## Annotated Files")
    table.insert(out, "")
    for _, file in ipairs(all_files) do
      write_file_section(out, file, base, head, M.state.file_context[file])
      write_annotations(out, M.state.annotations, by_file, file)
    end
  end

  table.insert(out, "## Full Diff")
  table.insert(out, "")
  if M.config.full_diff_skip_annotated and #all_files > 0 then
    local changed = vim.fn.systemlist(string.format(
      "git diff --name-only %s",
      (head == "" or head == nil) and base or (base .. ".." .. head)
    ))
    local any = false
    for _, f in ipairs(changed) do
      if not seen[f] then
        local diff = git_diff(base, head, string.format("-U%d", M.config.default_context_lines), f)
        if #diff > 0 then
          any = true
          table.insert(out, "```diff")
          for _, l in ipairs(diff) do table.insert(out, l) end
          table.insert(out, "```")
          table.insert(out, "")
        end
      end
    end
    if not any then
      table.insert(out, "_All changed files already shown in Annotated Files above._")
    end
  else
    table.insert(out, "```diff")
    for _, l in ipairs(git_diff(base, head, string.format("-U%d", M.config.default_context_lines))) do
      table.insert(out, l)
    end
    table.insert(out, "```")
  end

  if #M.state.rounds > 0 then
    table.insert(out, "")
    table.insert(out, "## History")
    table.insert(out, "")
    for ri = #M.state.rounds, 1, -1 do
      local round = M.state.rounds[ri]
      table.insert(out, string.format("### Round %d — %s (head: %s)", ri, round.timestamp, round.head_label))
      table.insert(out, "")
      for i, ann in ipairs(round.annotations) do
        local tag = ann.resolved and " ✓" or (ann.stale and " ⚠" or "")
        local loc = ann.line_start == ann.line_end
          and string.format("line %d", ann.line_start)
          or  string.format("lines %d-%d", ann.line_start, ann.line_end)
        table.insert(out, string.format("**Q%d%s** `%s` (%s): %s", i, tag, ann.file, loc, ann.note))
      end
      table.insert(out, "")
    end
  end

  local path = review_path()
  local f = io.open(path, "w")
  if f then
    f:write(table.concat(out, "\n"))
    f:close()
    vim.notify("[review] saved → " .. path, vim.log.levels.INFO)
    -- Reload the notes buffer if open
    local rpath = notes_abspath()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(b) == rpath then
        vim.api.nvim_buf_call(b, function() vim.cmd("edit") end)
        break
      end
    end
  else
    vim.notify("[review] failed to write " .. path, vim.log.levels.ERROR)
  end
end

-- Open diffview + notes split

function M.open(base, head)
  base = base or M.config.default_base
  head = head or ""

  if load_session() and M.state.base == base and M.state.head == head then
    vim.notify(string.format("[review] resumed session (%d annotations)", #M.state.annotations), vim.log.levels.INFO)
  else
    M.state = { base = base, head = head, annotations = {}, rounds = {}, file_context = vim.empty_dict(), status_map = {} }
    save_session()
  end

  if head == "" then
    vim.cmd("DiffviewOpen " .. base)
  else
    vim.cmd(string.format("DiffviewOpen %s..%s", base, head))
  end

  -- Open notes buffer after diffview settles
  vim.api.nvim_create_autocmd("User", {
    pattern = "DiffviewViewOpened",
    once    = true,
    callback = function()
      open_notes_win()
    end,
  })
end

-- Telescope pickers

local function pick_head_then_open(base)
  vim.ui.input({ prompt = "Head (leave empty for working tree): " }, function(head)
    M.open(base, (head ~= "" and head) or nil)
  end)
end

local function telescope_pick_base(builtin, picker_name, opts)
  local actions = require("telescope.actions")
  local state   = require("telescope.actions.state")
  builtin[picker_name](vim.tbl_extend("force", opts or {}, {
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        local entry = state.get_selected_entry()
        local base = entry and (entry.value or entry[1]) or nil
        if not base then return end
        base = base:gsub("^remotes/", "")
        actions.close(prompt_bufnr)
        pick_head_then_open(base)
      end)
      return true
    end,
  }))
end

function M.pick()
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.ui.input({ prompt = "Base branch/commit: ", default = M.config.default_base }, function(base)
      if not base or base == "" then return end
      pick_head_then_open(base)
    end)
    return
  end

  vim.ui.select(
    { "Branches", "Recent commits", "Tags" },
    { prompt = "Pick base from:" },
    function(choice)
      if not choice then return end
      if choice == "Branches" then
        telescope_pick_base(builtin, "git_branches", { prompt_title = "Base Branch" })
      elseif choice == "Recent commits" then
        telescope_pick_base(builtin, "git_commits",  { prompt_title = "Base Commit" })
      elseif choice == "Tags" then
        telescope_pick_base(builtin, "git_tags",     { prompt_title = "Base Tag" })
      end
    end
  )
end

-- Right-side questions panel (toggle)

function M.toggle_panel()
  if _panel_win and vim.api.nvim_win_is_valid(_panel_win) then
    vim.api.nvim_win_close(_panel_win, true)
    _panel_win = nil
    return
  end

  local refs = parse_notes_refs()
  if #refs == 0 then
    vim.notify("[review] no annotations", vim.log.levels.INFO)
    return
  end

  local lines = {}
  local row_to_loc = {}

  for i, ref in ipairs(refs) do
    local st = M.state.status_map and M.state.status_map[ref.key]
    local status = (st and st.status) or "open"
    local icon = (status == "implemented" or status == "answered") and "✓"
               or status == "deferred" and "~" or "●"
    local tag  = status ~= "open" and (" [" .. status:upper():sub(1, 4) .. "]") or ""
    local fname = ref.file:match("([^/]+)$") or ref.file
    table.insert(lines, string.format("%s Q%-2d %s:%d%s", icon, i, fname, ref.line, tag))
    row_to_loc[#lines] = { file = ref.file, line = ref.line }
    for _, nl in ipairs(ref.notes) do
      if nl ~= "" then
        table.insert(lines, "  " .. nl)
        row_to_loc[#lines] = { file = ref.file, line = ref.line }
      end
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype    = "nofile"

  local prev_win = vim.api.nvim_get_current_win()
  vim.cmd("botright 44vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  _panel_win = win

  vim.wo[win].wrap          = false
  vim.wo[win].number        = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn    = "no"
  vim.wo[win].cursorline    = true
  vim.wo[win].winfixwidth   = true

  local close = function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    _panel_win = nil
  end

  local function jump()
    local loc = row_to_loc[vim.api.nvim_win_get_cursor(win)[1]]
    if not loc then return end
    local target = nil
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if w ~= win then
        local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
        if name:match(vim.pesc(loc.file) .. "$") then target = w; break end
      end
    end
    if target then
      vim.api.nvim_set_current_win(target)
    else
      vim.api.nvim_set_current_win(prev_win)
      vim.cmd("edit " .. vim.fn.fnameescape(loc.file))
    end
    vim.api.nvim_win_set_cursor(0, { loc.line, 0 })
    vim.cmd("normal! zz")
  end

  local o = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "q",     close, o)
  vim.keymap.set("n", "<Esc>", close, o)
  vim.keymap.set("n", "<CR>",  jump,  o)
end

-- Setup

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_augroup("CodeReviewSigns", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = "CodeReviewSigns",
    callback = function()
      M.refresh_signs()
      if M.state.base then
        setup_buf_for_review(vim.api.nvim_get_current_buf())
      end
    end,
  })

  vim.api.nvim_create_user_command("ReviewDiff",      function(o) M.open(o.fargs[1], o.fargs[2]) end, { nargs = "*" })
  vim.api.nvim_create_user_command("ReviewPick",      function() M.pick() end, {})
  vim.api.nvim_create_user_command("ReviewSave",      function() M.save() end, {})
  vim.api.nvim_create_user_command("ReviewList",      function() M.list_annotations() end, {})
  vim.api.nvim_create_user_command("ReviewDelete",    function() M.delete_annotation() end, {})
  vim.api.nvim_create_user_command("ReviewRefresh",   function() M.refresh() end, {})
  vim.api.nvim_create_user_command("ReviewAsk",       function() M.ask() end, {})
  vim.api.nvim_create_user_command("ReviewStatus",    function() M.status() end, {})
  vim.api.nvim_create_user_command("ReviewClose",     function() M.close() end, {})
  vim.api.nvim_create_user_command("ReviewSetStatus", function() M.set_status() end, {})
  vim.api.nvim_create_user_command("ReviewSummary",   function() M.review_summary() end, {})
  vim.api.nvim_create_user_command("ReviewPanel",     function() M.toggle_panel() end, {})

  local o = { noremap = true, silent = true }
  vim.keymap.set("n", "<leader>ra", M.add_annotation, { noremap = true, desc = "Add review note" })
  vim.keymap.set("v", "<leader>ra", function()
    local line1 = vim.fn.line("v")
    local line2 = vim.fn.line(".")
    if line1 > line2 then line1, line2 = line2, line1 end
    M.add_annotation(line1, line2)
  end, o)
  vim.keymap.set("n", "<leader>rf", M.set_full, o)
  vim.keymap.set("n", "<leader>re", M.set_extended, o)
  vim.keymap.set("n", "<leader>rd", M.set_default_context, o)
  vim.keymap.set("n", "<leader>rs", M.save, o)
  vim.keymap.set("n", "<leader>rl", M.list_annotations, o)
  vim.keymap.set("n", "<leader>rx", M.delete_annotation, o)
  vim.keymap.set("n", "<leader>rR", M.refresh, o)
  vim.keymap.set("n", "<leader>rz", M.resolve_annotation, o)
  vim.keymap.set("n", "<leader>ru", M.reanchor, o)
  vim.keymap.set("n", "<leader>ri", M.status, o)
  vim.keymap.set("n", "<leader>rA", M.ask, o)
  vim.keymap.set("n", "<leader>rp", "<cmd>DiffviewToggleFiles<cr>", o)
  vim.keymap.set("n", "<leader>rq", M.close, o)
  vim.keymap.set("n", "<leader>rS", M.set_status, o)
  vim.keymap.set("n", "<leader>rI", M.review_summary, o)
  vim.keymap.set("n", "<leader>rT", M.toggle_panel,   o)

  local wk_ok, wk = pcall(require, "which-key")
  if wk_ok then
    pcall(wk.add, {
      { "<leader>r",  group = "Review" },
      { "<leader>ra", desc = "Annotate → notes buffer" },
      { "<leader>rf", desc = "File: full content" },
      { "<leader>re", desc = "File: extended context" },
      { "<leader>rd", desc = "File: default context" },
      { "<leader>rs", desc = "Save structured review.md" },
      { "<leader>rl", desc = "List annotations (quickfix)" },
      { "<leader>rx", desc = "Delete annotation" },
      { "<leader>rz", desc = "Resolve annotation" },
      { "<leader>ru", desc = "Re-anchor stale annotation" },
      { "<leader>rR", desc = "Refresh (new round)" },
      { "<leader>ri", desc = "Status" },
      { "<leader>rA", desc = "Ask Claude CLI" },
      { "<leader>ra", desc = "Annotate (visual)", mode = "v" },
      { "<leader>rp", desc = "Toggle diffview file panel" },
      { "<leader>rq", desc = "Close review session" },
      { "<leader>rS", desc = "Set status (IMPL/ANS/DEF)" },
      { "<leader>rI", desc = "Summary by status (float)" },
      { "<leader>rT", desc = "Toggle questions panel" },
    })
  end
end

return M
