local M = {}
local api = vim.api
local fn = vim.fn

dofile(vim.g.base46_cache .. "nvdash")

local opts = require("nvconfig").ui.nvdash

api.nvim_create_autocmd("BufLeave", {
  callback = function()
    if vim.bo.ft == "nvdash" then
      vim.g.nvdash_displayed = false
    end
  end,
})

local map = function(keys, action, buf)
  for _, v in ipairs(keys) do
    vim.keymap.set("n", v, action, { buffer = buf })
  end
end

local function txt_pad(str, max_str_w)
  local av = (max_str_w - fn.strwidth(str)) / 2
  av = math.floor(av)
  return string.rep(" ", av) .. str .. string.rep(" ", av)
end

local function btn_gap(txt1, txt2, max_str_w)
  local btn_len = fn.strwidth(txt1) + #txt2
  local spacing = max_str_w - btn_len
  return txt1 .. string.rep(" ", spacing) .. txt2
end

M.open = function()
  local win = api.nvim_get_current_win()
  local ns = api.nvim_create_namespace "nvdash"
  local winh = api.nvim_win_get_height(win)
  local winw = api.nvim_win_get_width(win)
  local buf = vim.api.nvim_create_buf(false, true)
  local nvdash_w = 0

  api.nvim_win_set_buf(0, buf)

  ------------------------ find largest string's width -----------------------------
  for _, val in ipairs(opts.header) do
    if fn.strwidth(val) > nvdash_w then
      nvdash_w = #val
    end
  end

  for _, val in ipairs(opts.buttons) do
    local str = type(val.txt) == "string" and val.txt or val.txt()
    str = val.keys and str .. val.keys or str

    if nvdash_w < fn.strwidth(str) then
      nvdash_w = #str
    end
  end
  ----------------------- save display txt -----------------------------------------
  local dashboard = {}

  for _, v in ipairs(opts.header) do
    table.insert(dashboard, { txt = txt_pad(v, nvdash_w), hl = "NvDashAscii" })
  end

  for _, v in ipairs(opts.buttons) do
    local txt

    if not v.keys then
      local str = type(v.txt) == "string" and v.txt or v.txt()
      txt = v.rep and string.rep(str, nvdash_w) or txt_pad(str, nvdash_w)
    else
      txt = btn_gap(v.txt, v.keys, nvdash_w)
    end

    table.insert(dashboard, { txt = txt, hl = v.hl, cmd = v.cmd })

    if not v.no_gap then
      table.insert(dashboard, { txt = string.rep(" ", nvdash_w) })
    end
  end

  local row_i = math.floor((winh / 2) - (#dashboard / 2))
  local col_i = math.floor((winw / 2) - (nvdash_w / 2))

  -- make all lines available
  local empty_str = {}

  for i = 1, winh do
    empty_str[i] = string.rep(" ", winw)
  end

  -- set text + highlight
  api.nvim_buf_set_lines(buf, 0, -1, false, empty_str)
  local key_lines = {}

  for i, v in ipairs(dashboard) do
    v.txt = "  " .. v.txt .. "  "
    v.hl = v.hl or "NvDashButtons"
    local opt = { virt_text_pos = "overlay", virt_text = { { v.txt, v.hl } } }
    api.nvim_buf_set_extmark(buf, ns, row_i + i, col_i, opt)

    if v.cmd then
      table.insert(key_lines, { i = row_i + i + 1, cmd = v.cmd })
    end
  end

  ------------------------------------ keybinds ------------------------------------------
  -- disable left/right
  map({ "h", "l", "<left>", "<right>" }, "", buf)

  local btn_start_i = row_i + #opts.header + 2
  api.nvim_win_set_cursor(win, { btn_start_i, col_i + 5 })

  map({ "k", "<up>" }, function()
    local cur = fn.line "."
    local target_line = cur == key_lines[1].i and key_lines[#key_lines].i or cur - 2
    api.nvim_win_set_cursor(win, { target_line, col_i + 5 })
  end, buf)

  map({ "j", "<down>" }, function()
    local cur = fn.line "."
    local target_line = cur == key_lines[#key_lines].i and key_lines[1].i or cur + 2
    api.nvim_win_set_cursor(win, { target_line, col_i + 5 })
  end, buf)

  map({ "<cr>" }, function()
    local line = fn.line "."

    local key = vim.tbl_filter(function(item)
      return item.i == line
    end, key_lines)

    if key[1] and key[1].cmd then
      vim.cmd(key[1].cmd)
    end
  end, buf)

  require("nvchad.utils").set_cleanbuf_opts "nvdash"
end

return M
