<h1 align="center">Fcitx.nvim</h1>

A Neovim plugin for storing and restoring fcitx status of several mode groups separately.

This plugin stores fcitx status while leaving a <ins>mode group</ins> and restores a mode group's
fcitx status while entering this group. All disabled mode groups and other modes share one status.

**Mode group**:

- `insert`: See `:h InsertEnter`
- `cmdline`: See `:h CmdlineEnter`, `:`, `>`, `=`, and `@`
- `cmdtext`: See `:h CmdlineEnter`, `/`, `?` and `-`
- `terminal`: See `:h TermEnter`
- `select`: See `:h mode()`, `s`, `S` and `\S`

## Installation

For [packer.nvim](https://github.com/wbthomason/packer.nvim) user:

```lua
require('packer').startup(function()
  use { 'alohaia/fcitx.nvim'
    config = function ()
        require 'fcitx' {
            -- options
        }
    end
  }
end)
```

For my built-in packer(See [here](https://github.com/alohaia/nvimcfg)):

```lua
['alohaia/fcitx.nvim'] = {
    -- ft = 'rmd,markdown,text',
    config = function ()
        require 'fcitx' {
            -- options
        }
    end
}
```

## Options

default options:

```lua
enable = {
    insert = true,
    cmdline = true,
    cmdtext = true,
    terminal = true,
    select = true,
},
guess_initial_status = true
```

> It's not a good idea to enable `cmdline`, because it's used everywhere implicitly.

- `enable`: Fcitx status of each enabled modes is stored separately, others' status is stored together.
- `guess_initial_status`: Whether to get **initial status** of one mode from related modes whose status is initialized.
    - `true`(default): enable with default settings
    - `false`: disable
    - A dictionary: detailed configs of guessing strategy

The default guessing strategy:

```lua
{
    insert = {'select', 'cmdtext'},
    cmdline = {'others'},
    cmdtext = {'insert', 'select'},
    terminal = {'cmdline', 'others'},
    select = {'insert', 'cmdtext'},
    others = {}
}
```

This means, for example, the plugins will guess `insert`'s initial status from `select` or `replace` group.
If the status of any of `select` and `replace` group is stored before, it will be used as `insert`'s initial status.

For instance, you don't want guess `insert`'s initial status, thus you can set `guess_initial_status` like this:

```lua
guess_initial_status = {
    insert = {}
    -- ...
}
```

## Alternative

- [h-hg/fcitx.nvim](https://github.com/h-hg/fcitx.nvim)
- [fcitx.vim](https://github.com/lilydjwg/fcitx.vim)
- [vim-barbaric](https://github.com/rlue/vim-barbaric)

