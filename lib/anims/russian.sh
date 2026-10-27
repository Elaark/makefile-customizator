# ---- animation: russian roulette ----
# A revolver cylinder with one bullet spins, then ticks slowly into place
# under the firing pin: empty chamber on success (*click*), the bullet on
# failure (BANG). For clean the bullet drops out of the cylinder.

ANIM_TITLE="RUSSIAN ROULETTE"
WIN_MSG="*click*  SURVIVED" LOSE_MSG="BANG!" CLEAN_MSG="UNLOADED"
W=18 H=14 MSG_LINE=3

RU_CX=8 RU_CY=6         # the cylinder is centered on (CX + .5, CY + .5)
# chamber offsets every 30°, clockwise from 3 o'clock; 9 is the firing pin
RU_DX=(3 3 2 0 -2 -3 -3 -3 -2 0 2 3)
RU_DY=(0 2 3 3 3 2 0 -2 -3 -3 -3 -2)

anim_init() {
	ru_r=$((RANDOM % 12))  # rotation, in 30° steps
	ru_target=-1 ru_wait=0 ru_drop=-1 ru_loaded=1
}

anim_frame() {
	local x y X Y s k a want rem

	if [[ -n $RESULT ]] && ((ru_target < 0)); then
		[[ $RESULT == lose ]] && want=9 || want=3
		ru_target=$((ru_r + 12))
		while ((ru_target % 12 != want)); do ((ru_target++)); done
	fi
	if ((ru_target < 0)); then
		ru_r=$((ru_r + (SPEED + 1) / 2))
	elif ((ru_r < ru_target)); then
		rem=$((ru_target - ru_r))  # last steps tick slowly, for suspense
		if ((rem > 3 || ++ru_wait >= (4 - rem) * 3)); then
			((ru_r++)); ru_wait=0
		fi
	elif [[ $RESULT == clean ]]; then
		ru_loaded=0
		((ru_drop++))
		((ru_drop > 8)) && ENDED=1
	else
		ENDED=1
	fi

	canvas_clear -1
	cabinet 18 14
	c=$T_SCREEN
	((ENDED && hold < 2)) && [[ $RESULT == lose ]] && c=208  # muzzle flash
	rect 1 1 16 12 "$c"
	for ((y = 1; y < 13; y++)); do
		for ((x = 2; x < 16; x++)); do
			X=$((2 * (x - RU_CX) - 1)) Y=$((2 * (y - RU_CY) - 1))
			((X * X + Y * Y > 121)) && continue
			s=$((X + Y))
			if ((s < -8)); then c=250; elif ((s > 8)); then c=240; else c=245; fi
			P[y * W + x]=$c
		done
	done
	rect "$RU_CX" "$RU_CY" 2 2 238      # center pin
	for ((k = 0; k < 6; k++)); do
		a=$(((ru_r + 2 * k) % 12))
		x=$((RU_CX + RU_DX[a])) y=$((RU_CY + RU_DY[a]))
		if ((k == 0 && ru_loaded)); then
			rect "$x" "$y" 2 2 178
			P[y * W + x]=220
		else
			rect "$x" "$y" 2 2 233
		fi
		if ((k == 0 && ru_drop >= 0 && y + ru_drop < 13)); then
			rect "$x" $((y + ru_drop)) 2 2 178   # bullet falling out
			P[(y + ru_drop) * W + x]=220
		fi
	done
	rect "$RU_CX" 0 2 1 196             # firing pin marker
}
