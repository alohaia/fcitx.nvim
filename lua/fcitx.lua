-- check fcitx-remote (fcitx5-remote)
local fcitx_remote = vim.fn.exepath("fcitx5-remote") ~= ""
    and vim.fn.exepath("fcitx5-remote") or vim.fn.exepath("fcitx-remote")

if fcitx_remote == "" then
    vim.notify_once("[fcitx.nvim] Executable file fcitx5-remote or fcitx-remote not found.", vim.log.levels.WARN)
    return
elseif vim.fn.exists("$DISPLAY") == 0 and vim.fn.exists("$WAYLAND_DISPLAY") == 0 then
    return
end

local status = {}

-- execute a command and return its output
local function exec(cmd)
    local handle = io.popen(cmd)
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
        exec(fcitx_remote .. " -c")
    elseif to_status == 2 then
        exec(fcitx_remote .. " -o")
    end
end

-- translate output of vim.fn.mode into "insert", "cmdline",
--  "select", "replace" or "others" according to settings
-- modes set to false in settings are regarded as "others"
local function translate_mode(md, settings)
    if md:sub(1,1) == "i" and settings.enable.insert then
        return "insert"
    elseif md:sub(1,1) == "c" and settings.enable.cmdline then
        return "cmdline"
    elseif (md == "s" or md == "S" or md == "\19") and settings.enable.select then
        return "select"
    elseif (md:sub(1,1) == "R") and settings.enable.replace then
        return "replace"
    else
        return "others"
    end
end

-- guess initial status
-- return nil if settings.guess_initial_status is nil or false
local function guess_status(mode, settings)
    if not settings.guess_initial_status then
        return nil
    end

    local strategy = {
        insert = {'select', 'replace'},
        cmdline = {'others'},
        select = {'insert', 'replace'},
        replace = {'insert', 'select'},
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

return function (settings)
    -- default settings
    settings = vim.tbl_deep_extend("keep", settings, {
        enable = {
            insert = true,
            cmdline = true,
            select = true,
            replace = true
        },
        guess_initial_status = true
    })
    local fcitx_au_id = vim.api.nvim_create_augroup("fcitx", {clear=true})
    vim.api.nvim_create_autocmd("ModeChanged", {
        group = fcitx_au_id,
        pattern = "*",
        callback = function ()
            local old_mode = translate_mode(vim.v.event.old_mode, settings)
            local new_mode = translate_mode(vim.v.event.new_mode, settings)

            -- store status of old mode
            status[old_mode] = get_status()

            if status[new_mode] then
                -- set status for new mode
                set_status(status[new_mode])
            elseif settings.guess_initial_status then
                local guess_result = guess_status(new_mode, settings)
                if guess_result then
                    set_status(guess_result)
                end
            end
        end,
    })
end
