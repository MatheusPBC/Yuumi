local M = {}

function M.root()
  local cwd = vim.uv.cwd()
  return cwd or vim.fn.getcwd()
end

function M.join_path(...)
  return table.concat(vim.tbl_filter(function(part)
    return part and part ~= ""
  end, { ... }), "/")
end

function M.resolve_path(path)
  if not path or path == "" then
    return nil
  end

  if vim.startswith(path, "/") then
    return path
  end

  return M.join_path(M.root(), path)
end

function M.resolve_existing_path(path)
  local resolved = M.resolve_path(path)
  if resolved and vim.uv.fs_stat(resolved) then
    return resolved
  end

  if not path or path == "" or vim.startswith(path, "/") then
    return resolved
  end

  local buffer_path = vim.api.nvim_buf_get_name(0)
  local dir = buffer_path ~= "" and vim.fn.fnamemodify(buffer_path, ":p:h") or M.root()

  while dir and dir ~= "/" and dir ~= "" do
    local candidate = M.join_path(dir, path)
    if vim.uv.fs_stat(candidate) then
      return candidate
    end

    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end

  return resolved
end

function M.read_file(path)
  local resolved = M.resolve_existing_path(path)
  local file = io.open(resolved, "r")

  if not file then
    return nil, "Could not read " .. resolved
  end

  local content = file:read("*a")
  file:close()
  return content, nil
end

function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Yuumi" })
end

function M.buf_relative_path(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  local root = M.root()

  if vim.startswith(path, root .. "/") then
    return path:sub(#root + 2)
  end

  return path
end

function M.clamp(value, min, max)
  if value < min then
    return min
  end

  if value > max then
    return max
  end

  return value
end

return M
