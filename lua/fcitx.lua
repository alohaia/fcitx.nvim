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
local function exec(cmd)
    local output = io.popen(cmd, "r")
    assert(output, string.format("failed"))
    local rv = output:read()
    output:close()
    return rv
end

-- get_status, set_status:
--  get/set fcitx status(1 for inactive and 2 for active)
--  don't change the status table
local function get_status()
    return tonumber(exec(fcitx_remote))
end
local function set_status(to_status)
    if to_status == 1 then
        exec(fcitx_remote .. " -c")
    elseif to_status == 2 then
        exec(fcitx_remote .. " -o")
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

local tmp_file_name
local tmp_file
local function log(mes, ...)
    if settings == true or settings.log == "quickfix" then
       vim.fn.setqflist({}, 'a', {title = "Fcitx.nvim Log", lines = {string.format(mes, ...)}})
    elseif settings.log == "tmpfile" then
       tmp_file:write(string.format(mes, ...) .. "\n")
       tmp_file:flush()
    end
end

local mode_mapping = setmetatable({
        __last_cmd_mode__ = "cmdline",
        ["c"] = "cmdline",
        ["n"] = "normal",
        ["v"] = "normal", ["V"] = "normal", ["\22"] = "normal",
        ["i"] = "insert",
        ["s"] = "select", ["S"] = "select", ["\19"] = "select",
        ["t"] = "terminal", ["!"] = "terminal",
    }, {
        __index = function(origin_table, key)
            if key == "c" then
                local cmd_mode = cmd_type_map[vim.fn.getcmdtype()]
                if cmd_mode then
                    origin_table.__last_cmd_mode__ = cmd_mode
                    return cmd_mode
                else
                    return origin_table.__last_cmd_mode__
                end
            else
                return origin_table[string.sub(key, 1, 1)]
            end
        end
    }
)
local prepare_load = nil
local preparing = {}
local last_mode = nil
local function modeChange(behaviour, mode, event)
    if not settings.enable[mode] then
        return
    end

    if behaviour == "leave" then       -- store status for old mode
        -- if the mode we last entered is not the mode we left from this time
        if last_mode and (mode_mapping[last_mode.raw] ~= mode_mapping[event.old_mode]) then
            log("virtual: %s -> %s", last_mode.raw, event.old_mode)
            local ev = {old_mode = last_mode.raw, new_mode = event.old_mode}
            modeChange("leave", last_mode.name, ev)
            modeChange("enter", mode_mapping[event.old_mode], ev)
        end

        if prepare_load then
            prepare_load:stop()
            log(unpack(preparing))
            log("[c] %s -> %s\t%s %s, this and ↑ canceled", event.old_mode, event.new_mode, behaviour, mode)
            prepare_load = nil
            goto skip_save
        end

        status[mode] = get_status()
        log("%s -> %s\t%s %s, , store status %d", event.old_mode, event.new_mode, behaviour, mode, status[mode])

        ::skip_save::

        -- the mode last entered
        last_mode = {raw = event.new_mode, name = mode_mapping[event.new_mode]}
    elseif behaviour == "enter" then   -- set status for new mode
        preparing = {"[p] %s -> %s\t%s %s, set status %d", event.old_mode, event.new_mode, behaviour, mode, (status[mode] and status[mode] or "<guessing>")}
        prepare_load = vim.defer_fn(function()
            if status[mode] then
                set_status(status[mode])
                log("%s -> %s\t%s %s, set status %d", event.old_mode, event.new_mode, behaviour, mode, status[mode])
            elseif settings.guess_initial_status then
                local guess_result = guess_status(mode)
                if guess_result then
                    set_status(guess_result)
                    log("%s -> %s\t%s %s, guess status, %d", event.old_mode, event.new_mode, behaviour, mode, guess_result)
                else
                    log("%s -> %s\t%s %s, can not guess stauts", event.old_mode, event.new_mode, behaviour, mode)
                end
            end

            prepare_load = nil
        end, settings.threshold)
    end
end

local last_cmd_type = "cmdline"  -- default as "cmdline"
return function (_settings)
    -- update settings
    if type(_settings.guess_initial_status) == "boolean" then
        _settings.guess_initial_status = _settings.guess_initial_status and nil or {}
    end
    settings = vim.tbl_deep_extend("force", settings, _settings)

    -- prepare log file
    if settings.log == "tmpfile" then
        tmp_file_name = os.tmpname()
        tmp_file = io.open(tmp_file_name, "a")
        assert(tmp_file, "failed to open tmpfile " .. tmp_file_name)
        print("tmpfile name: " .. tmp_file_name)
    end

    -- set up auto commands
    local fcitx_au_id = vim.api.nvim_create_augroup("fcitx", {clear=true})
    -- leave events
    if settings.enable.normal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[nvV\22]*:[^nvV\22]*",
            callback = function () modeChange("leave", "normal", vim.v.event) end
        })
    end
    if settings.enable.insert then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "i*:[^i]*",
            callback = function () modeChange("leave", "insert", vim.v.event) end
        })
    end
    if settings.enable.cmdline or settings.enable.cmdtext then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "c*:[^c]*",
            callback = function ()
                modeChange("leave", last_cmd_type, vim.deepcopy(vim.v.event))
            end
        })
    end
    if settings.enable.terminal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[t!]:[^t!]*",
            callback = function () modeChange("leave", "terminal", vim.v.event) end
        })
    end
    if settings.enable.select then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[sS\19]:[^sS\19]",
            callback = function () modeChange("leave", "select", vim.v.event) end
        })
    end
    -- enter events
    if settings.enable.normal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[^nvV\22]*:[nvV\22]*",
            callback = function () modeChange("enter", "normal", vim.v.event) end
        })
    end
    if settings.enable.insert then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[^i]*:i*",
            callback = function () modeChange("enter", "insert", vim.v.event) end
        })
    end
    if settings.enable.cmdline or settings.enable.cmdtext then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[^c]*:c*",
            callback = function ()
                local mode = cmd_type_map[vim.fn.getcmdtype()]
                modeChange("enter", mode, vim.deepcopy(vim.v.event))
                last_cmd_type = mode
            end
        })
    end
    if settings.enable.terminal then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[^t!]*:[t!]",
            callback = function () modeChange("enter", "terminal", vim.v.event) end
        })
    end
    if settings.enable.select then
        vim.api.nvim_create_autocmd("ModeChanged", {
            group = fcitx_au_id,
            pattern = "[^sS\19]:[sS\19]",
            callback = function () modeChange("enter", "select", vim.v.event) end
        })
    end
end
