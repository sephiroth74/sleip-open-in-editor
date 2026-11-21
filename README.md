# open-in-editor

A plugin of [Lokyr](https://lokyr.dev): a pane's scrollback, or a command's
output, in your text editor, to search it, copy part of it or keep it, its
long lines whole rather than cut at the window's width.

## Use

- **Open Scrollback in Editor** (`open-in-editor.scrollback`), from the
  command palette (⇧⌘P) or keys of your own: everything that the pane
  holds, its scrollback and its screen, opens in your editor at the line
  that the window showed at its top.
- **Open Output in Editor** (`open-in-editor.output`), from the pane's
  context menu where a command's output is, or from the palette for the
  last command that ended: that command's output alone, as your shell
  marks it, of the shell integration.
- The editor is the one that `[links] editor` names in Lokyr's config,
  such as `"vscode"` or `"zed"`; without one, the app that opens text files.
- Each opening writes its file anew, `scrollback.txt` or `output.txt`, in a
  folder of the plugin's own that Lokyr empties as it quits: an editor that
  shows the file already shows the new text.
- A row that wraps at the window's edge joins the next, so that a line of
  the program's opens as one line.
- A text of more than 8 MB, or of more than 100,000 rows, opens its last
  lines, and a notice tells how many.
- Lokyr shows the commands' items in its menus whether or not they apply:
  of no command that ended at the cell, a notice says why nothing opened.

## Install

Of Lokyr 1.4 or later, of the plugin API 0.1.6:

```sh
sleip add sephiroth74/open-in-editor
```

## Capabilities

- `terminal-read`, for the texts of the pane's rows.
- `history-read`, for the commands that your shell marked, whose output
  Open Output in Editor takes.
- `open`, to open the file in your editor at its line.

The file is a temporary one of the plugin's own, which needs no
capability: Lokyr marks it as downloaded, so that macOS asks before it
opens as a program.

## How it works

An example for plugin authors, in two files:

- [`src/init.luau`](src/init.luau) registers the commands and the context
  menu's item, reads the rows with `cx.read_lines`, whose lines come as a
  `lines` event, writes them with `cx.temp_file` and opens the file with
  `cx.open_at`.
- [`src/text.luau`](src/text.luau) joins the rows that wrap into lines,
  finds the line of the view's first row, and keeps a file within its
  bytes.

## Develop

`sleip check` checks the plugin, `sleip test` runs its tests, and
`sleip dev` links it into Lokyr, which reloads it at each save.

## License

MIT, see [LICENSE](LICENSE).
