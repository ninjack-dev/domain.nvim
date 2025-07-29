local M = {}

--- @class Options

---@param opts Options
function M.setup(opts) -- Opts is unused for now
  vim.api.nvim_create_user_command('Domain', function(params)
    M.domain(params.line1, params.line2, params.fargs[1], params.bang, opts)
  end, { range = true, nargs = 1 })
end

-- Perform a normal-mode action while within a line domain.
--
---@param domain_start_line number Start line (1-based, inclusive)
---@param domain_end_line   number End line (1-based, inclusive)
---@param action            string Normal-mode command(s)
---@param bang              boolean Whether to apply the bang to the `norm` command
---@param opts              Options Unused for now
function M.domain(domain_start_line, domain_end_line, action, bang, opts)
  local line_range = domain_end_line - domain_start_line
  if line_range < 1 then
    vim.api.nvim_echo(
      { { "Line domain must be at least two lines" } }, true, { err = true })
    return
  end

  local ok = true
  local errorMsg, warnMsg -- warnMsg is currently unused

  local initial_loop = true
  local normal_cursor_delta

  while true do
    local previous_cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    local prev_buf_line_count = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_buf_call(0, function()
      -- Suppress --no lines in buffer-- notification. It may be worth looking into exiting if it ever gets to that point.
      -- Here's the original for convenience
      -- vim.cmd.normal { action, bang = bang, silent = true }
      vim.cmd("silent! normal" .. (bang and "!" or "") .. " " .. action)
    end)

    local current_cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    local curr_buf_line_count = vim.api.nvim_buf_line_count(0)

    local buffer_line_count_delta = curr_buf_line_count - prev_buf_line_count
    local cursor_delta = current_cursor_row - previous_cursor_row

    if initial_loop then
      initial_loop = false

      if cursor_delta == 0 and buffer_line_count_delta == 0 then
        errorMsg =
        "Cursor has not moved during initial loop! This will cause the operation to run on this line infinitely."
        ok = false
        break
      else
        normal_cursor_delta = cursor_delta
      end
    end

    domain_end_line = domain_end_line +
        buffer_line_count_delta                   -- Offset the end of the domain based on whether it grew or shrank

    if current_cursor_row > domain_end_line or    -- Moved outside bottom of domain
        current_cursor_row < domain_start_line or -- Moved outside top of domain
        cursor_delta < normal_cursor_delta then   -- End of document reached; only possible in some scenarios
      break
    end

    if buffer_line_count_delta >= cursor_delta then
      errorMsg =
      "Buffer size is increasing as fast as or faster than the cursor is moving! This will cause the buffer to infinitely expand."
      ok = false
      break
    end
  end

  if not ok then
    vim.api.nvim_echo(
      { { errorMsg } }, true, { err = true })
    vim.cmd.undo()
  end

  if warnMsg ~= nil then
    vim.api.nvim_echo(
      { { warnMsg, "warningMsg" } }, true, {})
  end
end

return M
