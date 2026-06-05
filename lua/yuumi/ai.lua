local anchor_util = require("yuumi.anchor")
local config = require("yuumi.config")
local persist = require("yuumi.persist")
local provider = require("yuumi.provider")
local state = require("yuumi.state")
local util = require("yuumi.util")
local validate = require("yuumi.validate")

local M = {}

local function review_status(output)
  local ok, decoded = pcall(vim.json.decode, output)
  if ok and type(decoded) == "table" and type(decoded.status) == "string" then
    return decoded.status
  end

  local lower = output:lower()
  if lower:match("needs%-change") or lower:match("needs change") then
    return "needs-change"
  end
  if lower:match("approved") then
    return "approved"
  end

  return "reviewed"
end

local function current_patch()
  local task = state.current_task()
  local anchor = state.current_anchor()

  if not task or not anchor then
    return nil, nil, "No Yuumi patch selected"
  end

  return task, anchor, nil
end

function M.build_payload(action)
  local task, anchor, err = current_patch()
  if err then
    return nil, err
  end

  local validation = validate.current_buffer()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  return {
    action = action,
    plan = {
      title = state.plan and state.plan.title or nil,
      path = state.plan_path,
      root = state.plan_root,
    },
    patch = {
      file = task.file,
      task = task.id,
      summary = task.summary,
      id = anchor.id,
      line = anchor.line,
      reason = anchor.reason,
      guidance = anchor.guidance,
      doneWhen = anchor.doneWhen,
    },
    expected = anchor_util.write_text(anchor),
    validation = validation,
    buffer = table.concat(lines, "\n"),
  }
end

function M.run(payload)
  return provider.run(config.options.ai_command, payload, {
    missing = "No Yuumi AI command configured",
    failed = "Yuumi AI command failed",
  })
end

function M.check_current()
  local payload, payload_err = M.build_payload("check")
  if not payload then
    return nil, payload_err
  end

  local output, err = M.run(payload)
  if not output then
    state.ai_review = { status = "blocked", error = err }
    return nil, err
  end

  state.ai_review = {
    status = review_status(output),
    action = payload.action,
    file = payload.patch.file,
    patch = payload.patch.id,
    output = output,
  }
  persist.save()
  return state.ai_review
end

function M.show_check()
  local result, err = M.check_current()
  if not result then
    util.notify(err, vim.log.levels.ERROR)
    return
  end

  util.notify("Yuumi AI review updated")
end

return M
