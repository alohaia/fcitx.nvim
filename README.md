<h1 align="center">Fcitx.nvim</h1>

A NeoVim plugin for storing and restoring fcitx status of several mode groups separately.

This plugin stores fcitx status while leaving a <ins>mode group</ins> and restore a mode group's
fcitx group while entering this group. All disabled mode groups and other modes share one status.

**Mode group**: See `:h mode()`. For example, `insert` mode group includes `i`, `ic` and `ix`.

## Installation

For [packer](https://github.com/wbthomason/packer.nvim) user:

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
    select = true,
    replace = true
},
guess_initial_status = true
```

- `enable`: Fcitx status of each enabled modes is stored separately, others' status is stored together.
- `guess_initial_status`: Whether to get **initial status** of one mode from related modes whose status is initialized.
    - `true`(default): enable with default settings
    - `false`: disable
    - A dictionary: detailed configs of guessing strategy

The default guessing strategy:

```lua
{
    insert = {'select', 'replace'},
    cmdline = {'others'},
    select = {'insert', 'replace'},
    replace = {'insert', 'select'},
    others = {}
}
```

This means, for example, the plugins will guess `insert`'s initial status from `select` or `replace` group.
If the status of any of `select` and `replace` group is stored before, it will be used as `insert`'s initial status.

For instance, you don't want guess `insert`'s initial status, thus you can set `guess_initial_status` like this:

```lua
guess_initial_status = {
    insert = {}
}
```

## Alternative

- [h-hg/fcitx.nvim](https://github.com/h-hg/fcitx.nvim)
- [fcitx.vim](https://github.com/lilydjwg/fcitx.vim)
- [vim-barbaric](https://github.com/rlue/vim-barbaric)

