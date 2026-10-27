# Makefile Customizator

Turn every `make` into a little arcade game.

`customizator.sh` adds a pixel-art animation to an existing Makefile. While
your project compiles, the animation plays at the bottom of the terminal; when
the build ends, it shows the result: a win if it compiled, a loss if it
didn't. `make clean` and `make fclean` get their own ending too.

Nothing about the build itself changes: same targets, same compiler output,
same exit code.

## Quick start

```sh
git clone git@github.com:Elaark/makefile-customizator.git ~/makefile-customizator
cd your/project
~/makefile-customizator/customizator.sh
```

The generator is interactive (arrow keys or `j`/`k`, Enter to pick). It asks:

1. **which Makefile** to use,
2. **which animation** and **which theme**,
3. **how to show the build logs**,
4. **how to add it**: rewrite the Makefile, or add a `GNUmakefile` next to it,
5. **where the animation code lives**: inside the Makefile, or a separate
   script.

After choosing the animation and theme, and again after choosing the log
mode, you can preview a successful build, a failed build and a clean before
going on. Nothing is written before the final summary, and a backup is
always kept.

Want to try it first? `examples/demo` is a tiny C project with a plain
Makefile:

```sh
cd ~/makefile-customizator/examples/demo
../../customizator.sh
make
```

## Animations

| Animation        | While building                          | Success                                  | Failure                                   | Clean                                  |
| ---------------- | --------------------------------------- | ---------------------------------------- | ----------------------------------------- | -------------------------------------- |
| Slot machine     | three reels spin, chasing lights        | 7 7 7, `★ JACKPOT ★`                     | a losing combo, `GAME OVER`               | reels spin back to empty               |
| Roulette         | the wheel turns, the ball runs the rim  | the ball drops into a red pocket         | the ball drops into the green zero        | the wheel stops, its pockets go grey   |
| Russian roulette | the revolver's cylinder spins           | the hammer falls on an empty chamber     | BANG: muzzle flash, recoil, smoke         | the cylinder swings out, casings drop  |
| Dice             | a dice cup rattles on the table         | the cup tips over: double six            | snake eyes                                | blank dice roll off the table          |
| Claw machine     | the claw sweeps, steered by a joystick  | it grabs a prize and drops it in the chute | the prize slips and falls back          | the pile empties                       |
| RPG quest        | a knight fights a slime                 | the slime bursts and drops a coin        | the slime leaps onto the knight           | the slime melts away                   |

In the RPG, the knight strikes each time the build prints new lines.

## Themes

`purple`, `classic` (red and gold), `neon` (cyan and magenta on a dark
cabinet), `mono` (greys) and `matrix` (green on black). Themes color the
cabinets, lights, frames and titles; symbols, dice, prizes and characters
keep their own colors.

## Build logs

| Mode      | What you see                                              |
| --------- | --------------------------------------------------------- |
| Scrolling | the full logs scroll above the animation, as usual        |
| One line  | only the latest log line, under the animation             |
| Hidden    | no logs at all, but they are printed if the build fails   |

The mode chosen in the generator is the default; `CUSTOMIZATOR_LOGS`
overrides it.

## Integration

**Rewrite the Makefile.** `all`, `clean` and `fclean` become `_all`, `_clean`
and `_fclean`, and new public rules run them through the animation:

```make
all:
	@bash makefile_anim.sh $(MAKE) --no-print-directory _all

_all: $(NAME)          # your original "all" rule
```

The original file is saved as `Makefile.customizator.bak`. To undo:
`mv Makefile.customizator.bak Makefile`.

**Add a GNUmakefile.** GNU make reads `GNUmakefile` before `Makefile`, so a
generated `GNUmakefile` wraps `all`, `clean`, `fclean` and `re` in the
animation and forwards every other target to your Makefile, which is never
touched. To undo: delete `GNUmakefile`. Use the rewrite instead if your
project must contain a single Makefile.

### Where the code lives

- **Inside the Makefile** (or GNUmakefile): one self-contained file. The
  script is stored in a `define` block and kept unexpanded with `$(value ...)`,
  so it is plain bash with no `$$` doubling.
- **In a separate script** (`makefile_anim.sh` by default): the Makefile stays
  short and only calls `bash makefile_anim.sh`. Remember to commit the script.

## Settings

Environment variables, read at every build:

| Variable                | Effect                                    | Default         |
| ----------------------- | ----------------------------------------- | --------------- |
| `NO_CUSTOMIZATOR=1`     | no animation, the command runs as usual   | off             |
| `CUSTOMIZATOR_LOGS=`    | `on`, `line` or `off`                     | chosen at setup |
| `CUSTOMIZATOR_SPEED=N`  | spinning speed, 1 (slow) to 6 (fast)      | 2               |
| `CUSTOMIZATOR_FPS=N`    | frames per second                         | 25              |

```sh
NO_CUSTOMIZATOR=1 make re
CUSTOMIZATOR_LOGS=off make
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
  file; the animation redraws itself in place under the logs every frame,
  at a steady frame rate.
- Pixels are drawn with the `▀` half-block character: one terminal cell holds
  two square pixels (foreground and background color).
- Each frame is sent in one write wrapped in *synchronized output*
  (`ESC[?2026h` … `ESC[?2026l`), so supporting terminals never show a
  half-drawn frame.

## Layout

| Path                 | Contents                                               |
| -------------------- | ------------------------------------------------------ |
| `customizator.sh`    | the interactive generator                              |
| `lib/core.sh`        | runs the command, handles logs, drives the animation   |
| `lib/canvas.sh`      | pixel helpers: rectangles, sprites, cabinet and lights |
| `lib/anims/*.sh`     | one file per animation                                 |
| `lib/themes/*.sh`    | one file per color theme                               |
| `examples/demo/`     | a small C project with a plain Makefile to try it on   |

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

Then add it to `ANIMS` and `ANIM_LABELS` in `customizator.sh`.
