--!strict
-- The text of a file of a pane's rows: their logical lines, a row that
-- soft-wraps joined with the next, as an editor shows them, within the
-- bytes that a temporary file holds, and the line of a row in it.

local text = {}

-- The most bytes of a temporary file, as Lokyr bounds it.
text.MOST_BYTES = 8 * 1024 * 1024

-- A file's text, the line that it opens at, from 1, and the lines that
-- were left out at its start, as it held too many bytes.
export type File = {
    text: string,
    line: number,
    dropped: number,
}

-- The logical lines of `rows`, oldest first, a row that soft-wraps joined
-- with the next, the empty lines that end them left out; and the line,
-- from 1, of the row numbered `row`, or the first line of none.
function text.lines(rows: { Line }, row: number): ({ string }, number)
    local lines: { string } = {}
    local parts: { string } = {}
    local found = 1
    for _, read in rows do
        if read.row == row then
            found = #lines + 1
        end
        table.insert(parts, read.text)
        if not read.wrapped then
            table.insert(lines, table.concat(parts))
            table.clear(parts)
        end
    end
    if #parts > 0 then
        table.insert(lines, table.concat(parts))
    end
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end
    return lines, math.clamp(found, 1, math.max(#lines, 1))
end

-- The file of `lines`, opened at `line`, within `most` bytes: of its last
-- lines alone where they all hold more, the first left out, and the line
-- moved with them, the file's first at least.
function text.file(lines: { string }, line: number, most: number): File
    local bytes = 0
    for _, each in lines do
        bytes += #each + 1
    end
    local first = 1
    while bytes > most and first <= #lines do
        bytes -= #lines[first] + 1
        first += 1
    end
    local kept = table.move(lines, first, #lines, 1, {})
    local body = table.concat(kept, "\n")
    return {
        text = if #kept > 0 then body .. "\n" else "",
        line = math.max(line - (first - 1), 1),
        dropped = first - 1,
    }
end

-- The rows of `command`'s output, the first row's number and how many: from
-- its output's mark to its end's row, or the row before where its end is at
-- the row's first column; none of a command whose output or end its shell
-- did not mark.
function text.output(command: ShellCommand): (number?, number)
    local output, finished = command.output, command["end"]
    if output == nil or finished == nil then
        return nil, 0
    end
    local first = output[2]
    local last = finished[2] - (if finished[1] == 0 then 1 else 0)
    return first, last - first + 1
end

return text
