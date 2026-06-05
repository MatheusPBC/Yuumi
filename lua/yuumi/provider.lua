local M = {}

function M.run(command, payload, messages)
  messages = messages or {}
  if not command then
    return nil, messages.missing or "No Yuumi provider command configured"
  end

  local result = vim.system(command, { stdin = vim.json.encode(payload), text = true }):wait()
  if result.code ~= 0 then
    return nil, result.stderr ~= "" and result.stderr or (messages.failed or "Yuumi provider command failed")
  end

  return result.stdout
end

return M
