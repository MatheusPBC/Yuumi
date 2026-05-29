local M = {}

function M.write_text(anchor)
  if anchor.writeText then
    return anchor.writeText
  end

  if anchor.patch and anchor.patch.writeText then
    return anchor.patch.writeText
  end

  return {}
end

return M
