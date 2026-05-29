local M = {
  plan = nil,
  plan_path = nil,
  plan_root = nil,
  cursor = {
    task = 1,
    anchor = 1,
  },
  tasks_by_file = {},
  namespace = vim.api.nvim_create_namespace("yuumi"),
  inline_namespace = vim.api.nvim_create_namespace("yuumi_inline"),
  inline = nil,
}

function M.reset()
  M.plan = nil
  M.plan_path = nil
  M.plan_root = nil
  M.cursor = { task = 1, anchor = 1 }
  M.tasks_by_file = {}
  M.inline = nil
end

function M.current_task()
  if not M.plan or not M.plan.tasks then
    return nil
  end

  return M.plan.tasks[M.cursor.task]
end

function M.current_anchor()
  local task = M.current_task()
  if not task or not task.anchors then
    return nil
  end

  return task.anchors[M.cursor.anchor]
end

function M.index_tasks()
  M.tasks_by_file = {}

  if not M.plan or not M.plan.tasks then
    return
  end

  for task_index, task in ipairs(M.plan.tasks) do
    if task.file then
      M.tasks_by_file[task.file] = M.tasks_by_file[task.file] or {}
      table.insert(M.tasks_by_file[task.file], task_index)
    end
  end
end

return M
