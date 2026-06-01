# Yuumi

Yuumi is a plan-guided pair programming layer for Neovim.

It does not generate plans and does not auto-apply patches. An external agent,
such as OpenCode, writes a JSON plan. Yuumi turns that plan into navigation,
minimal buffer markers, a right-side guidance board, inline ghost text, validation, and
optional AI fallback through an external CLI.

## What It Does

- Loads `.agent/current-plan.json` or any JSON plan path.
- Marks patch locations in the target buffers with compact `patch aqui` text.
- Shows a right-side board with files, patches, status, explanation, expected
  code, and done criteria.
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
:Yuumi
```

`:Yuumi` is the main workflow command. With no plan loaded, it opens the plan
picker. With a plan loaded, it opens the board and patch picker.

This repository includes two sample plans you can alternate between:

```vim
:YuumiLoad .agent/current-plan.json
:YuumiLoad .agent/html-plan.json
:YuumiPlans
```

`current-plan.json` targets `examples/sample.lua`. `html-plan.json` targets
`examples/index.html`. `:YuumiLoad` without a path opens the same plan picker as
`:YuumiPlans`. The picker searches `.agent/plans` first, then `.agent`.
`:YuumiFiles` does not load a new plan; it lists the files from the plan that is
already loaded, with pending anchor counts.

Then edit the highlighted region manually. If ghost text appears, accept it in
insert mode with `<M-y>`.

To check your progress:

```vim
:YuumiValidate
```

## Workflow

1. Generate or write a plan JSON.
2. Run `:Yuumi` and choose a plan.
3. Run `:Yuumi` again to pick a patch, or navigate patches with `:YuumiNext`.
4. Read the right-side board.
5. Type the requested code manually.
6. Accept ghost text with `<M-y>` when useful.
7. Run `:YuumiValidate` or `:YuumiCheck`.
8. Mark completed anchors with `:YuumiDone`.

## Commands

| Command | Purpose |
| --- | --- |
| `:Yuumi` | Main workflow: pick a plan when none is loaded, otherwise pick a patch. |
| `:YuumiLoad [path]` | Without a path, pick a plan. With a path, load that plan directly. |
| `:YuumiPlans` | Pick and load a plan JSON from `.agent/plans` or `.agent`. |
| `:YuumiFiles` | Pick a target file from the currently loaded plan. |
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
  { "<leader>yy", "<cmd>Yuumi<cr>", desc = "Yuumi" },
  { "<leader>yl", "<cmd>YuumiLoad<cr>", desc = "Yuumi Load Plan" },
  { "<leader>yP", "<cmd>YuumiPlans<cr>", desc = "Yuumi Plans" },
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
  show_virtual_lines = false,
  open_files_on_load = true,
  inline_debounce_ms = 80,
  inline_ai_enabled = false,
  accept_keymap = "<M-y>",
  gpt_command = nil,
})
```

Notes:

- `virtual_text_pos = "right_align"` keeps guidance away from code text.
- `show_virtual_lines = false` keeps the main buffer clean; the board carries
  the full plan details.
- `open_files_on_load = true` opens the board and task picker after explicit path loads. Plain `:YuumiLoad` opens the plan picker first.
- `inline_ai_enabled = false` keeps AI calls off unless explicitly enabled.
- `gpt_command` is any executable command that receives JSON on stdin and
  returns text on stdout.

## Plan Contract

Use `version: 2` guided patch plans as the default contract. A plan is a list of
manual patches: where to find the edit, why it exists, how the final code should
look, and how to confirm it is done. Guided patches locate edit regions by
context and do not depend on exact line numbers or exact indentation.

Default shape:

```json
{
  "version": 2,
  "title": "Add AppSync debug log",
  "description": "Guide manual insertion of structured debug logs around AppSync command flow.",
  "validation": [
    "nvim --headless -u NONE -l tests/run.lua",
    "git diff --check"
  ],
  "patches": [
    {
      "file": "src/handlers/example/lambda_function.py",
      "id": "log-after-parse-input",
      "summary": "Add a structured log after input parsing.",
      "locator": {
        "afterText": "device_id, payload = _parse_input(event)",
        "beforeText": "device_lookup_id = device_id"
      },
      "insert": [
        "logger.info(",
        "    \"AppSync device command input parsed\",",
        "    extra={\"device_id\": device_id},",
        ")"
      ],
      "doneWhen": ["The log is between parse_input and device_lookup_id"]
    }
  ]
}
```

Yuumi normalizes v2 patches internally. Legacy line-based v1 plans are still supported.

Default required fields:

| Field | Purpose |
| --- | --- |
| `version` | Must be `2` for new plans. |
| `title` | Short plan title shown in the board. |
| `patches[]` | Ordered list of manual patches. |
| `patches[].id` | Stable lowercase slug for the patch. |
| `patches[].file` | Target file path relative to project root. |
| `patches[].summary` | Short label shown in pickers and board. |
| `patches[].locator.afterText` | Existing line before the insertion region. |
| `patches[].locator.beforeText` | Existing line after the insertion region. |
| `patches[].reason` | Why this patch exists. |
| `patches[].guidance` | Human instruction for executing the patch. |
| `patches[].insert` | Final lines the developer should type manually. |
| `patches[].doneWhen` | Concrete checks for considering the patch complete. |

Useful optional fields:

| Field | Purpose |
| --- | --- |
| `description` | Longer context for the whole plan. |
| `tags` | Search/filter labels for external agents. |
| `priority` | Plan priority, for example `low`, `medium`, or `high`. |
| `risk` | Risk hint, for example `low`, `medium`, or `high`. |
| `validation` | Commands or manual checks to run after completing the plan. |
| `patches[].inlineSuggestions` | Optional deterministic completion triggers. |

Avoid in new plans:

- `line` / `endLine` as the primary locator; use them only as fallback.
- `tasks[].anchors[]`; it is legacy v1 shape.
- Generic `steps`, `todo`, or prose-only plans without `locator` and `insert`.

Legacy v1 `.agent/current-plan.json` shape:

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

Legacy v1 fields:

| Field | Purpose |
| --- | --- |
| `file` | Target file path relative to the project root. |
| `line` / `endLine` | Planned edit region. |
| `locator.afterText` / `locator.beforeText` | Context boundaries for guided patches. |
| `reason` | Why this anchor exists. |
| `guidance` | Human-readable instruction. |
| `writeText` / `patch.writeText` | Planned lines shown in the board and used by inline/validation. |
| `patch.mode` | Guided patch operation, currently `insert-between`. |
| `doneWhen` | Checklist shown in the board and hover popup. |
| `inlineSuggestions` | Optional trigger-based deterministic hints. |
| `anchorText` / `beforeText` / `afterText` | Deterministic reanchor hints when line numbers drift. |

## Guidance Board

`:YuumiBoard` opens a floating panel on the right side of the editor. It shows:

- plan title and progress summary
- `Arquivos`: target files, compact paths, patch counts, and anchor status
- `Patch atual`: active file, line, status, and summary
- `Por que`: patch reason
- `Fazer`: execution guidance
- `Codigo esperado`: exact lines from `writeText`
- `Checklist`: done criteria
- `Plano`: execution queue with the current patch and next pending patches

The main buffer only shows a compact `patch aqui` marker. The board is meant to
be the execution guide, while the developer still types or accepts code
manually.

Board status labels are highlighted by state: pending, done, stale, and skipped.

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
