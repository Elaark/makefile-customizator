# ---- core: runs the command, shows its logs, drives the animation ----
# Expects from the theme: T_* colors. From the animation: ANIM_TITLE,
# WIN_MSG, LOSE_MSG, CLEAN_MSG, W, H, MSG_LINE, anim_init and anim_frame,
# which reads RESULT (empty while running, then win/lose/clean) and sets
# ENDED=1 once its final pose is drawn.

CLEAN=0
[[ ${1-} == --clean ]] && { CLEAN=1; shift; }

if [[ ! -t 1 || -n ${NO_CASINO-} ]]; then
	exec "$@"
fi

LOGS=${CASINO_LOGS:-$LOGS_DEFAULT}
case $LOGS in on | off | line) ;; *) LOGS=on ;; esac
SPEED=${CASINO_SPEED:-2}
[[ $SPEED =~ ^[0-9]+$ ]] || SPEED=2
((SPEED < 1)) && SPEED=1
((SPEED > 6)) && SPEED=6
FPS=${CASINO_FPS:-25}
[[ $FPS =~ ^[1-9][0-9]*$ ]] || FPS=25
DELAY=$(awk "BEGIN { print 1 / $FPS }")
COLS=$(stty size </dev/tty 2>/dev/null)
COLS=${COLS#* }
[[ $COLS =~ ^[0-9]+$ ]] && ((COLS >= 20)) || COLS=80

LOG=$(mktemp)
"$@" >"$LOG" 2>&1 &
PID=$!

E=$'\e'
SYNC_ON="$E[?2026h" SYNC_OFF="$E[?2026l"

cleanup() {
	printf '%s' "$SYNC_OFF$E[0m$E[?25h"
	rm -f "$LOG"
}
trap 'kill "$PID" 2>/dev/null; cleanup; echo; exit 130' INT TERM
printf '%s' "$E[?25l"

FOOT=$((1 + H / 2))
[[ $LOGS == line ]] && FOOT=$((FOOT + 1))

# Builds the footer into $out (raw escapes, printed with %s)
render() {
	local x y t b i c lead title msg="" sub=""

	((CLEAN)) && title="MAKEFILE CLEAN" || title="MAKEFILE $ANIM_TITLE"
	lead=$(((W - ${#title} - 4) / 2))
	((lead < 0)) && lead=0
	out+="  "
	for ((i = 0; i < lead; i++)); do out+=" "; done
	out+="$E[1;38;5;${T_SHIMMER[frame / 4 % 8]}m▶ "
	for ((i = 0; i < ${#title}; i++)); do
		if ((ENDED)) && [[ $RESULT == win ]]; then
			c=$T_WIN_TEXT
		elif ((ENDED)) && [[ $RESULT == lose ]]; then
			c=244
		else
			c=${T_SHIMMER[(i + frame / 4) % 8]}
		fi
		out+="$E[38;5;${c}m${title:i:1}"
	done
	out+=" $E[38;5;${T_SHIMMER[(frame / 4 + 4) % 8]}m◀$E[0m$E[K"$'\n'

	# result message, shown beside the animation
	if ((!ENDED)); then
		((CLEAN)) && msg="NOW CLEANING" || msg="NOW COMPILING"
		msg="$E[1;37m$msg$E[0m"
	elif [[ $RESULT == win ]]; then
		msg="$E[1;38;5;${T_WIN_TEXT}m$WIN_MSG$E[0m" sub="$E[32mbuild OK$E[0m"
	elif [[ $RESULT == clean ]]; then
		msg="$E[1;32m$CLEAN_MSG$E[0m"
		((removed)) && sub="$E[32m$removed files removed$E[0m" || sub="$E[2mall clean$E[0m"
	else
		msg="$E[1;38;5;196m$LOSE_MSG$E[0m" sub="$E[2mexit $rc$E[0m"
	fi

	for ((y = 0; y < H; y += 2)); do
		out+="  "
		for ((x = 0; x < W; x++)); do
			t=${P[y * W + x]} b=${P[(y + 1) * W + x]}
			if ((t < 0 && b < 0)); then out+="$E[0m "
			elif ((t < 0)); then out+="$E[0;38;5;${b}m▄"
			elif ((b < 0)); then out+="$E[0;38;5;${t}m▀"
			else out+="$E[38;5;${t};48;5;${b}m▀"
			fi
		done
		out+="$E[0m"
		((y / 2 == MSG_LINE)) && out+="  $msg"
		((y / 2 == MSG_LINE + 1)) && out+="  $sub"
		out+="$E[K"$'\n'
	done
	[[ $LOGS == line ]] && out+="  $E[2m› $last$E[0m$E[K"$'\n'
}

######  LOOP  ######

frame=0 RESULT="" ENDED=0 rc="" shown=0 removed=0 hold=0 last="" NEW_LOGS=0
anim_init

while :; do
	out=$SYNC_ON
	((frame > 0)) && out+="$E[${FOOT}A"

	if [[ -z $rc ]] && ! kill -0 "$PID" 2>/dev/null && ((frame > 4)); then
		wait "$PID"; rc=$?
		if ((rc != 0)); then
			RESULT=lose
		elif ((CLEAN)); then
			RESULT=clean
			removed=$(grep -c "^removed '" "$LOG")
		else
			RESULT=win
		fi
	fi

	# new log lines go above the animation, which overwrites itself in place
	n=$(wc -l <"$LOG")
	NEW_LOGS=$((n - shown))
	if ((n > shown)); then
		if [[ $LOGS == on ]]; then
			while IFS= read -r line; do
				out+="$E[2K${line//$'\t'/    }$E[0m"$'\n'
			done < <(sed -n "$((shown + 1)),${n}p" "$LOG")
		elif [[ $LOGS == line ]]; then
			last=$(sed -n "${n}{s/\x1b\[[0-9;]*[A-Za-z]//g;s/\t/ /g;p}" "$LOG")
			((${#last} > COLS - 5)) && last="${last:0:COLS-6}…"
		fi
		shown=$n
	fi

	anim_frame
	render
	printf '%s' "$out$SYNC_OFF"

	((ENDED && ++hold > 8)) && break
	((frame++))
	sleep "$DELAY"
done

if [[ $LOGS != on ]]; then
	# logs were hidden: show them when something went wrong
	((rc != 0)) && { echo; cat "$LOG"; }
elif [[ -s $LOG && $(tail -c1 "$LOG" | wc -l) -eq 0 ]]; then
	# last log line may lack a trailing newline
	tail -n1 "$LOG"; echo
fi
cleanup
exit "$rc"
