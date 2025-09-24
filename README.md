SkyBison for Neovim
===================

This is a Lua rewrite of the original [SkyBison](https://github.com/paradigm/skybison) Vim plugin.

Description
-----------

SkyBison is a plugin designed to make Neovim's command-line more intuitive and efficient. It provides real-time feedback and completions, reducing the number of keystrokes needed to execute commands.

SkyBison alleviates three key issues with the default command-line experience:

1.  **Always-on Completions**: Instead of requiring you to manually trigger completions (e.g., with `<C-d>`), SkyBison displays them automatically as you type.
2.  **Implicit Confirmation**: When your input narrows down to a single possible completion, SkyBison allows you to confirm and execute the command by simply pressing `<CR>`, without needing to tab-complete or finish typing.
3.  **Automatic Execution**: As an extension of the above, if you provide a count to the command, SkyBison can automatically execute the command as soon as it's uniquely identified, skipping the need for `<CR>` entirely.

For example, if you have three buffers open (`.vimrc`, `.bashrc`, and `.zshrc`) and you type `:SkyBison b `, you'll see a list of those buffers. If you then type `v`, SkyBison will know you mean `.vimrc` and will be ready to open it.

Installation
------------

### lazy.nvim

To install SkyBison using `lazy.nvim`, add the following to your configuration:

```lua
{
  "ibrahim317/skybison",
  -- If you are installing it from a local path, you can use the `dir` option:
  -- dir = "/path/to/your/local/skybison",
  config = function()
    -- Configuration goes here, if any in the future.
  end,
}
```

Usage
-----

SkyBison provides a `:SkyBison` command that you can map to a key of your choice. It's recommended to map it to `:`, so it replaces the default command-line.

```lua
vim.keymap.set("n", ":", "<Cmd>SkyBison<CR>", { noremap = true, silent = true })
```

You can also create more specific mappings for common commands:

```lua
-- For :b. You can prefix this with a count, e.g., 2<leader>b
vim.keymap.set("n", "<leader>b", "<Cmd>SkyBison b <CR>", { noremap = true, silent = true })

-- For :tag. You can prefix this with a count, e.g., 2<leader>t
vim.keymap.set("n", "<leader>t", "<Cmd>SkyBison tag <CR>", { noremap = true, silent = true })
```

### Options

You can configure SkyBison's fuzziness and other options by setting global variables in your Neovim configuration:

-   `g:skybison_fuzz`: Controls the fuzzy matching behavior.
    -   `0`: No fuzzy matching (default).
    -   `1`: Full fuzzy matching (characters in order, but with anything in between).
    -   `2`: Substring matching.

-   `g:skybison_numberselect`: Toggles whether you can select a completion by typing its number.
    -   `1`: Enabled (default).
    -   `0`: Disabled.

You can set these in your `init.lua` like this:

```lua
vim.g.skybison_fuzz = 1
vim.g.skybison_numberselect = 0
```

For more detailed usage instructions and a full list of keybindings within the SkyBison prompt, please see the original `doc/skybison.txt`.
