--- Spawn a sclang process.
-- @module scnvim/sclang
-- @author David Granström
-- @license GPLv3

local scnvim = require('scnvim')
local utils = require('scnvim/utils')

local M = {}
local uv = vim.loop
local handle
local postwin_bufnr

local stdin = uv.new_pipe(false)
local stdout = uv.new_pipe(false)
local stderr = uv.new_pipe(false)

local function get_options(path)
  local options = {}
  options.stdio = {
    stdin,
    stdout,
    stderr,
  }
  options.cwd = vim.call('expand', '%:p:h')
  -- TODO: get sclang user options
  options.args = {'-i', 'scnvim', '-d', options.cwd}
  -- windows specific settings
  options.verbatim = true
  options.hide = true
  return options
end

-- TODO: move to separate class
-- look at nvim_buf_attach() to listen for events
local function print_to_postwin(line)
  if postwin_bufnr then
    vim.api.nvim_buf_set_lines(postwin_bufnr, -1, -1, true, {line})
    local num_lines = vim.api.nvim_buf_line_count(postwin_bufnr)
    local id = vim.call('bufwinid', postwin_bufnr)
    vim.api.nvim_win_set_cursor(id, {num_lines, 0})
  end
end

local on_stdout = function() 
  local stack = {''}
  return function(err, data)
    assert(not err, err)
    if data then
      table.insert(stack, data)
      -- TODO: not sure if \r is needed.. need to check on windows.
      local got_line = vim.endswith(data, '\n') or vim.endswith(data, '\r')
      if got_line then
        local str = table.concat(stack, "")
        local lines = vim.gsplit(str, '[\n\r]')
        for line in lines do
          if line ~= '' then
            print_to_postwin(line)
          end
        end
        stack = {''}
      end
    end
  end
end

function M.is_running()
  return handle and handle:is_active()
end

function M.send(data, silent)
  if M.is_running() then
    stdin:write({data, string.char(silent and 0x1b or 0x0c)})
  end
end

local function safe_close(handle)
  if not handle:is_closing() then
    handle:close()
  end
end

function M.on_exit()
  stdout:read_stop()
  stderr:read_stop()
  safe_close(stdin)
  safe_close(stdout)
  safe_close(stderr)
  safe_close(handle)
end

function M.start()
  if M.is_running() then
    vim.call('scnvim#util#err', {'sclang is already running'})
    return
  end

  local settings = vim.call('scnvim#util#get_user_settings')
  local sclang = settings.paths.sclang_executable
  local options = get_options()
  handle = uv.spawn(sclang, options, vim.schedule_wrap(M.on_exit))
  assert(handle, 'Could not open sclang process')

  postwin_bufnr = vim.call('scnvim#postwindow#create') -- TODO: should also move to lua
  scnvim.init()
  vim.call('scnvim#document#set_current_path') -- TODO: should also move to lua

  local onread = on_stdout()
  stdout:read_start(vim.schedule_wrap(onread))
  stderr:read_start(vim.schedule_wrap(onread))
end

function M.stop()
  if M.is_running() then
    M.send('0.exit', true)
  else
    vim.call('scnvim#util#err', {'sclang is not running'})
  end
end

return M
