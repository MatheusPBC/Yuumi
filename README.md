# Yuumi

Yuumi is a plan-guided pair programming layer for Neovim.

It does not generate plans and does not edit files by itself. OpenCode or any
external agent writes `.agent/current-plan.json`; Yuumi turns that plan into
navigation, marks, hover guidance, a right-side guidance board, deterministic
inline hints, and optional completion items.

## Install

With lazy.nvim:

```lua
{
  "MatheusPBC/Yuumi",
  config = function()
    require("yuumi").setup()
  end,
}
```

## Quick Start

```vim
:YuumiLoad
:YuumiBoard
:YuumiFiles
:YuumiNext
:YuumiHover
```

Yuumi defaults to `.agent/current-plan.json`.

## Commands

| Command | Purpose |
| --- | --- |
| `:YuumiLoad [path]` | Load a plan JSON file |
| `:YuumiBoard` | Show the right-side guidance board |
| `:YuumiFiles` | Pick a task/anchor with `vim.ui.select` |
| `:YuumiNext` / `:YuumiPrev` | Navigate anchors |
| `:YuumiHover` | Show guidance for the current anchor |
| `:YuumiStatus` | Show current plan progress |
| `:YuumiDone` / `:YuumiSkip` | Persist anchor status |
| `:YuumiResetState` | Clear persisted state |
| `:YuumiReanchor` | Re-locate anchors using plan text context |
| `:YuumiAcceptInline` | Accept deterministic inline hint |

Default inline accept keymap: `<M-y>`.

Floating popups such as `:YuumiHover`, `:YuumiStatus`, and `:YuumiCheck` can be
closed by running the same command again. If the popup is focused, press `q`.

## Guidance Board

`:YuumiBoard` opens a floating panel on the right side of the editor. It shows:

- plan title
- files and anchors
- current anchor status
- current guidance, removal text, and done criteria

When `open_files_on_load` is enabled, `:YuumiLoad` opens the board before the
file picker so the developer sees the plan context first.

## Configuration

Default setup:

```lua
require("yuumi").setup({
  plan_path = ".agent/current-plan.json",
  state_path = ".agent/yuumi-state.json",
  highlight_group = "YuumiAnchor",
  virtual_text_prefix = "yuumi: ",
  virtual_text_pos = "right_align",
  show_virtual_lines = true,
  open_files_on_load = true,
  inline_debounce_ms = 80,
  inline_ai_enabled = false,
  accept_keymap = "<M-y>",
  gpt_command = nil,
})
```

Set `virtual_text_pos` to any `nvim_buf_set_extmark()` virtual text position
supported by your Neovim version. The default is `right_align` so guidance does
not look like typed code.

## Plan Contract

Minimum `.agent/current-plan.json`:

```json
{
  "version": 1,
  "title": "Example plan",
  "tasks": [
    {
      "id": "task-1",
      "file": "src/example.lua",
      "summary": "Manual edit guidance",
      "anchors": [
        {
          "id": "anchor-1",
          "line": 10,
          "endLine": 12,
          "anchorText": "exact text to find if line numbers drift",
          "beforeText": "nearby text before the anchor",
          "afterText": "nearby text after the anchor",
          "reason": "Why this region matters",
          "guidance": "What the developer should do manually",
          "writeText": [
            "local value = compute_value(input)",
            "return value"
          ],
          "doneWhen": ["Expected behavior is implemented"],
          "inlineSuggestions": [
            {
              "trigger": "local",
              "insertText": "local value = compute_value(input)"
            }
          ]
        }
      ]
    }
  ]
}
```

Use `anchorText`, `beforeText`, and `afterText` when possible. They let Yuumi
reanchor deterministically if line numbers drift.

## Inline Guidance

Yuumi inline guidance tries sources in this order:

- `writeText`: completes the rest of the current line or the next missing line
  from the planned block, without requiring an exact trigger.
- `inlineSuggestions`: deterministic trigger-based hints.
- AI fallback: only when `inline_ai_enabled = true` and `gpt_command` is set.

For AI fallback, Yuumi sends an `InlineSuggest` payload with file, cursor line,
current prefix, nearby lines, guidance, and `writeText`. The command should
return only the text suffix to insert at the cursor.

## blink.cmp

Yuumi exposes a `blink.cmp` source at `yuumi.blink`.

```lua
require("blink.cmp").setup({
  sources = {
    default = { "lsp", "path", "snippets", "buffer", "yuumi" },
    providers = {
      yuumi = {
        name = "Yuumi",
        module = "yuumi.blink",
      },
    },
  },
})
```

The source returns `inlineSuggestions` for the current file. It does not call an
LLM.

## GPT Adapter

Yuumi does not store API keys and does not call OpenAI/OpenRouter directly.

Instead, configure `gpt_command` as an external command. Yuumi sends a JSON
payload to stdin and displays stdout.

```lua
require("yuumi").setup({
  gpt_command = { "yuumi-gpt-wrapper" },
})
```

Your wrapper can use `OPENAI_API_KEY`, OpenRouter, OpenCode, a local model, or
any other provider outside Yuumi.

Example wrapper responsibilities:

```text
stdin:  { "action": "Explain", "file": "src/example.lua", "line": 10 }
stdout: Markdown/text response to show in a floating window
```

Keep secrets in environment variables such as `OPENAI_API_KEY`; do not commit
them into the repository.

## State

Yuumi persists local runtime state in `.agent/yuumi-state.json`:

- anchor statuses
- last loaded plan path
- current task/anchor cursor

This file is ignored by Git.
