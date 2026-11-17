local function update_hl_visual_match()
  if vim.w.hl_visual_match_id then
    pcall(vim.fn.matchdelete, vim.w.hl_visual_match_id)
    vim.w.hl_visual_match_id = nil
  end

  -- 1行に収まる選択だけをハイライト。行跨ぎを許す場合、選択の大きさだけパターン
  -- が大きくなってしまう。
  local mode = vim.fn.mode()
  if not mode:match("^[vV]$") or vim.fn.line("v") ~= vim.fn.line(".") then
    return
  end

  local text = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })[1]
  if not text:match("%S") then
    return
  end

  vim.w.hl_visual_match_id =
    vim.fn.matchadd("VisualMatch", [[\V\c]] .. vim.fn.escape(text, [[\]]))
end

vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
  callback = update_hl_visual_match,
})
