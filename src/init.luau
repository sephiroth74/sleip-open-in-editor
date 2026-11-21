--!strict
-- Open in Editor: a pane's scrollback, or a command's output, in your text
-- editor, as a file of the plugin's own that Lokyr keeps until it quits:
-- the rows read, their logical lines joined, the file written, and the
-- editor opened at the line that the view showed first.

local text = require("./text")

local Plugin: Plugin = {}

-- The rows back from the screen whose commands a look for the last command
-- reads, as a read of every command would take them all.
local RECENT_ROWS = 10000

-- The most rows that a read gives, as Lokyr bounds it.
local MOST_ROWS = 100000

-- The files that the commands write, each opening in place of the last.
local SCROLLBACK_FILE = "scrollback.txt"
local OUTPUT_FILE = "output.txt"

-- A read under way: the file that it writes, the row whose line the editor
-- opens at, and whether the read left rows out at its start.
type Reading = {
    file: string,
    row: number,
    cut: boolean,
}

-- The read under way, by its id: the last command's alone, so that a read
-- of no event is forgotten as the next starts.
local readings: { [number]: Reading } = {}

-- The command that ended of `pane` whose output a command opens: of the
-- cell of `args`' `column` and `row`, as the pane's context menu gives
-- them, or, of none, the last command that ended; none on the alternate
-- screen, which hides the commands' rows.
local function command_of(cx: Cx, pane: PaneId, args: Args): ShellCommand?
    local view = cx.viewport(pane)
    if view == nil or view.alternate then
        return nil
    end
    local column, row = args.column, args.row
    if type(column) == "number" and column >= 0 and type(row) == "number" and row >= 0 then
        local command = cx.command_at(pane, row)
        return if text.ended(command) then command else nil
    end
    local commands = cx.shell_commands(pane, view.screen - RECENT_ROWS, view.screen + view.rows) or {}
    for at = #commands, 1, -1 do
        if text.ended(commands[at]) then
            return commands[at]
        end
    end
    return nil
end

-- Reads `count` rows of `pane` from the row numbered `first`, their last
-- `MOST_ROWS` where they are more, for the file `file`, opened at the line
-- of the row numbered `row`.
local function read(cx: Cx, pane: PaneId, first: number, count: number, file: string, row: number)
    local from = math.max(first, first + count - MOST_ROWS)
    local id = assert(cx.read_lines(pane, from, first + count - from))
    table.clear(readings)
    readings[id] = { file = file, row = row, cut = from > first }
end

function Plugin.activate(cx: Cx)
    assert(cx.register_command({
        name = "open-in-editor.scrollback",
        title = "Open Scrollback in Editor",
        category = "edit",
    }))
    -- A command's output: its cell's, as the context menu gives it, or, of
    -- none, the last command's.
    local column: Param = { name = "column", kind = "integer", default = -1 }
    local row: Param = { name = "row", kind = "integer", default = -1 }
    assert(cx.register_command({
        name = "open-in-editor.output",
        title = "Open Output in Editor",
        category = "edit",
        params = { column, row },
    }))
    assert(cx.add_menu_item({ place = "pane-context", command = "open-in-editor.output" }))
end

function Plugin.applies(cx: Cx, name: string, args: Args): boolean
    local pane = cx.focused_pane()
    if pane == nil then
        return false
    end
    if name == "open-in-editor.output" then
        return command_of(cx, pane, args) ~= nil
    end
    return true
end

function Plugin.on_command(cx: Cx, name: string, args: Args)
    local pane = cx.focused_pane()
    if pane == nil then
        return
    end
    if name == "open-in-editor.output" then
        -- Its item shows in the menus whether or not it applies, as Lokyr
        -- asks a plugin of a thread of its own nothing before its menu
        -- shows: a notice tells why it opens nothing.
        local command = command_of(cx, pane, args)
        local view = cx.viewport(pane)
        local first, count
        if command ~= nil and view ~= nil then
            first, count = text.output(command, view.oldest)
        end
        if first == nil then
            cx.notify(cx.message("open-in-editor-no-command") or "No command that ended is here", "info")
            return
        end
        read(cx, pane, first, count, OUTPUT_FILE, first)
        return
    end
    -- The scrollback and the screen, opened at the view's first row.
    local view = cx.viewport(pane)
    if view == nil then
        return
    end
    local past = view.screen + view.rows
    read(cx, pane, view.oldest, past - view.oldest, SCROLLBACK_FILE, view.top)
end

-- Writes the file of `reading` of `rows` and opens it in the editor.
local function open(cx: Cx, reading: Reading, rows: { Line })
    local lines, line = text.lines(rows, reading.row)
    if #lines == 0 then
        cx.notify(cx.message("open-in-editor-empty") or "There is no text to open", "info")
        return
    end
    local file = text.file(lines, line, text.MOST_BYTES)
    local path, failure = cx.temp_file(reading.file, file.text)
    if path == nil then
        local reason = failure or "?"
        local args: { [string]: Data } = { error = reason }
        cx.notify(cx.message("open-in-editor-not-written", args) or `The file was not written: {reason}`, "error")
        return
    end
    assert(cx.open_at(path, file.line))
    if reading.cut or file.dropped > 0 then
        local kept = #lines - file.dropped
        local args: { [string]: Data } = { lines = kept }
        cx.notify(
            cx.message("open-in-editor-cut", args) or `Only the last {kept} lines open, as the rest did not fit`,
            "info"
        )
    end
end

function Plugin.on_event(cx: Cx, events: { Event })
    for _, event in events do
        if event.kind == "lines" then
            local reading = readings[event.id]
            if reading ~= nil then
                readings[event.id] = nil
                if event.complete then
                    open(cx, reading, event.lines)
                else
                    -- Cut short, as a resize renumbered the rows or the
                    -- pane closed in the middle: nothing opens.
                    local message = cx.message("open-in-editor-changed")
                    cx.notify(message or "The pane changed while its rows were read: nothing opened", "info")
                end
            end
        end
    end
end

return Plugin
