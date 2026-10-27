#!/usr/bin/env bash
# Makefile Customizator: adds an arcade animation to an existing Makefile.
# Run it and answer the questions; nothing is written before the summary.

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LIB=$ROOT/lib
E=$'\e'
MARKER="MAKEFILE CUSTOMIZATOR"

ANIMS=(slots roulette russian dice claw rpg)
ANIM_LABELS=(
	"Slot machine       7 7 7 on success, a losing combo on failure"
	"Roulette           a prize wheel stops on red, or on the green zero"
	"Russian roulette   the cylinder stops on an empty chamber, or BANG"
	"Dice               two big dice roll a double six, or snake eyes"
	"Claw machine       grabs the prize, or drops it"
	"RPG quest          the knight slays the slime, or dies"
)
THEMES=(purple classic neon mono matrix)
LOG_MODES=(on line off)
LOG_LABELS=(
	"Scrolling   the build logs scroll above the animation"
	"One line    only the last log line, under the animation"
	"Hidden      no logs, shown anyway if the build fails"
)

######  RUNTIME  ######

# The animation script: header + theme + canvas + animation + core
build_runtime() {       # anim theme logs
	printf '%s\n' \
		"# $MARKER runtime (animation: $1, theme: $2, logs: $3)" \
		"# Usage: <runner> [--clean] <command> [args...]" \
		"# Env:   NO_CUSTOMIZATOR=1 to disable, CUSTOMIZATOR_LOGS=on|line|off," \
		"#        CUSTOMIZATOR_SPEED=1..6, CUSTOMIZATOR_FPS=N" \
		"" "LOGS_DEFAULT=$3" ""
	cat "$LIB/themes/$2.sh"; echo
	cat "$LIB/canvas.sh"; echo
	cat "$LIB/anims/$1.sh"; echo
	cat "$LIB/core.sh"
}

# Makefile section holding the runtime, kept unexpanded with $(value)
embedded_block() {      # anim theme logs
	local runtime
	runtime=$(build_runtime "$@")
	if grep -qE '^[[:space:]]*(define|endef)([[:space:]]|$)' <<<"$runtime"; then
		echo "internal error: the runtime cannot be embedded" >&2
		return 1
	fi
	printf '%s\n' \
		"" \
		"# **************************************************************************** #" \
		"#   $MARKER - animation: $1, theme: $2, logs: $3" \
		"#   NO_CUSTOMIZATOR=1 make runs without the animation." \
		"# **************************************************************************** #" \
		"" \
		"# Kept unexpanded with \$(value) so the script needs no \$\$ escaping" \
		"define CUSTOMIZATOR_RUNTIME_SRC" \
		"$runtime" \
		"endef" \
		"export CUSTOMIZATOR_RUNTIME := \$(value CUSTOMIZATOR_RUNTIME_SRC)"
}

######  MAKEFILE  ######

# Prints "first <target>" and one "has <target>" per wrappable rule, or
# "error <message>" for rules this tool can't safely rewrite.
scan_makefile() {       # file
	awk '
		/^define[ \t]/ { indef = 1 }
		/^endef/ { indef = 0; next }
		indef || /^\t/ || /^[ \t]*#/ || cont { cont = /\\$/; next }
		{
			i = index($0, ":")
			if (i == 0) next
			eq = index($0, "=")
			if (eq && eq < i) next
			if (substr($0, i + 1, 1) == "=" || substr($0, i + 1, 2) == ":=") next
			cont = /\\$/
			n = split(substr($0, 1, i - 1), t, " ")
			if (n && !first && t[1] !~ /^\./ && t[1] !~ /%/) { first = t[1]; print "first " first }
			for (k = 1; k <= n; k++) {
				if (t[k] != "all" && t[k] != "clean" && t[k] != "fclean") continue
				if (n > 1) { print "error \"" t[k] "\" shares a rule with other targets (line " NR ")"; next }
				if (substr($0, i + 1, 1) == ":") { print "error \"" t[k] "::\" double-colon rules are not supported (line " NR ")"; next }
				if (seen[t[k]]++) { print "error \"" t[k] "\" is defined twice (line " NR ")"; next }
				print "has " t[k]
			}
		}
	' "$1"
}

# Renames all/clean/fclean to _all/_clean/_fclean and puts a public rule in
# front of each one that runs it through the animation.
rewrite_makefile() {    # file runner wrapped...
	local file=$1 runner=$2
	shift 2
	awk -v wrapped="$*" -v runner="$runner" '
		BEGIN { n = split(wrapped, w, " "); for (i = 1; i <= n; i++) isw[w[i]] = 1 }
		function rename(s,   out, word) {
			out = ""
			while (match(s, /[^ \t\\;]+/)) {
				word = substr(s, RSTART, RLENGTH)
				out = out substr(s, 1, RSTART - 1) ((word in isw) ? "_" word : word)
				s = substr(s, RSTART + RLENGTH)
			}
			return out s
		}
		cont { print rename($0); cont = /\\$/; next }
		/^define[ \t]/ { indef = 1 }
		/^endef/ { indef = 0 }
		!indef && !/^\t/ {
			for (k = 1; k <= n; k++) {
				name = w[k]
				if ($0 !~ ("^" name "[ \t]*:([^=]|$)")) continue
				rest = substr($0, index($0, ":") + 1)
				print name ":"
				print "\t@" runner " " (name == "all" ? "" : "--clean ") "$(MAKE) --no-print-directory _" name
				print ""
				print "_" name ":" rename(rest)
				cont = /\\$/
				next
			}
		}
		{ print }
		END {
			phony = ""
			for (k = 1; k <= n; k++) phony = phony " _" w[k]
			print ""
			print ".PHONY:" phony
		}
	' "$file"
}

# A GNUmakefile is read by GNU make before the Makefile: it wraps the
# public rules in the animation and forwards everything else untouched.
gnumakefile() {         # makefile-name first runner wrapped...
	local mk=$1 first=$2 runner=$3 name order=()
	shift 3
	local wrapped=" $* "
	printf '%s\n' \
		"# **************************************************************************** #" \
		"#   $MARKER - wraps $mk in an animation, without modifying it." \
		"#   Delete this file to go back to plain make." \
		"# **************************************************************************** #" \
		"" \
		"CUSTOMIZATOR_MAKE = \$(MAKE) --no-print-directory -f $mk" ""
	if [[ $wrapped == *" $first "* ]]; then
		order=("$first")
	else
		printf '%s\n' "customizator-default:" $'\t'"@\$(CUSTOMIZATOR_MAKE)" ""
	fi
	for name; do [[ $name != "$first" ]] && order+=("$name"); done
	for name in "${order[@]}"; do
		[[ $name == all ]] && flag="" || flag="--clean "
		printf '%s\n' "$name:" $'\t'"@$runner $flag\$(CUSTOMIZATOR_MAKE) $name" ""
	done
	if [[ $HAS_RE && $wrapped == *" fclean "* && $wrapped == *" all "* ]]; then
		printf '%s\n' "re:" \
			$'\t'"@\$(MAKE) --no-print-directory fclean" \
			$'\t'"@\$(MAKE) --no-print-directory all" ""
	fi
	printf '%s\n' \
		"$mk GNUmakefile: ;" "" \
		"%:" $'\t'"@\$(CUSTOMIZATOR_MAKE) \$@" "" \
		".PHONY: customizator-default $* ${HAS_RE:+re}"
}

######  MENUS  ######

# Arrow keys (or j/k, or a digit) and Enter. Sets CHOICE to the index.
menu() {                # title option...
	local title=$1 sel=0 key i n
	shift
	n=$#
	local opts=("$@")
	printf '\n%s\n' "$E[1m$title$E[0m"
	while :; do
		for ((i = 0; i < n; i++)); do
			if ((i == sel)); then
				printf '  %s\n' "$E[1;38;5;213m› ${opts[i]}$E[0m$E[K"
			else
				printf '    %s\n' "${opts[i]}$E[K"
			fi
		done
		IFS= read -rsn1 key
		case $key in
			$'\e')
				read -rsn2 -t 0.05 key
				[[ $key == "[A" ]] && sel=$(((sel + n - 1) % n))
				[[ $key == "[B" ]] && sel=$(((sel + 1) % n))
				;;
			k) sel=$(((sel + n - 1) % n)) ;;
			j) sel=$(((sel + 1) % n)) ;;
			[1-9]) ((key <= n)) && sel=$((key - 1)) ;;
			"") break ;;
		esac
		printf '%s' "$E[${n}A"
	done
	CHOICE=$sel
}

theme_label() {         # theme
	(
		source "$LIB/themes/$1.sh"
		printf '%-9s %s' "$1" "$E[48;5;${T_BODY}m  $E[48;5;${T_BULB_ON}m  $E[48;5;${T_WIN}m  $E[48;5;${T_SHIMMER[3]}m  $E[0m"
	)
}

banner() {
	local t="M A K E F I L E   C U S T O M I Z A T O R" i c out=""
	local colors=(219 213 177 141 135 141 177 213)
	for ((i = 0; i < ${#t}; i++)); do
		c=${colors[i % 8]}
		out+="$E[1;38;5;${c}m${t:i:1}"
	done
	printf '\n  %s%s\n' "$out" "$E[0m"
	printf '  %s\n' "$E[2mAdds an arcade animation to your Makefile.$E[0m"
}

preview() {             # anim theme logs result
	local tmp cmd
	tmp=$(mktemp)
	build_runtime "$1" "$2" "$3" >"$tmp"
	# fake builds, with enough output to compare the log modes
	case $4 in
		win) cmd='for f in main lexer parser eval env builtins signals utils; do
				echo "cc -Wall -Wextra -Werror -Iincludes -c srcs/$f.c -o build/$f.o"; sleep 0.25
			done
			echo "cc build/*.o -o minishell"' ;;
		lose) cmd='for f in main lexer parser; do
				echo "cc -Wall -Wextra -Werror -Iincludes -c srcs/$f.c -o build/$f.o"; sleep 0.25
			done
			printf "%s\n" "srcs/parser.c:42:17: error: expected '"'"';'"'"' after expression" \
				"   42 |     node = parse_cmd(tokens)" \
				"      |                             ^" "1 error generated."
			exit 2' ;;
		clean) cmd='for f in main lexer parser eval env builtins signals utils; do
				echo "removed '"'"'build/$f.o'"'"'"; sleep 0.1
			done' ;;
	esac
	echo
	if [[ $4 == clean ]]; then
		bash "$tmp" --clean bash -c "$cmd"
	else
		bash "$tmp" bash -c "$cmd"
	fi
	rm -f "$tmp"
}

die() {
	printf '\n  %s\n\n' "$E[1;38;5;196m✗$E[0m $*" >&2
	exit 1
}

######  MAIN  ######

main() {
	local makefile dir mkname scan line wrapped=() first="" anim theme logs
	local mode placement script="" runner out_file backup="" i ai li labels=()

	[[ -t 0 && -t 1 ]] || die "customizator.sh is interactive: run it from a terminal."
	banner

	printf '\n%s\n' "$E[1mWhich Makefile?$E[0m"
	read -rep "  path: " -i "Makefile" makefile
	[[ -f $makefile ]] || die "$makefile: no such file."
	grep -q "$MARKER" "$makefile" && die "$makefile already has an animation. Start again from the original (or the .customizator.bak backup)."
	dir=$(cd "$(dirname "$makefile")" && pwd)
	mkname=$(basename "$makefile")
	grep -qs "$MARKER" "$dir/GNUmakefile" &&
		die "$dir/GNUmakefile already adds an animation. Delete it to start again."

	HAS_RE=""
	scan=$(scan_makefile "$makefile")
	while read -r line; do
		case $line in
			"error "*) die "$mkname: ${line#error }" ;;
			"has "*) wrapped+=("${line#has }") ;;
			"first "*) first=${line#first } ;;
		esac
	done <<<"$scan"
	grep -qE '^re[[:space:]]*:' "$makefile" && HAS_RE=1
	((${#wrapped[@]})) || die "$mkname has no all, clean or fclean rule to animate."
	printf '  %s\n' "$E[32m✓$E[0m rules found: ${wrapped[*]}"

	while :; do
		menu "Animation?" "${ANIM_LABELS[@]}"
		ai=$CHOICE
		anim=${ANIMS[ai]}
		labels=()
		for i in "${THEMES[@]}"; do labels+=("$(theme_label "$i")"); done
		menu "Theme?" "${labels[@]}"
		theme=${THEMES[CHOICE]}
		while :; do
			menu "${ANIM_LABELS[ai]%%  *}, theme $theme: preview?" \
				"Looks good, continue" \
				"Preview a successful build" \
				"Preview a failed build" \
				"Preview a clean" \
				"Pick another animation or theme"
			case $CHOICE in
				0) break 2 ;;
				1) preview "$anim" "$theme" on win ;;
				2) preview "$anim" "$theme" on lose ;;
				3) preview "$anim" "$theme" on clean ;;
				4) break ;;
			esac
		done
	done

	while :; do
		menu "Build logs?" "${LOG_LABELS[@]}"
		li=$CHOICE
		logs=${LOG_MODES[li]}
		while :; do
			menu "${LOG_LABELS[li]%%  *} logs: preview?" \
				"Looks good, continue" \
				"Preview a successful build" \
				"Preview a failed build" \
				"Preview a clean" \
				"Pick another log mode"
			case $CHOICE in
				0) break 2 ;;
				1) preview "$anim" "$theme" "$logs" win ;;
				2) preview "$anim" "$theme" "$logs" lose ;;
				3) preview "$anim" "$theme" "$logs" clean ;;
				4) break ;;
			esac
		done
	done

	menu "How should it be added?" \
		"$(printf '%-21s' "Rewrite $mkname") all/clean/fclean are renamed and wrapped (a backup is kept)" \
		"Add a GNUmakefile     $mkname stays untouched, GNU make reads GNUmakefile first"
	((CHOICE == 0)) && mode=rewrite || mode=gnu

	menu "Where should the animation code live?" \
		"Inside the Makefile   one self-contained file, nothing else to ship" \
		"In a separate script  the Makefile stays short and readable"
	if ((CHOICE == 0)); then
		placement=embedded
		runner='bash -c "$$CUSTOMIZATOR_RUNTIME" customizator'
	else
		placement=script
		printf '\n%s\n' "$E[1mScript path, relative to the Makefile?$E[0m"
		read -rep "  path: " -i "makefile_anim.sh" script
		[[ -n $script ]] || die "no script path given."
		runner="bash $script"
	fi

	[[ $mode == rewrite ]] && out_file=$dir/$mkname || out_file=$dir/GNUmakefile
	printf '\n%s\n' "$E[1mSummary$E[0m"
	printf '  %-12s %s\n' \
		"animation" "$anim" "theme" "$theme" "logs" "$logs" "writes" "$out_file"
	[[ -n $script ]] && printf '  %-12s %s\n' "script" "$dir/$script"
	[[ $mode == rewrite ]] && printf '  %-12s %s\n' "backup" "$out_file.customizator.bak"
	[[ -e $dir/GNUmakefile && $mode == gnu ]] &&
		printf '  %-12s %s\n' "replaces" "the existing GNUmakefile (backup: GNUmakefile.customizator.bak)"
	menu "Write these files?" "Yes" "No, quit without writing"
	((CHOICE == 0)) || { echo; exit 0; }

	if [[ $mode == rewrite ]]; then
		backup=$out_file.customizator.bak
		cp "$makefile" "$backup" || die "cannot write $backup"
		{
			rewrite_makefile "$backup" "$runner" "${wrapped[@]}" &&
				if [[ $placement == embedded ]]; then
					embedded_block "$anim" "$theme" "$logs"
				else
					printf '\n%s\n' "# $MARKER - animation: $anim, theme: $theme, logs: $logs, code in $script"
				fi
		} >"$out_file.customizator.tmp" && mv "$out_file.customizator.tmp" "$out_file" || die "cannot write $out_file"
	else
		[[ -e $out_file ]] && { cp "$out_file" "$out_file.customizator.bak" || die "cannot back up $out_file"; }
		{
			gnumakefile "$mkname" "$first" "$runner" "${wrapped[@]}" &&
				if [[ $placement == embedded ]]; then embedded_block "$anim" "$theme" "$logs"; fi
		} >"$out_file" || die "cannot write $out_file"
	fi
	if [[ $placement == script ]]; then
		mkdir -p "$(dirname "$dir/$script")" &&
			{ echo '#!/usr/bin/env bash'; build_runtime "$anim" "$theme" "$logs"; } >"$dir/$script" &&
			chmod +x "$dir/$script" || die "cannot write $dir/$script"
	fi

	printf '\n  %s\n' "$E[32m✓$E[0m Done. Try it: $E[1mmake$E[0m"
	if [[ $mode == rewrite ]]; then
		printf '  %s\n' "$E[2mTo undo: mv $backup $out_file$E[0m"
	else
		printf '  %s\n' "$E[2mTo undo: rm $out_file$E[0m"
	fi
	echo
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
