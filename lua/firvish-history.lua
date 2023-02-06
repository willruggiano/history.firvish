---@mod firvish-history
---@brief [[
---Opinionated re-implementations of |:oldfiles| and |:jumps|, which are
---local to the current workspace.
---@brief ]]

---@tag :Oldfiles[!]
---@brief [[
---Like |:oldfiles| but filters |v:oldfiles| to only show you old files in
---the current workspace.
---
---By default, :Oldfiles opens a quickfix list with the filtered old files,
---while :Oldfiles! opens a plain |firvish-buffer|.
---
---See |firvish-history-config| for configuration options.
---@brief ]]

---@tag :Jumps[!]
---@brief [[
---Like |:jumps| but filters |getjumplist()| to only show you jumps that took
---place in/between files within the current workspace.
---
---By default, :Jumps opens a quickfix list with the filtered old files,
---while :Jumps! opens a plain |firvish-buffer|.
---
---See |firvish-history-config| for configuration options.
---@brief ]]

local firvish = require "firvish"
local lib = require "firvish-history.lib"

local Buffer = require "firvish.buffer"

local M = {}

---@tag firvish-history-config
---@brief [[
---Default configuration:
--->
---{
---  ---Commands open a quickfix list unless <bang> is given, in which case
---  ---they open a plain |firvish-buffer|. This setting, when `true`,
---  ---inverts that behavior.
---  invert = false,
---  ---How to open the |firvish-buffer|
---  open = function(filename)
---    vim.cmd.edit(filename)
---  end,
---  ---Keymaps to set in the |firvish-buffer|
---  keymaps = {
---    n = {},
---  },
---}
---<
---@brief ]]
M.config = {
  invert = false,
  open = function(filename)
    vim.cmd.edit(filename)
  end,
  keymaps = {
    n = {},
  },
}

M.filename = {
  jumps = "firvish://jumps",
  oldfiles = "firvish://oldfiles",
}

---Configure the plugin
---@see firvish-history-config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  for name, filename in pairs(M.filename) do
    firvish.extension.register(name, {
      config = M.config,
      filetype = {
        filename = filename,
        filetype = function(_, bufnr)
          M.setup_buffer(bufnr, name)
        end,
      },
    })

    vim.api.nvim_create_user_command(name:gsub("^%l", string.upper), function(args)
      if M.config.invert then
        if args.bang then
          lib.setqflist(name):open()
        else
          M.config.open(filename)
        end
      else
        if args.bang then
          M.config.open(filename)
        else
          lib.setqflist(name):open()
        end
      end
    end, { bang = true, desc = string.format("Open the %s list", name) })
  end
end

---@package
function M.setup_buffer(bufnr, what)
  local buffer = Buffer.new(bufnr)

  lib.refresh(buffer, what)

  buffer:create_autocmd({ "BufEnter", "BufWinEnter" }, function()
    lib.refresh(buffer, what)
  end)

  buffer:create_autocmd("BufWriteCmd", function()
    buffer.options.modified = false
  end)

  buffer:create_autocmd("BufWritePost", function()
    lib.refresh(buffer, what)
  end)
end

return M
