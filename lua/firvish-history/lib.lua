local ErrorList = require "firvish.types.errorlist"
local errorlist = require "firvish.lib.errorlist"
local lfs = require "lfs"

local ignore = {
  function(cwd, file)
    return vim.startswith(file, cwd) == false
  end,
  { pattern = "%[Wilder Float %d%]$" },
  { prefix = "firvish://" },
  { prefix = "man://" },
  { prefix = "term://" },
  { mode = "directory" },
  { exists = true },
  { git = true },
}

---@param file string
local function filter_workspace(cwd, file)
  for _, rule in ipairs(ignore) do
    local attrs = lfs.attributes(file)

    if type(rule) == "function" then
      if rule(cwd, file) then
        return false
      end
    elseif rule.pattern then
      if string.match(file, rule.pattern) then
        return false
      end
    elseif rule.prefix then
      if vim.startswith(file, rule.prefix) then
        return false
      end
    elseif rule.exists then
      if attrs == nil then
        return false
      end
    elseif rule.mode then
      if attrs and rule.mode == attrs.mode then
        return false
      end
    elseif rule.git then
      if string.match(file, "/%.git/") then
        return false
      end
    else
      local key = vim.tbl_keys(rule)[1]
      print("unknown rule name '" .. key .. "'")
    end
  end

  return true
end

local function filter_workspace_jumps(cwd, entry)
  local is_valid = vim.api.nvim_buf_is_valid(entry.bufnr)
  local filename = entry.filename or is_valid and vim.api.nvim_buf_get_name(entry.bufnr)
  if filename then
    local attrs = lfs.attributes(filename)

    for _, rule in ipairs(ignore) do
      if type(rule) == "function" then
        if rule(cwd, filename) then
          return false
        end
      elseif rule.pattern then
        if string.match(filename, rule.pattern) then
          return false
        end
      elseif rule.prefix then
        if vim.startswith(filename, rule.prefix) then
          return false
        end
      elseif rule.exists then
        if attrs == nil then
          return false
        end
      elseif rule.mode then
        if attrs and rule.mode == attrs.mode then
          return false
        end
      elseif rule.git then
        if string.match(filename, "/%.git/") then
          return false
        end
      else
        local key = vim.tbl_keys(rule)[1]
        print("unknown rule name '" .. key .. "'")
      end
    end
  end

  return true
end

local lib = {}

---@param buffer Buffer
---@param what string
function lib.refresh(buffer, what)
  if what == "oldfiles" then
    buffer:set_lines(lib.oldfiles(filter_workspace))
  else
    assert(what == "jumps", "invalid argument: 'what' must be 'oldfiles' or 'jumps'")
    buffer:set_lines(lib.jumps(filter_workspace_jumps))
  end
  buffer.options.modified = false
end

function lib.setqflist(what)
  local title = string.format("%s (local to workspace)", what)
  if what == "oldfiles" then
    return errorlist.from_lines("quickfix", lib.oldfiles(filter_workspace), { efm = "%f", title = title })
  else
    assert(what == "jumps", "invalid argument: 'what' must be 'oldfiles' or 'jumps'")
    return ErrorList:new("quickfix", {
      items = lib.jumps(filter_workspace_jumps),
      title = title,
    })
  end
end

---Like |:oldfiles| but only for the current workspace
---@param filter function?
---@return string[]
function lib.oldfiles(filter)
  local cwd = vim.fn.getcwd()
  local oldfiles = {}
  for _, file in ipairs(vim.v.oldfiles) do
    if filter and filter(cwd, file) then
      table.insert(oldfiles, vim.fn.fnamemodify(file, ":."))
    end
  end
  return oldfiles
end

function lib.jumps(filter)
  local cwd = vim.fn.getcwd()
  local jumps = vim.fn.getjumplist()[1]
  local sorted = {}
  for i = #jumps, 1, -1 do
    if filter == nil or filter(cwd, jumps[i]) then
      table.insert(sorted, jumps[i])
    end
  end
  return sorted
end

return lib
