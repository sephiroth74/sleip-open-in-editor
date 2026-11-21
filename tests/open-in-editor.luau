--!strict
-- The plugin's tests, which `sleip test` runs on a host of the tests: each
-- function of the table a test, of a host of its own, which fails at its
-- first error, as `assert` raises it.

local text = require("../src/text")

local test = {}

-- The folder of the test host's temporary files, the plugin's within it.
local FOLDER = "/tmp/lokyr-temporary/open-in-editor/"

-- A row of `text`, of no style.
local function row(content: string): CellRow
    return { text = content, runs = {} }
end

-- A line of a read of the row numbered `at`, of `content`, soft-wrapping
-- into the next where `wrapped`.
local function line(at: number, content: string, wrapped: boolean?): Line
    return { row = at, text = content, wrapped = wrapped == true }
end

-- The file and the line that the plugin's last opening in the editor gave,
-- of the writes that its calls made.
local function opened(host: TestHost): (string?, number?)
    local found: { [string]: any }? = nil
    for _, write in host.done() do
        if write.open_at ~= nil then
            found = write.open_at
        end
    end
    if found == nil then
        return nil, nil
    end
    return found.target, found.line
end

-- A screen of a command's block, its prompt, its output of two rows and the
-- next prompt, and the command, as the shell marks it.
local function block(host: TestHost)
    host.set_screen({ row("$ ls"), row("a.txt"), row("b.txt"), row("$") })
    host.set_commands({
        { id = 1, prompt = { 0, 0 }, output = { 0, 1 }, ["end"] = { 0, 3 }, status = 0 },
    })
end

function test.the_commands_register_and_the_output_s_applies_of_a_command(host: TestHost)
    host.activate()
    local names = host.commands()
    assert(table.find(names, "open-in-editor.scrollback") ~= nil)
    assert(table.find(names, "open-in-editor.output") ~= nil)
    assert(host.applies("open-in-editor.scrollback"))
    assert(not host.applies("open-in-editor.output"), "no command, no output")
    block(host)
    assert(host.applies("open-in-editor.output"))
end

function test.the_scrollback_opens_in_the_editor_at_the_view_s_first_line(host: TestHost)
    host.activate()
    host.set_screen({ row("$ ls -l"), row("total 0"), row("$") })
    host.command("open-in-editor.scrollback")
    host.events({})
    assert(host.temporary_file("scrollback.txt") == "$ ls -l\ntotal 0\n$\n", host.temporary_file("scrollback.txt"))
    local target, at = opened(host)
    assert(target == FOLDER .. "scrollback.txt", target)
    assert(at == 1, `the line {at}`)
end

function test.a_command_s_output_opens_alone_of_the_last_command_or_its_cell(host: TestHost)
    host.activate()
    block(host)
    host.command("open-in-editor.output")
    host.events({})
    assert(host.temporary_file("output.txt") == "a.txt\nb.txt\n", host.temporary_file("output.txt"))
    local target, at = opened(host)
    assert(target == FOLDER .. "output.txt" and at == 1)
    -- Of a cell of its output, as the pane's context menu gives it.
    local cell: Args = { column = 0, row = 2 }
    host.command("open-in-editor.output", cell)
    host.events({})
    assert(opened(host) == FOLDER .. "output.txt")
end

-- The text of the last notice that the plugin showed.
local function last_notice(host: TestHost): string?
    local notices = host.notices()
    return if #notices > 0 then notices[#notices].text else nil
end

function test.an_opening_of_nothing_tells_why_in_a_notice(host: TestHost)
    host.activate()
    host.command("open-in-editor.output")
    assert(last_notice(host) == "No command that ended is here", last_notice(host))
    -- A notice a second, as Lokyr shows them.
    host.advance(1000)
    host.command("open-in-editor.scrollback")
    host.events({})
    assert(last_notice(host) == "There is no text to open", last_notice(host))
    assert(opened(host) == nil, "nothing opened")
end

function test.rows_that_wrap_join_as_one_line_and_the_empty_ones_that_end_go()
    local lines, at = text.lines({
        line(10, "a long line that ", true),
        line(11, "wraps", false),
        line(12, "next", false),
        line(13, "", false),
        line(14, "", false),
    }, 12)
    assert(#lines == 2, `{#lines} lines`)
    assert(lines[1] == "a long line that wraps" and lines[2] == "next")
    assert(at == 2, `the line {at}`)
    -- A row past the lines, or one that is not there, takes the first.
    local _, first = text.lines({ line(0, "x") }, 99)
    assert(first == 1)
end

function test.a_file_past_its_bytes_keeps_its_last_lines_and_moves_its_line()
    local file = text.file({ "aaa", "bbb", "ccc" }, 3, 8)
    assert(file.text == "bbb\nccc\n", file.text)
    assert(file.dropped == 1 and file.line == 2)
    -- Within its bytes, whole; the line of a dropped row the first.
    local whole = text.file({ "aaa", "bbb" }, 1, 100)
    assert(whole.text == "aaa\nbbb\n" and whole.dropped == 0 and whole.line == 1)
    local cut = text.file({ "aaa", "bbb", "ccc" }, 1, 4)
    assert(cut.text == "ccc\n" and cut.line == 1)
end

function test.an_output_s_rows_run_from_its_mark_to_its_end()
    local first, count = text.output({ id = 1, output = { 0, 5 }, ["end"] = { 0, 9 } } :: any, 0)
    assert(first == 5 and count == 4)
    -- An end past its row's first column holds that row.
    first, count = text.output({ id = 1, output = { 0, 5 }, ["end"] = { 3, 9 } } :: any, 0)
    assert(first == 5 and count == 5)
    first = text.output({ id = 1 } :: any, 0)
    assert(first == nil)
    -- Of its marks before its end gone with the scrollback's oldest rows,
    -- from the oldest row; of a prompt but no output's mark, none.
    first, count = text.output({ id = 1, ["end"] = { 0, 9 } } :: any, 2)
    assert(first == 2 and count == 7, `{first} {count}`)
    first = text.output({ id = 1, prompt = { 0, 4 }, ["end"] = { 0, 9 } } :: any, 2)
    assert(first == nil)
end

function test.a_long_output_whose_mark_left_the_scrollback_opens_from_its_oldest_row(host: TestHost)
    host.activate()
    host.set_screen({ row("line 19998"), row("line 19999"), row("line 20000"), row("$") })
    host.set_commands({ { id = 1, ["end"] = { 0, 3 }, status = 0 } })
    assert(host.applies("open-in-editor.output"))
    host.command("open-in-editor.output")
    host.events({})
    local written = host.temporary_file("output.txt")
    assert(written == "line 19998\nline 19999\nline 20000\n", written)
end

function test.a_read_cut_short_opens_nothing_and_tells_why(host: TestHost)
    host.activate()
    host.set_screen({ row("$ ls -l"), row("total 0"), row("$") })
    host.command("open-in-editor.scrollback")
    host.cut_reads()
    host.events({})
    assert(opened(host) == nil, "nothing opened")
    assert(host.temporary_file("scrollback.txt") == nil)
    local text = last_notice(host)
    assert(text == "The pane changed while its rows were read: nothing opened", text)
end

return test
