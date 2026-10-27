# ---- animation: roulette ----
# A strip of pockets runs under a pointer: the ball lands on red on success,
# on the green zero on failure. For clean the strip runs backwards and the
# pockets empty out from the pointer.

ANIM_TITLE="ROULETTE"
WIN_MSG="★ RED WINS ★" LOSE_MSG="ZERO! HOUSE WINS" CLEAN_MSG="CLEANED"
W=30 H=14 MSG_LINE=3

RO_N=37 RO_PW=4         # pockets (0 is green), pixel width of a pocket
RO_L=$((RO_N * RO_PW))
RO_X=2 RO_W=26 RO_PTR=13

anim_init() {
	ro_off=$((RANDOM % RO_L))
	ro_dir=1
	((CLEAN)) && ro_dir=-1
	ro_target=-1 ro_fade=-1
}

anim_frame() {
	local x y p pk c d t best=-1

	if [[ -n $RESULT ]] && ((ro_target < 0)); then
		# closest matching pocket, far enough ahead to slow down nicely
		for ((pk = 0; pk < RO_N; pk++)); do
			case $RESULT in
				win) ((pk % 2 == 1)) || continue ;;
				lose) ((pk == 0)) || continue ;;
			esac
			t=$(((pk * RO_PW + 2 - RO_PTR + RO_L) % RO_L))
			d=$(((ro_dir * (t - ro_off) % RO_L + 2 * RO_L) % RO_L))
			((d < 24)) && d=$((d + RO_L))
			((best < 0 || d < best)) && best=$d ro_target=$t
		done
	fi
	if ((ro_target < 0)); then
		ro_off=$(((ro_off + ro_dir * (SPEED + 2) + RO_L) % RO_L))
	elif ((ro_fade < 0)); then
		approach ro_off "$ro_target" "$RO_L" $((SPEED + 2)) "$ro_dir" && ro_fade=0
	elif [[ $RESULT == clean ]] && ((ro_fade <= RO_PTR)); then
		((ro_fade++))
	else
		ENDED=1
	fi

	canvas_clear -1
	cabinet 30 13
	rect 2 2 26 9 22                    # felt
	rect 2 4 26 1 236                   # rails
	rect 2 10 26 1 236
	for ((x = 0; x < RO_W; x++)); do
		p=$(((ro_off + x) % RO_L))
		pk=$((p / RO_PW))
		if ((p % RO_PW == 0)); then
			c=250
		elif ((ro_fade >= 0)) && [[ $RESULT == clean ]] &&
			((x - RO_PTR <= ro_fade && RO_PTR - x <= ro_fade)); then
			c=240
		elif ((pk == 0)); then
			c=28
		elif ((pk % 2)); then
			c=160
		else
			c=233
		fi
		for ((y = 5; y < 10; y++)); do P[y * W + RO_X + x]=$c; done
	done

	x=$((RO_X + RO_PTR))                # pointer
	rect $((x - 1)) 2 3 1 255
	P[3 * W + x]=255
	if ((ro_fade >= 0)) && [[ $RESULT != clean ]]; then
		P[6 * W + x]=255                # ball in its pocket
		rect $((x - 1)) 7 3 1 255
		P[8 * W + x]=250
	fi
}
