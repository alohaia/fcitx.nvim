<h1 align="center">Fcitx.nvim</h1>

A Neovim plugin for storing and restoring fcitx status of several mode groups separately.

This plugin stores fcitx status while leaving a <ins>mode group</ins> and restores a mode group's fcitx status while entering this group. All disabled mode groups and other modes share one status.

> P.S. This plugin uses timer of `vim.loop` to make some delay, in order to avoid too frequent switching.

**Mode group**(see `:h mode()` and `:h ModeChanged`):

- `normal`: `[nvV^V]*`
- `insert`: `i*`
- `cmdline` and `cmdtext`: `c*`
    - `cmdline`: See `:h getcmdtype()`, `:`, `>` and `=`
    - `cmdtext`: See `:h getcmdtype()`, `/`, `?`, `-` , and `@`
- `terminal`: `[t!]`
- `select`: `[sS^S]`

## Installation

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

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

With my built-in packer(See [here](https://github.com/alohaia/nvimcfg)):

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

Default options:

```lua
enable = {
    normal   = true,
    insert   = true,
    cmdline  = true,
    cmdtext  = true,
    terminal = true,
    select   = true,
},
guess_initial_status = {
    normal   = {},
    insert   = {'select', 'cmdtext'},
    cmdline  = {'normal'},
    cmdtext  = {'cmdline', 'insert'},
    terminal = {'cmdline', 'normal'},
    select   = {'insert', 'cmdtext'},
},
threshold = 30,
log = false,
```

- `enable`(`table`): Fcitx status of each enabled modes is stored separately, others' status is stored together.
- `guess_initial_status`(`boolean` or `table`): Whether to get **initial status** of one mode from related modes whose status is initialized.
    - `true`: enable with default settings
    - `false`: disable
    - A dictionary: detailed configs of guessing strategy
- `threshold`(`number`): If the time from one input method switching to another is short than `threshold`(in milliseconds), the latter will be skipped. Just leave this as the default if there is no issue.
- `log`(`false` or `"quickfix"`): Whether and where to show log. When set this to `quickfix`, use `copen` to open quickfix window.

The guessing strategy means, for example, the plugins will guess `insert`'s initial status from `select` or `cmdtext` group. If the status of any of `select` and `cmdtext` groups is stored before, it will be used as `insert`'s initial status.

For instance, you don't want guess `insert`'s initial status, thus you can set `guess_initial_status` like this:

```lua
guess_initial_status = {
    insert = {}
}
```

It's the same as


```lua
guess_initial_status = {
    normal   = {},
    insert   = {},
    cmdline  = {'normal'},
    cmdtext  = {'insert', 'select'},
    terminal = {'cmdline', 'normal'},
    select   = {'insert', 'cmdtext'},
}
```

## Alternative

- [h-hg/fcitx.nvim](https://github.com/h-hg/fcitx.nvim)
- [fcitx.vim](https://github.com/lilydjwg/fcitx.vim)
- [vim-barbaric](https://github.com/rlue/vim-barbaric)

