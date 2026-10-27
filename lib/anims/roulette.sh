# ---- animation: roulette ----
# A big upright prize wheel in an arcade cabinet: red and black wedges, one
# green zero, lights around the rim and a pointer on top. It slows down on a
# red wedge on success, on the green zero on failure. For clean it spins
# backwards and its wedges go dark one by one.

ANIM_TITLE="ROULETTE"
WIN_MSG="★ RED WINS ★" LOSE_MSG="ZERO! HOUSE WINS" CLEAN_MSG="CLEANED"
W=28 H=18 MSG_LINE=4

RO_SEG=10 RO_STEPS=60   # wedges, rotation steps per turn
RO_TOP=45               # angle step under the pointer (straight up)

# Wheel geometry, computed once: per pixel its layer (0 outside, 1 rim,
# 2 wedges, 3 hub) and its angle step.
eval "$(awk -v W=$W -v H=$H 'BEGIN {
	cx = 14; cy = 8.5; pi = atan2(0, -1)
	for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
		dx = x + .5 - cx; dy = y + .5 - cy; r = sqrt(dx * dx + dy * dy)
		a = atan2(dy, dx); if (a < 0) a += 2 * pi
		l = (y < 2 || y > 14) ? 0 : r > 6.6 ? 0 : r > 5.6 ? 1 : r > 1.5 ? 2 : 3
		L = L " " l; A = A " " int(a / (2 * pi) * 60) % 60
	}
	print "RO_LAYER=(" L ")\nRO_ANGLE=(" A ")"
}')"

anim_init() {
	ro_rot=$((RANDOM % RO_STEPS))
	ro_dir=1
	((CLEAN)) && ro_dir=-1
	ro_target=-1 ro_stopped=0 ro_fade=-1
}

ro_wedge() {            # wedge -> c (0 is the green zero)
	if (($1 == 0)); then c=28; elif (($1 % 2)); then c=160; else c=233; fi
}

anim_frame() {
	local i x c w a top seg

	if ((ro_target < 0)) && [[ -n $RESULT ]]; then
		case $RESULT in
			win) seg=$(((RANDOM % 4) * 2 + 1)) ;;   # a red wedge
			lose) seg=0 ;;
			*) seg=$((RANDOM % RO_SEG)) ;;
		esac
		# the middle of that wedge under the pointer
		ro_target=$(((seg * 6 + 3 - RO_TOP + 2 * RO_STEPS) % RO_STEPS))
	fi
	if ((ro_target < 0)); then
		ro_rot=$(((ro_rot + ro_dir * (SPEED + 1) + RO_STEPS) % RO_STEPS))
	elif ((!ro_stopped)); then
		approach ro_rot "$ro_target" "$RO_STEPS" $((SPEED + 1)) "$ro_dir" && ro_stopped=1
	elif [[ $RESULT == clean ]] && ((ro_fade < RO_SEG)); then
		((ro_fade++))
	else
		ENDED=1
	fi
	top=$((((RO_TOP + ro_rot) % RO_STEPS) / 6))

	canvas_clear -1
	cabinet 28 16
	rect 1 1 26 14 "$T_SCREEN"
	for ((i = 0; i < W * H; i++)); do
		case ${RO_LAYER[i]} in
			0) continue ;;
			1)                                  # rim with chasing lights
				a=${RO_ANGLE[i]}
				if ((a % 5 == 0)); then
					if ((ENDED)); then
						[[ $RESULT == lose ]] && c=$T_DEAD || c=$T_WIN
					else
						(((a / 5 + frame / 2) % 3 == 0)) && c=$T_BULB_ON || c=$T_BULB_OFF
					fi
				else
					c=136
				fi
				;;
			2)
				a=$(((RO_ANGLE[i] + ro_rot) % RO_STEPS))
				w=$((a / 6))
				if ((a % 6 == 0)); then
					c=252                       # wedge border
				else
					ro_wedge "$w"
					((w < ro_fade)) && c=237    # clean: wedges go dark
				fi
				;;
			3) c=250 ;;
		esac
		P[i]=$c
	done
	P[8 * W + 13]=255                       # hub shine

	# pointer: flicks aside each time a wedge border passes under it
	x=13
	((!ro_stopped && (RO_TOP + ro_rot) % 6 < 2)) && x=$((x - ro_dir))
	rect 12 1 3 1 196
	P[2 * W + x + 1]=196

	# result lamp on the side shows the color under the pointer
	ro_wedge "$top"
	((top < ro_fade)) && c=237
	rect 23 6 3 3 "$c"
	rect 23 5 3 1 240
	rect 2 11 3 3 178; rect 2 10 3 1 220   # chip stacks
	rect 2 6 3 3 160; rect 2 5 3 1 203

	panel 16
	((ENDED)) && c=22 || c=46
	rect 4 17 3 1 "$c"                     # spin button
}
