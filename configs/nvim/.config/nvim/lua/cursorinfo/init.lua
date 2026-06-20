local M = {}

local ns_id = vim.api.nvim_create_namespace("cursorinfo")

local state = {
  enabled = true,
  current_buf_id = nil,
}

local default_config = {
  highlights = {
    CursorInfo = { link = "Comment", default = true },
    CursorInfoInsert = { link = "ModeMsg", default = true },
    CursorInfoVisual = { link = "ModeMsg", default = true},
  },
}

local function is_show()
  if not state.enabled then
    return false
  end

  local buf_type = vim.bo.buftype

  if buf_type ~= "" then
    return false
  end

  return true
end

local function update()
  if state.current_buf_id and vim.api.nvim_buf_is_valid(state.current_buf_id) then
    vim.api.nvim_buf_clear_namespace(state.current_buf_id, ns_id, 0, -1)
  end

  local buf_id = vim.api.nvim_get_current_buf()
  state.current_buf_id = buf_id

  if not is_show() then
    return
  end

  local line = vim.fn.line(".")
  local mode = vim.fn.mode()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local total_lines = vim.api.nvim_buf_line_count(buf_id)
  local mode_text = nil
  local mode_text_hl = nil

  if mode:match("^i") then
    mode_text = " <<INSERT"
    mode_text_hl = "CursorInfoInsert"
  elseif mode:match("[vV\22]") then
    local wc = vim.fn.wordcount()
    local visual_text = nil

    if mode:match("v") then
      visual_text = "VISUAL"
    elseif mode:match("V") then
      visual_text = "VISUAL-LINE"
    elseif mode:match("\22") then
      visual_text = "VISUAL-BLOCK"
    end

    mode_text = string.format(
      " <<%s %d lines, %d chars",
      visual_text,
      math.abs(vim.fn.line("v") - vim.fn.line(".")) + 1,
      wc.visual_chars or 0
    )
    mode_text_hl = "CursorInfoVisual"
  else
    mode_text = ""
  end

  local text = string.format(
    " %d/%d:%d ",
    row,
    total_lines,
    col
  )

  vim.api.nvim_buf_set_extmark(
    buf_id,
    ns_id,
    line - 1,
    0,
    {
      virt_text = {
        { mode_text, mode_text_hl },
        { text, "CursorInfo" },
      },
      virt_text_pos = "eol",
    }
  )
end

local function override_highlights(user_hls)
  user_hls = user_hls or {}

  local hls = vim.deepcopy(default_config.highlights)

  for name, val in pairs(user_hls) do
    hls[name] = val
  end

  return hls
end

function M.enable()
  state.enabled = true
  update()
end

function M.disable()
  state.enabled = false
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf_id) then
      vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
    end
  end
end

function M.toggle()
  if state.enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.setup(opts)
  opts = opts or {}

  local config = vim.tbl_deep_extend(
    "force",
    vim.deepcopy(default_config),
    opts
  )

  config.highlights = override_highlights(opts.highlights)

  vim.api.nvim_create_autocmd(
    {
      "ModeChanged",
      "BufEnter",
      "CursorMoved",
      "CursorMovedI"
    },
    {
      callback = update,
    }
  )

  vim.api.nvim_create_user_command("CursorInfoEnable", M.enable, {})
  vim.api.nvim_create_user_command("CursorInfoDisable", M.disable, {})
  vim.api.nvim_create_user_command("CursorInfoToggle", M.toggle, {})

  vim.api.nvim_set_hl(0, "CursorInfo", config.highlights.CursorInfo)
  vim.api.nvim_set_hl(0, "CursorInfoInsert", config.highlights.CursorInfoInsert)
  vim.api.nvim_set_hl(0, "CursorInfoVisual", config.highlights.CursorInfoVisual)
end

return M
