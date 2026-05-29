local locator = require("yuumi.locator")
local minit = require("tests.minit")

local function cleanup()
  vim.cmd("enew!")
end

minit.test("locates guided patch region between afterText and beforeText", function()
  cleanup()

  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "def lambda_handler(event, context):",
    "    device_id, payload = _parse_input(event)",
    "    device_lookup_id = device_id",
    "    return device_lookup_id",
  })

  local anchor = {
    line = 999,
    kind = "guided-patch",
    locator = {
      afterText = "device_id, payload = _parse_input(event)",
      beforeText = "device_lookup_id = device_id",
    },
    patch = {
      mode = "insert-between",
      writeText = { "logger.info(\"parsed\")" },
    },
  }

  local start_line, end_line = locator.range(0, anchor)

  minit.eq(3, start_line)
  minit.eq(3, end_line)

  cleanup()
end)

minit.test("falls back to expanded line range for legacy anchors", function()
  cleanup()

  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three", "four" })

  local start_line, end_line = locator.range(0, {
    line = 2,
    writeText = { "two", "three" },
  })

  minit.eq(2, start_line)
  minit.eq(3, end_line)

  cleanup()
end)
