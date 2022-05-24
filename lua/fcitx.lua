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

-- translate output of vim.fn.mode into "insert", "cmdline",
--  "select", "replace" or "others" according to settings
-- modes set to false in settings are regarded as "others"
-- local function translate_mode(md, settings)
--     if md == "i" and settings.enable.insert then
--         return "insert"
--     elseif md == "c" and settings.enable.cmdline then
--         return "cmdline"
--     elseif md == "s" or md == "S" or md == "\19" and settings.enable.select then
--         return "select"
--     elseif md == "R" and settings.enable.replace then
--         return "replace"
--     else
--         return "others"
--     end
-- end

-- guess initial status
-- return nil if settings.guess_initial_status is nil or false
local function guess_status(mode, settings)
    if not settings.guess_initial_status then
        return nil
    end

    local strategy = {
        insert = {'select', 'cmdtext'},
        cmdline = {'others'},
        cmdtext = {'insert', 'select'},
        select = {'insert', 'cmdtext'},
        others = {}
    }
    if type(settings.guess_initial_status) == "table" then
        strategy = vim.tbl_extend("keep", settings.guess_initial_status, strategy)
    end

    for _,m in pairs(strategy[mode]) do
        if status[m] then
            return status[m]
        end
    end
    return nil
end

FCITX_LOG = {}
local function appendlog(str, ...)
    table.insert(FCITX_LOG, string.format(str, ...))
    vim.fn.setqflist({}, 'r', {title = 'Fcitx Log', lines = vim.fn.reverse(FCITX_LOG)})
end

-- local last
-- function modechanged_callback()
--     local old_mode = translate_mode(vim.v.event.old_mode, settings)
--     local new_mode = translate_mode(vim.v.event.new_mode, settings)
--     if new_mode == old_mode then
--         return
--     end
--
--     local now = vim.fn.reltimefloat(vim.fn.reltime())
--     if last and now - last < 0.1 then
--         appendlog("%s(%s)(%1.4f) -> %s(%s), skip", old_mode, vim.v.event.old_mode, (now - last), new_mode, vim.v.event.new_mode)
--         goto afterstore
--     elseif last then
--         appendlog("%s(%s)(%1.4f) -> %s(%s), far enough", old_mode, vim.v.event.old_mode, (now - last), new_mode, vim.v.event.new_mode)
--     else
--         appendlog("%s(%s)(start) -> %s(%s), far enough", old_mode, vim.v.event.old_mode, new_mode, vim.v.event.new_mode)
--     end
--
--     last = vim.fn.reltimefloat(vim.fn.reltime())
-- end

local function modeEnter(mode)
    appendlog("----- Enter %s -----", mode)
    status.others = get_status()
    appendlog("store status %d for mode others", status[mode])

    if status[mode] then
        set_status(status[mode])
        appendlog("set status %d for mode %s", status[mode], mode)
    elseif settings.guess_initial_status then
        local guess_result = guess_status(mode, settings)
        if guess_result then
            set_status(guess_result)
            appendlog("guess and set status %d for mode %s", guess_result, mode)
        end
    end
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

    appendlog("----- %s %s -----", behaviour, mode)
    status[old_mode] = get_status()
    appendlog("store status %d for mode %s", status[old_mode], old_mode)

    if status[new_mode] then
        set_status(status[new_mode])
        appendlog("set status %d for mode %s", status[new_mode], new_mode)
    elseif settings.guess_initial_status then
        local guess_result = guess_status(new_mode, settings)
        if guess_result then
            set_status(guess_result)
            appendlog("guess and set status %d for mode %s", guess_result, new_mode)
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
            select = true,
        },
        guess_initial_status = true,
    })
    local fcitx_au_id = vim.api.nvim_create_augroup("fcitx", {clear=true})
    -- vim.api.nvim_create_autocmd("ModeChanged", {
    --     group = fcitx_au_id,
    --     pattern = "*",
    --     callback = modechanged_callback
    -- })
    if settings.enable.insert then
        appendlog("insert")
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
        appendlog("cmdline")
        vim.api.nvim_create_autocmd("CmdlineEnter", {
            group = fcitx_au_id,
            pattern = "[:>=@]",
            callback = function () modeChange("enter", "cmdline") end
        })
        vim.api.nvim_create_autocmd("CmdlineLeave", {
            group = fcitx_au_id,
            pattern = "[/\\?-]",
            callback = function () modeChange("leave", "cmdline") end
        })
    end
    if settings.enable.cmdtext then
        appendlog("cmdtext")
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
    if settings.enable.select then
        appendlog("select")
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = {"*:s", "*:S", "*:\19"},
            callback = function () modeEnter("select") end
        })
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = {"s:*", "S:*", "\19:*"},
            callback = function () modeLeave("select") end
        })
    end
end
