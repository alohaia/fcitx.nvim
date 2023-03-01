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
local cmd_type_map = {
    [':'] = 'cmdline', ['>'] = 'cmdline', ['='] = 'cmdline',
    ['/'] = 'cmdtext', ['?'] = 'cmdtext', ['@'] = 'cmdtext', ['-'] = 'cmdtext',
}
-- default settings
local settings = {
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
}

-- execute a command and return its output
local function exec(cmd, ...)
    return vim.fn.trim(vim.fn.system(vim.fn.join({cmd, ...}, ' ')))
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
local function guess_status(mode)
    local strategy
    -- settings.guess_initial_status must be a table
    if not settings.guess_initial_status then
        return nil
    else
        strategy = settings.guess_initial_status
    end

    for _,m in pairs(strategy[mode]) do
        if status[m] then
            return status[m]
        end
    end
    return nil
end

local function log(lines)
    if settings.log == "quickfix" then
        vim.fn.setqflist({}, 'a', {title = "Fcitx.nvim Log", lines = lines})
    end
end

local function which_group(m)
    if m == 'i' then
        return 'insert'
    elseif m == 'n' then
        return 'normal'
    end
end

local last_cmd_type = ""
local prepare_load = nil
local preparing = ""
local last_mode = nil
local function modeChange(behaviour, mode, event)
    if mode == "cmd" then
        if behaviour == "enter" then
            mode = cmd_type_map[vim.fn.getcmdtype()]
            last_cmd_type = mode
        elseif behaviour == "leave" then
            -- getcmdtype() returns empty string when leaving cmd mode
            mode = last_cmd_type
        end
    end
    if not settings.enable[mode] then
        return
    end

    if behaviour == "leave" then       -- store status for old mode
        -- if the mode we last entered is not the mode we left from this time
        if last_mode and (last_mode ~= event.old_mode) then
            log({"virtual: " .. last_mode .. '->' .. event.old_mode})
            local ev = {old_mode = last_mode, new_mode = event.old_mode}
            modeChange("leave", which_group(last_mode), ev)
            modeChange("enter", which_group(event.old_mode), ev)
        end

        if prepare_load then
            prepare_load:stop()
            log({preparing, "[c]" .. event.old_mode .. "->" .. event.new_mode .. "\t" .. behaviour .. ' ' .. mode .. ", this and ↑ canceled"})
            prepare_load = nil
            goto skip_save
        end

        status[mode] = get_status()
        log({event.old_mode .. "->" .. event.new_mode .. "\t" .. behaviour .. ' ' .. mode .. ", store status " .. status[mode]})

        ::skip_save::

        last_mode = event.new_mode
    elseif behaviour == "enter" then   -- set status for new mode
        preparing = "[p]".. event.old_mode .. "->" .. event.new_mode .. "\t" .. behaviour .. ' ' .. mode .. ', set status ' .. (status[mode] and status[mode] or "<guessing>")
        prepare_load = vim.loop.new_timer()
        prepare_load:start(settings.threshold, 0, vim.schedule_wrap(function()
            if status[mode] then
                set_status(status[mode])
                log({event.old_mode .. "->" .. event.new_mode .. "\t" .. behaviour .. ' ' .. mode .. ', set status ' .. status[mode]})
            elseif settings.guess_initial_status then
                local guess_result = guess_status(mode)
                if guess_result then
                    set_status(guess_result)
                    log({event.old_mode .. "->" .. event.new_mode .. "\t" .. behaviour .. ' ' .. mode .. ', guess status ' .. guess_result})
                else
                    log({event.old_mode .. "->" .. event.new_mode .. "\t" .. behaviour .. ' ' .. mode .. ', status not found'})
                end
            end

            prepare_load = nil
        end))
    end
end

return function (_settings)
    -- update settings
    if type(_settings.guess_initial_status) == "boolean" then
        _settings.guess_initial_status = _settings.guess_initial_status and nil or {}
    end
    settings = vim.tbl_deep_extend("force", settings, _settings)

    -- set up auto commands
    local fcitx_au_id = vim.api.nvim_create_augroup("fcitx", {clear=true})
    -- leave events
    if settings.enable.normal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[nvV\22]*:*",
            callback = function () modeChange("leave", "normal", vim.v.event) end
        })
    end
    if settings.enable.insert then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "i*:*",
            callback = function () modeChange("leave", "insert", vim.v.event) end
        })
    end
    if settings.enable.cmdline or settings.enable.cmdtext then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "c*:*",
            callback = function () modeChange("leave", "cmd", vim.v.event) end
        })
    end
    if settings.enable.terminal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[t!]:*",
            callback = function () modeChange("leave", "terminal", vim.v.event) end
        })
    end
    if settings.enable.select then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[sS\19]:*",
            callback = function () modeChange("leave", "select", vim.v.event) end
        })
    end
    -- enter events
    if settings.enable.normal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "*:[nvV\22]*",
            callback = function () modeChange("enter", "normal", vim.v.event) end
        })
    end
    if settings.enable.insert then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "*:i*",
            callback = function () modeChange("enter", "insert", vim.v.event) end
        })
    end
    if settings.enable.cmdline or settings.enable.cmdtext then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "*:c*",
            callback = function () modeChange("enter", "cmd", vim.v.event) end
        })
    end
    if settings.enable.terminal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "*:[t!]",
            callback = function () modeChange("enter", "terminal", vim.v.event) end
        })
    end
    if settings.enable.select then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "*:[sS\19]",
            callback = function () modeChange("enter", "select", vim.v.event) end
        })
    end
end
