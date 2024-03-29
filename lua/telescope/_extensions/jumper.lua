local actions = require "telescope.actions"
local actions_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local sorters = require "telescope.sorters"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"

local conf = require("telescope.config").values

local jump_folders = os.getenv("__JUMPER_FOLDERS")
local jump_files = os.getenv("__JUMPER_FILES")
local cmd_folders = vim.tbl_flatten({ "jumper", "-f", jump_folders, "-n", "100"})
local cmd_files = vim.tbl_flatten({ "jumper", "-f", jump_files, "-n", "100"})

local jumper_layout_config = {
    width = 0.9,
    height = 0.9,
    prompt_position = "bottom",
    preview_cutoff = 220,
}
local function jump_to_folder(opts)
    opts = opts or {}
    local cwd = vim.loop.cwd()

    local jumper_finder = finders.new_job(function(prompt)
        return vim.tbl_flatten({ cmd_folders, prompt })
    end, make_entry.gen_from_string(), {}, cwd)

    local ls = previewers.new_termopen_previewer({
        title = "Contents",
        get_command = function(entry)
            return { 'ls', '-1UpC', '--color=always', entry[1] }
        end
    })

    pickers.new(opts, {
        prompt_title = "Search",
        finder = jumper_finder,
        sorter = sorters.highlighter_only(opts),
        previewer = ls,
        layout_config = jumper_layout_config,
        attach_mappings = function(_)
            actions.select_default:replace(function()
                local entry = actions_state.get_selected_entry()
                require("telescope.builtin").find_files { cwd = entry[1], hidden = false }
            end)
            return true
        end,
    }):find()
end

local function jump_to_file(opts)
    opts = opts or {}
    local jumper_finder = finders.new_job(function(prompt)
        return vim.tbl_flatten({ cmd_files, prompt })
    end, make_entry.gen_from_string(), {}, '')
    pickers.new(opts, {
        prompt_title = "Search files",
        finder = jumper_finder,
        previewer = conf.grep_previewer(opts),
        layout_config = jumper_layout_config,
        sorter = sorters.highlighter_only(opts),
    }):find()
end

local function os_capture(command, raw)
    local handle = assert(io.popen(command, 'r'))
    local output = assert(handle:read('*a'))
    handle:close()
    if raw then
        return output
    end
    output = string.gsub(string.gsub(output, '^%s+', ''), '%s+$', '')
    return output
end

local function find_in_files(opts)
    opts = opts or {}
    local jumper_finder = finders.new_job(function(prompt)
        local raw = os_capture("jumper -f ${__JUMPER_FILES} ''", false)
        local file_list = {}
        for value in string.gmatch(raw, "([^" .. '\n' .. "]+)") do
            table.insert(file_list, value)
        end
        return vim.tbl_flatten({ conf.vimgrep_arguments, '--', prompt, file_list })
    end, opts.entry_maker or make_entry.gen_from_vimgrep(opts), {}, '')
    pickers.new(opts, {
        prompt_title = "Live Grep",
        layout_config = jumper_layout_config,
        previewer = conf.grep_previewer(opts),
        finder = jumper_finder,
        sorter = sorters.highlighter_only(opts),
    }):find()
end

return require("telescope").register_extension({
    exports = {
        jump_to_folder = jump_to_folder,
        jump_to_file = jump_to_file,
        find_in_files = find_in_files,
    },
})
