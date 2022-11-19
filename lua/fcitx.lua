-- check fcitx-remote / fcitx5-remote
local fcitx_remote = vim.fn.exepath("fcitx5-remote") ~= ""
    and vim.fn.exepath("fcitx5-remote") or vim.fn.exepath("fcitx-remote")

if fcitx_remote == "" then
    vim.notify_once("[fcitx.nvim] Executable file fcitx5-remote or fcitx-remote not found.", vim.log.levels.WARN)
    return
elseif vim.fn.exists("$DISPLAY") == 0 and vim.fn.exists("$WAYLAND_DISPLAY") == 0 then
    return
end

local status = {}
local settings = nil

-- execute a command and return its output
local function exec(cmd, ...)
    local handle = io.popen(table.concat({cmd, ...}, " "))
    if handle then
        local result = handle:read("*a")
        handle:close()
        return result
    else
        return nil
    end
end

-- get_status, set_status:
--  get/set fcitx status(1 for inactive and 2 for active)
--  don't change the status table
local function get_status()
    return tonumber(exec(fcitx_remote))
end
local function set_status(to_status)
    if to_status == 1 then
        exec(fcitx_remote, "-c")
    elseif to_status == 2 then
        exec(fcitx_remote, "-o")
    end
end

-- guess initial status
-- return nil if settings.guess_initial_status is nil or false
local function guess_status(mode, s)
    if not s.guess_initial_status then
        return nil
    end

    local strategy = {
        insert = {'select', 'cmdtext'},
        cmdline = {'others'},
        cmdtext = {'insert', 'select'},
        terminal = {'cmdline', 'others'},
        select = {'insert', 'cmdtext'},
        others = {}
    }
    if type(s.guess_initial_status) == "table" then
        strategy = vim.tbl_extend("keep", s.guess_initial_status, strategy)
    end

    for _,m in pairs(strategy[mode]) do
        if status[m] then
            return status[m]
        end
    end
    return nil
end

local function modeChange(behaviour, mode)
    local old_mode
    local new_mode
    if behaviour == "leave" then
        old_mode = mode
        new_mode = "others"
    elseif behaviour == "enter" then
        old_mode = "others"
        new_mode = mode
    end

    status[old_mode] = get_status()

    if status[new_mode] then
        set_status(status[new_mode])
    elseif settings.guess_initial_status then
        local guess_result = guess_status(new_mode, settings)
        if guess_result then
            set_status(guess_result)
        end
    end
end

return function (_settings)
    -- default settings
    settings = vim.tbl_deep_extend("keep", _settings, {
        enable = {
            insert = true,
            cmdline = false,
            cmdtext = true,
            terminal = true,
            select = true,
        },
        guess_initial_status = true,
    })
    local fcitx_au_id = vim.api.nvim_create_augroup("fcitx", {clear=true})
    if settings.enable.insert then
        vim.api.nvim_create_autocmd("InsertEnter", {
            group = fcitx_au_id,
            pattern = "*",
            callback = function () modeChange("enter", "insert") end
        })
        vim.api.nvim_create_autocmd("InsertLeave", {
            group = fcitx_au_id,
            pattern = "*",
            callback = function () modeChange("leave", "insert") end
        })
    end
    if settings.enable.cmdline then
        vim.api.nvim_create_autocmd("CmdlineEnter", {
            group = fcitx_au_id,
            pattern = "[:>=@]",
            callback = function () modeChange("enter", "cmdline") end
        })
        vim.api.nvim_create_autocmd("CmdlineLeave", {
            group = fcitx_au_id,
            pattern = "[:>=@]",
            callback = function () modeChange("leave", "cmdline") end
        })
    end
    if settings.enable.cmdtext then
        vim.api.nvim_create_autocmd("CmdlineEnter", {
            group = fcitx_au_id,
            pattern = "[/\\?-]",
            callback = function () modeChange("enter", "cmdtext") end
        })
        vim.api.nvim_create_autocmd("CmdlineLeave", {
            group = fcitx_au_id,
            pattern = "[/\\?-]",
            callback = function () modeChange("leave", "cmdtext") end
        })
    end
    if settings.enable.terminal then
        vim.api.nvim_create_autocmd("TermEnter", {
            group = fcitx_au_id,
            pattern = "*",
            callback = function () modeChange("enter", "terminal") end
        })
        vim.api.nvim_create_autocmd("TermLeave", {
            group = fcitx_au_id,
            pattern = "*",
            callback = function () modeChange("leave", "terminal") end
        })
    end
    if settings.enable.select then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = {"*:s", "*:S", "*:\19"},
            callback = function () modeChange("enter", "select") end
        })
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = {"s:*", "S:*", "\19:*"},
            callback = function () modeChange("leave", "select") end
        })
    end
end
