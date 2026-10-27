# ---- animation: russian roulette ----
# A big revolver cylinder fills the screen of an arcade cabinet, one brass
# bullet among its six chambers, the firing pin marked on top. At the end it
# creeps slowly onto a chamber: an empty one on success (CLICK), the bullet
# on failure (a flash, then BANG!). For clean the bullet drops out (EMPTY).

ANIM_TITLE="RUSSIAN ROULETTE"
WIN_MSG="*click*  SURVIVED" LOSE_MSG="BANG!" CLEAN_MSG="UNLOADED"
W=28 H=18 MSG_LINE=4

RU_STEPS=36 RU_TOP=27   # rotation steps per turn, step of the firing pin

# Cylinder geometry, computed once: the steel disc with its shading, and
# where the top-left pixel of a 3x3 chamber sits at each rotation step.
eval "$(awk -v W=$W -v H=$H 'BEGIN {
	cx = 14; cy = 8.5; pi = atan2(0, -1)
	for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
		dx = x + .5 - cx; dy = y + .5 - cy; r = sqrt(dx * dx + dy * dy)
		c = -1
		if (y >= 2 && y <= 14 && r <= 6.6) {
			s = dx + dy
			c = r > 5.8 ? 240 : s < -5 ? 251 : s > 5 ? 243 : 247
			if (r < 1.2) c = 238
		}
		D = D " " c
	}
	for (i = 0; i < 36; i++) {
		a = i / 36 * 2 * pi
		X = X " " int(cx + 4 * cos(a) - 1); Y = Y " " int(cy + 4 * sin(a) - 1)
	}
	print "RU_DISC=(" D ")\nRU_CX=(" X ")\nRU_CY=(" Y ")"
}')"

anim_init() {
	ru_a=$((RANDOM % RU_STEPS))     # chamber k sits at step ru_a + 6k
	ru_phase=spin ru_left=0 ru_t=0 ru_drop=0
}

chamber() {             # x y loaded
	if (($3)); then
		rect "$1" "$2" 3 3 178
		P[$2 * W + $1]=220
		P[($2 + 1) * W + $1 + 1]=250    # primer
	else
		rect "$1" "$2" 3 3 233
		P[$2 * W + $1]=236
	fi
}

anim_frame() {
	local i k x y c a want step

	case $ru_phase in
		spin)
			ru_a=$(((ru_a + SPEED) % RU_STEPS))
			if [[ -n $RESULT ]]; then
				# one more turn, then onto the chosen chamber
				[[ $RESULT == lose ]] && k=0 || k=$((RANDOM % 5 + 1))
				want=$(((RU_TOP - 6 * k + 2 * RU_STEPS) % RU_STEPS))
				ru_left=$(((want - ru_a + RU_STEPS) % RU_STEPS + RU_STEPS))
				ru_phase=slow
			fi
			;;
		slow)
			# fast at first, then the last chamber creeps in for suspense
			if ((ru_left > 12)); then step=2
			elif ((ru_left > 6)); then step=1
			else ((frame % 3 == 0)) && step=1 || step=0
			fi
			ru_a=$(((ru_a + step) % RU_STEPS))
			ru_left=$((ru_left - step))
			((ru_left == 0)) && ru_phase=fire ru_t=0
			;;
		fire)
			((ru_t++))
			[[ $RESULT == clean ]] && ((ru_drop < 16)) && ((ru_drop++))
			((ru_t > 10)) && ENDED=1
			;;
	esac

	canvas_clear -1
	cabinet 28 16
	c=$T_SCREEN
	if [[ $ru_phase == fire && $RESULT == lose ]]; then
		((ru_t <= 1)) && c=231 || { ((ru_t <= 3)) && c=208 || c=52; }
	fi
	rect 1 1 26 14 "$c"

	if [[ $ru_phase != fire || $RESULT != lose ]]; then
		for ((i = 2 * W; i < 15 * W; i++)); do
			((RU_DISC[i] >= 0)) && P[i]=${RU_DISC[i]}
		done
		for ((k = 0; k < 6; k++)); do
			a=$(((ru_a + 6 * k) % RU_STEPS))
			x=${RU_CX[a]} y=${RU_CY[a]}
			if ((k == 0)) && [[ $RESULT == clean && $ru_phase == fire ]]; then
				chamber "$x" "$y" 0
				((y + ru_drop < 15)) && chamber "$x" $((y + ru_drop)) 1   # falls out
			else
				chamber "$x" "$y" $((k == 0))
			fi
		done
	fi
	rect 13 1 3 1 196                       # firing pin marker
	P[2 * W + 14]=196

	if [[ $ru_phase == fire ]] && ((ru_t >= 2)); then
		case $RESULT in
			win) rect 3 6 22 7 "$T_SCREEN"; text 5 7 255 "CLICK" ;;
			lose) ((ru_t >= 4)) && text 5 7 226 "BANG!" ;;
			clean) ((ru_drop >= 8)) && { rect 3 6 22 7 "$T_SCREEN"; text 5 7 250 "EMPTY"; } ;;
		esac
	fi

	panel 16
	[[ $ru_phase == fire ]] && c=196 || c=88
	rect 4 17 3 1 "$c"                      # trigger button
}
