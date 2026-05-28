# Yuumi

Yuumi is a plan-guided pair programming layer for Neovim.

It does not generate plans and does not edit files by itself. OpenCode or any
external agent writes `.agent/current-plan.json`; Yuumi turns that plan into
navigation, marks, hover guidance, deterministic inline hints, and optional
completion items.

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
:YuumiFiles
:YuumiNext
:YuumiHover
```

Yuumi defaults to `.agent/current-plan.json`.

## Commands

| Command | Purpose |
| --- | --- |
| `:YuumiLoad [path]` | Load a plan JSON file |
| `:YuumiFiles` | Pick a task/anchor with `vim.ui.select` |
| `:YuumiNext` / `:YuumiPrev` | Navigate anchors |
| `:YuumiHover` | Show guidance for the current anchor |
| `:YuumiDone` / `:YuumiSkip` | Persist anchor status |
| `:YuumiResetState` | Clear persisted state |
| `:YuumiReanchor` | Re-locate anchors using plan text context |
| `:YuumiAcceptInline` | Accept deterministic inline hint |

Default inline accept keymap: `<M-y>`.

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
