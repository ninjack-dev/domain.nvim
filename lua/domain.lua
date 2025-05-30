local M = {}

function M.setup(opts) -- Opts is unused for now
  vim.api.nvim_create_user_command('Domain', function(params)
    M.domain(params.line1, params.line2, params.fargs[1], params.bang)
  end, { range = true, nargs = 1 })
end

-- Perform a normal-mode action while within a line domain.
--
-- @param domain_start_line (number) Start line (1-based, inclusive)
-- @param domain_end_line   (number) End line (1-based, inclusive)
-- @param action            (string) Normal-mode command(s)
-- @param bang              (boolean) Whether to apply the bang to the `norm` command
function M.domain(domain_start_line, domain_end_line, action, bang)
  local line_range = domain_end_line - domain_start_line
  if line_range < 2 then
    vim.api.nvim_echo(
      { { "Line domain must be at least two lines!" } }, true, { err = true })
    return
  end

  -- Copy the target lines to scratch buffer in temporary window; this is the only way (as far as I can tell) to apply `normal` actions atomically
  -- In theory, the window should never actually appear. If it does, then it may be worth looking at other options for manipulating the buffer,
  -- or at the very least ensuring atomicity.
  local orig_bufnr = vim.api.nvim_get_current_buf()
  local temp_bufnr = vim.api.nvim_create_buf(false, true)
  local orig_lines = vim.api.nvim_buf_get_lines(orig_bufnr, domain_start_line - 1, domain_end_line, false)
  local orig_cursor_column = vim.api.nvim_win_get_cursor(0)[2]
  vim.api.nvim_buf_set_lines(temp_bufnr, 0, -1, false, orig_lines)

  -- Attempt action in scratch buffer
  local temp_win = vim.api.nvim_open_win(temp_bufnr, true, {
    relative = "editor", row = 0, col = 0, width = 1, height = 1, style = "minimal", hide = true
  })
  vim.api.nvim_win_set_cursor(temp_win, { 1, orig_cursor_column })
  local num_lines = vim.api.nvim_buf_line_count(temp_bufnr)
  local initial_loop = true
  local normal_cursor_delta

  local ok = true
  local errorMsg, warnMsg
  while true do
    local previous_cursor_row = vim.api.nvim_win_get_cursor(temp_win)[1]
    local prev_buf_lines = vim.api.nvim_buf_line_count(temp_bufnr)

    vim.api.nvim_buf_call(temp_bufnr, function()
      vim.cmd.normal { action, bang = bang }
    end)

    local curr_cursor_row = vim.api.nvim_win_get_cursor(temp_win)[1]
    local curr_buf_lines = vim.api.nvim_buf_line_count(temp_bufnr)

    local buf_line_delta = curr_buf_lines - prev_buf_lines
    local cursor_delta = curr_cursor_row - previous_cursor_row

    if initial_loop then
      if cursor_delta == 0 then
        errorMsg =
        "Cursor has not moved during initial loop! This will cause the operation to run on this line infinitely."
        ok = false
        break
      else
        normal_cursor_delta = cursor_delta
      end

      -- WIP: I'm unsure of how often it would actually be necessary to know this.
      -- if line_range % normal_cursor_delta ~= 0 then
      --   warnMsg = "The cursor movement delta (".. tostring(normal_cursor_delta) .. ") does not divide the domain size (" .. tostring(line_range) ..") cleanly; the last iteration may behave differently!"
      -- end

      initial_loop = false
    end

    if cursor_delta < normal_cursor_delta then
      break -- End of document reached
    end

    if buf_line_delta > cursor_delta then
      errorMsg =
      "Buffer size is increasing faster than the cursor is moving! This will cause the buffer to infinitely expand."
      break
    end

    num_lines = num_lines + buf_line_delta
    if curr_cursor_row > num_lines then break end
  end

  vim.api.nvim_win_close(temp_win, true)

  if ok then
    -- Replace lines in original buffer
    local new_lines = vim.api.nvim_buf_get_lines(temp_bufnr, 0, -1, false)
    vim.api.nvim_buf_set_lines(orig_bufnr, domain_start_line - 1, domain_end_line, false, new_lines)
  else
    vim.api.nvim_echo(
      { { errorMsg } }, true, { err = true })
  end
  if warnMsg ~= nil then
    vim.api.nvim_echo(
      { { warnMsg, "warningMsg" } }, true, {})
  end

  vim.api.nvim_buf_delete(temp_bufnr, { force = true })
end

return M
