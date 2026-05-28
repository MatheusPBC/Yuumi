# Yuumi

Yuumi is a plan-guided pair programming layer for Neovim.

It does not generate plans and does not auto-apply patches. An external agent,
such as OpenCode, writes a JSON plan. Yuumi turns that plan into navigation,
buffer marks, a right-side guidance board, inline ghost text, validation, and
optional AI fallback through an external CLI.

## What It Does

- Loads `.agent/current-plan.json` or any JSON plan path.
- Marks planned edit regions in the target buffers.
- Shows a right-side board with files, anchors, instructions, `writeText`, and
  done criteria.
- Suggests ghost text from `writeText` without requiring exact trigger words.
- Falls back to deterministic `inlineSuggestions` when configured.
- Optionally calls an external AI command for inline suggestions.
- Validates the current buffer against the active anchor's `writeText`.
- Persists anchor status, last plan path, and current cursor.

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

Local development setup:

```lua
{
  "MatheusPBC/Yuumi",
  dir = "/home/matheus/Documentos/vscode/Yuumi",
  config = function()
    require("yuumi").setup({
      inline_ai_enabled = true,
      gpt_command = {
        "/home/matheus/Documentos/vscode/Yuumi/scripts/yuumi-codex-inline",
      },
    })
  end,
}
```

## Quick Start

```vim
:YuumiLoad .agent/test-plan.json
:YuumiBoard
:YuumiNext
```

Then edit the highlighted region manually. If ghost text appears, accept it in
insert mode with `<M-y>`.

To check your progress:

```vim
:YuumiValidate
```

## Workflow

1. Generate or write a plan JSON.
2. Run `:YuumiLoad [path]`.
3. Pick an anchor from the picker or navigate with `:YuumiNext`.
4. Read the right-side `:YuumiBoard`.
5. Type the requested code manually.
6. Accept ghost text with `<M-y>` when useful.
7. Run `:YuumiValidate` or `:YuumiCheck`.
8. Mark completed anchors with `:YuumiDone`.

## Commands

| Command | Purpose |
| --- | --- |
| `:YuumiLoad [path]` | Load a plan JSON file. Defaults to `.agent/current-plan.json`. |
| `:YuumiFiles` | Pick a task/anchor with `vim.ui.select`. |
| `:YuumiNext` / `:YuumiPrev` | Navigate through anchors. |
| `:YuumiBoard` | Show the right-side guidance board. |
| `:YuumiHover` | Show guidance for the current anchor. |
| `:YuumiStatus` | Show current plan progress. |
| `:YuumiValidate` | Validate current buffer against active anchor `writeText`. |
| `:YuumiCheck` | Same validation path as `:YuumiValidate`. |
| `:YuumiDone` / `:YuumiSkip` | Persist anchor status. |
| `:YuumiResetState` | Clear persisted runtime state. |
| `:YuumiReanchor` | Re-locate anchors using plan text context. |
| `:YuumiAcceptInline` | Accept current inline hint from normal command mode. |
| `:YuumiExplain` / `:YuumiSuggest` / `:YuumiBreakdown` | Optional external AI popup commands. |

Default insert-mode inline accept keymap: `<M-y>`.

Floating popups such as `:YuumiHover`, `:YuumiStatus`, `:YuumiValidate`, and
`:YuumiCheck` can be closed by running the same command again. If the popup is
focused, press `q`.

## Suggested Keymaps

```lua
keys = {
  { "<leader>yl", "<cmd>YuumiLoad<cr>", desc = "Yuumi Load Plan" },
  { "<leader>yf", "<cmd>YuumiFiles<cr>", desc = "Yuumi Files" },
  { "<leader>yn", "<cmd>YuumiNext<cr>", desc = "Yuumi Next" },
  { "<leader>yp", "<cmd>YuumiPrev<cr>", desc = "Yuumi Prev" },
  { "<leader>yh", "<cmd>YuumiHover<cr>", desc = "Yuumi Hover" },
  { "<leader>ys", "<cmd>YuumiStatus<cr>", desc = "Yuumi Status" },
  { "<leader>yv", "<cmd>YuumiValidate<cr>", desc = "Yuumi Validate" },
  { "<leader>yb", "<cmd>YuumiBoard<cr>", desc = "Yuumi Board" },
  { "<leader>yd", "<cmd>YuumiDone<cr>", desc = "Yuumi Done" },
  { "<leader>yk", "<cmd>YuumiSkip<cr>", desc = "Yuumi Skip" },
  { "<leader>yr", "<cmd>YuumiReanchor<cr>", desc = "Yuumi Reanchor" },
}
```

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

Notes:

- `virtual_text_pos = "right_align"` keeps guidance away from code text.
- `open_files_on_load = true` opens the board and task picker after loading.
- `inline_ai_enabled = false` keeps AI calls off unless explicitly enabled.
- `gpt_command` is any executable command that receives JSON on stdin and
  returns text on stdout.

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

Important fields:

| Field | Purpose |
| --- | --- |
| `file` | Target file path relative to the project root. |
| `line` / `endLine` | Planned edit region. |
| `reason` | Why this anchor exists. |
| `guidance` | Human-readable instruction. |
| `writeText` | Exact planned lines shown in the board and used by inline/validation. |
| `doneWhen` | Checklist shown in the board and hover popup. |
| `inlineSuggestions` | Optional trigger-based deterministic hints. |
| `anchorText` / `beforeText` / `afterText` | Deterministic reanchor hints when line numbers drift. |

## Guidance Board

`:YuumiBoard` opens a floating panel on the right side of the editor. It shows:

- plan title
- files and anchors
- active anchor status
- file and line
- guidance
- `Write exactly:` block from `writeText`
- done criteria

The board is meant to remove guesswork. The developer still types or accepts
code manually.

## Inline Guidance

Yuumi inline guidance tries sources in this order:

1. `writeText`: completes the rest of the current line or the next missing line
   from the planned block without requiring an exact trigger.
2. `inlineSuggestions`: deterministic trigger-based hints.
3. AI fallback: only when `inline_ai_enabled = true` and `gpt_command` is set.

Examples:

```html
<meta name="viewport" conte
```

If the active anchor has this planned line:

```html
<meta name="viewport" content="width=device-width, initial-scale=1.0">
```

Yuumi suggests only the suffix:

```html
nt="width=device-width, initial-scale=1.0">
```

On an empty line, Yuumi suggests the next missing `writeText` line.

## Validation

`:YuumiValidate` and `:YuumiCheck` compare the current buffer with the active
anchor's `writeText` and report:

- `OK`: exact planned lines already present
- `Missing`: planned lines not found
- `Different`: nearby-looking lines that do not exactly match

This is deterministic validation. It checks exact planned lines, not semantic
equivalence.

## AI Fallback

Yuumi never stores provider keys and does not call OpenAI/OpenRouter directly.
AI is delegated to `gpt_command`.

If your wrapper uses API credentials, keep them outside the plugin in
environment variables such as `OPENAI_API_KEY`. Do not commit secrets.

When inline AI fallback runs, Yuumi sends an `InlineSuggest` JSON payload:

```json
{
  "action": "InlineSuggest",
  "file": "examples/index.html",
  "line": 5,
  "prefix": "<meta name=\"viewport\" conte",
  "nearbyLines": ["..."],
  "guidance": "Write this block at the top of the file.",
  "writeText": ["..."]
}
```

The command should return only the text suffix to insert at the cursor. Do not
return Markdown or explanation.

## Codex CLI OAuth Adapter

If you use Codex CLI with ChatGPT/OAuth login, Yuumi can call it through the
included wrapper:

```lua
require("yuumi").setup({
  inline_ai_enabled = true,
  gpt_command = {
    "/home/matheus/Documentos/vscode/Yuumi/scripts/yuumi-codex-inline",
  },
})
```

The wrapper reads Yuumi's JSON payload from stdin and runs:

```bash
codex exec --sandbox read-only --ephemeral
```

It uses your existing Codex CLI OAuth session. Log in to Codex CLI before using
it. Optionally choose a model with:

```bash
export YUUMI_CODEX_MODEL="gpt-5.2"
```

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

The source returns deterministic plan suggestions. It does not call an LLM.

## State

Yuumi persists local runtime state in `.agent/yuumi-state.json`:

- anchor statuses
- last loaded plan path
- current task/anchor cursor

This file is ignored by Git.

## Development

Run the test suite:

```bash
nvim --headless -u NONE -l tests/run.lua
```

Check diff whitespace before committing:

```bash
git diff --check
```
