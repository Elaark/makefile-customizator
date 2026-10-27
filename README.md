# Makefile Casino

Turn every `make` into a game of chance.

`casino.sh` adds a pixel-art arcade animation to an existing Makefile. While
your project compiles, the animation plays at the bottom of the terminal; when
the build ends, it shows the result: a jackpot if it compiled, a loss if it
didn't. `make clean` and `make fclean` get their own ending too.

Nothing about the build itself changes: same targets, same compiler output,
same exit code.

## Quick start

```sh
git clone <this repo> ~/makefile-casino
cd your/project
~/makefile-casino/casino.sh
```

The generator is interactive (arrow keys or `j`/`k`, Enter to pick). It asks:

1. **which Makefile** to use,
2. **which animation** and **which theme**, with a live preview of a
   successful build, a failed build and a clean,
3. **how to show the build logs**,
4. **how to add it**: rewrite the Makefile, or add a `GNUmakefile` next to it,
5. **where the animation code lives**: inside the Makefile, or a separate
   script.

Nothing is written before the final summary, and a backup is always kept.

Want to try it first? `examples/demo` is a tiny C project with a plain
Makefile:

```sh
cd ~/makefile-casino/examples/demo
../../casino.sh
make
```

## Animations

| Animation        | Success                              | Failure                        | Clean                          |
| ---------------- | ------------------------------------ | ------------------------------ | ------------------------------ |
| Slot machine     | 7 7 7, `★ JACKPOT ★`                 | a losing combo, `GAME OVER`    | reels spin back to empty       |
| Roulette         | the ball lands on red                | the ball lands on the green 0  | the pockets empty out          |
| Russian roulette | empty chamber, `*click*  SURVIVED`   | the bullet, `BANG!`            | the bullet drops out           |
| Dice             | double six                           | snake eyes                     | blank faces                    |
| Claw machine     | the prize drops into the chute       | the prize slips on the way up  | the pile empties               |
| RPG quest        | the knight slays the slime           | the slime crushes the knight   | the slime melts away           |

In the RPG, the knight strikes each time the build prints new lines.

## Themes

`purple`, `classic` (red and gold), `neon` (cyan and magenta on a dark
cabinet), `mono` (greys) and `matrix` (green on black). Themes color the
cabinet, the lights and the titles; the symbols keep their own colors.

## Build logs

| Mode      | What you see                                              |
| --------- | --------------------------------------------------------- |
| Scrolling | the full logs scroll above the animation, as usual        |
| One line  | only the latest log line, under the animation             |
| Hidden    | no logs at all, but they are printed if the build fails   |

The mode chosen in the generator is the default; `CASINO_LOGS` overrides it.

## Integration

**Rewrite the Makefile.** `all`, `clean` and `fclean` become `_all`, `_clean`
and `_fclean`, and new public rules run them through the animation:

```make
all:
	@bash casino.sh $(MAKE) --no-print-directory _all

_all: $(NAME)          # your original "all" rule
```

The original file is saved as `Makefile.casino.bak`. To undo:
`mv Makefile.casino.bak Makefile`.

**Add a GNUmakefile.** GNU make reads `GNUmakefile` before `Makefile`, so a
generated `GNUmakefile` wraps `all`, `clean`, `fclean` and `re` in the
animation and forwards every other target to your Makefile, which is never
touched. To undo: delete `GNUmakefile`. Use the rewrite instead if your
project must contain a single Makefile.

### Where the code lives

- **Inside the Makefile** (or GNUmakefile): one self-contained file. The
  script is stored in a `define` block and kept unexpanded with `$(value ...)`,
  so it is plain bash with no `$$` doubling.
- **In a separate script** (`casino.sh` by default): the Makefile stays short
  and only calls `bash casino.sh`. Remember to commit the script.

## Settings

Environment variables, read at every build:

| Variable          | Effect                                      | Default         |
| ----------------- | ------------------------------------------- | --------------- |
| `NO_CASINO=1`     | no animation, the command runs as usual     | off             |
| `CASINO_LOGS=`    | `on`, `line` or `off`                       | chosen at setup |
| `CASINO_SPEED=N`  | spinning speed, 1 (slow) to 6 (fast)        | 2               |
| `CASINO_FPS=N`    | frames per second                           | 25              |

```sh
NO_CASINO=1 make re
CASINO_LOGS=off make
```

The animation also turns itself off when the output is not a terminal (CI,
`make > build.log`, pipes), so logs stay clean there.

## Requirements

- GNU make and **bash 4.3 or newer** (macOS ships bash 3.2:
  `brew install bash`)
- a terminal with 256 colors (Ghostty, kitty, Alacritty, foot, WezTerm, GNOME
  Terminal, iTerm2, …)
- the `N files removed` count reads the `removed '...'` lines printed by GNU
  `rm -v`; with plain `rm` the clean ending just says `all clean`

## Limitations

- The rewrite handles the usual `all` / `clean` / `fclean` rules. It stops
  with an error, without writing anything, if one of them shares a line with
  other targets (`clean fclean:`), is a double-colon rule, or is defined twice.
- Only prerequisites are renamed (`fclean: clean` becomes `_fclean: _clean`).
  Recipes are left alone, so `$(MAKE) clean -C libft` still calls libft's own
  `clean`.
- When a build fails, make adds its own `make: *** [Makefile:NN: all] Error N`
  line after the animation. That line is what makes `make` return an error,
  so it is kept on purpose.
- `make re` plays two animations: the clean, then the build.

## How it works

- The real rule runs in the background with its output captured to a temp
  file; the animation redraws itself in place under the logs every frame.
- Pixels are drawn with the `▀` half-block character: one terminal cell holds
  two square pixels (foreground and background color).
- Each frame is sent in one write wrapped in *synchronized output*
  (`ESC[?2026h` … `ESC[?2026l`), so supporting terminals never show a
  half-drawn frame.

## Layout

| Path                | Contents                                               |
| ------------------- | ------------------------------------------------------ |
| `casino.sh`         | the interactive generator                              |
| `lib/core.sh`       | runs the command, handles logs, drives the animation   |
| `lib/canvas.sh`     | pixel helpers: rectangles, sprites, cabinet and lights |
| `lib/anims/*.sh`    | one file per animation                                 |
| `lib/themes/*.sh`   | one file per color theme                               |
| `examples/demo/`    | a small C project with a plain Makefile to try it on   |

The generator assembles theme + canvas + animation + core into a single
script, so a project only carries the animation it uses.

### Adding an animation

Create `lib/anims/<name>.sh` defining `ANIM_TITLE`, `WIN_MSG`, `LOSE_MSG`,
`CLEAN_MSG`, the canvas size `W` and `H` (even), `MSG_LINE` (the text line
where the result message goes), and two functions:

- `anim_init`, called once;
- `anim_frame`, called every frame: it reads `RESULT` (empty while the
  command runs, then `win`, `lose` or `clean`), draws into the pixel array
  `P`, and sets `ENDED=1` once its final pose is on screen.

Then add it to `ANIMS` and `ANIM_LABELS` in `casino.sh`.
