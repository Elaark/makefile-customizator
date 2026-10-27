# ---- animation: russian roulette ----
# A revolver seen from the side, its cylinder spinning; a strip below shows
# the six chambers and the one under the hammer. At the end the cylinder
# ticks slowly into place and the hammer falls: an empty chamber on success
# (*click*), the bullet on failure (BANG, muzzle flash, smoke). For clean the
# cylinder swings out and the casings drop.

ANIM_TITLE="RUSSIAN ROULETTE"
WIN_MSG="*click*  SURVIVED" LOSE_MSG="BANG!" CLEAN_MSG="UNLOADED"
W=30 H=14 MSG_LINE=3

declare -A RU_PAL=(
	[H]=240 [S]=245 [L]=250 [D]=240 [K]=232 [F]=252 [T]=240
	[W]=94 [G]=130 [B]=58 [Y]=226 [O]=214 [X]=231
)
RU_GUN=(
	".....................F"
	"...SLLLLLLLLLLLLLLLLLL"
	"...S......SSSSSSSSSSSK"
	"...S......SDDDDDDDDDDD"
	"...S......SD.........."
	"..WS......S..........."
	".WGWSSSSSSD..........."
	".WGW..T..D............"
	"WGWW..T.D............."
	"WGW....DD............."
	"WGW..................."
	".BB..................."
)
RU_FLASH=(
	"..Y.." ".YOY." "OXXXY" ".YOY." "..Y.."
)
RU_FLASH2=(
	"....." "..O.." ".OXO." "..O.." "....."
)
RU_GX=2 RU_GY=1         # gun position; the cylinder is cols 4-9, rows 2-5
RU_CYL=(252 247 242 238)

anim_init() {
	ru_c=$((RANDOM % 6))  # chamber under the hammer; the bullet is in 0
	ru_phase=spin ru_t=0 ru_target=-1 ru_wait=0 ru_roll=0
	ru_puffs=()             # smoke: "x y age" triples
}

anim_frame() {
	local x y k c gy=$RU_GY row cx cy i a

	case $ru_phase in
		spin)
			ru_roll=$((ru_roll + 1))
			((frame % 2)) && ru_c=$(((ru_c + 1) % 6))
			if [[ -n $RESULT ]]; then
				if [[ $RESULT == clean ]]; then
					ru_phase=open ru_t=0
				else
					# at least one full turn, then slowly onto the chamber
					[[ $RESULT == lose ]] && a=0 || a=3
					ru_target=$((6 + (a - ru_c + 6) % 6))
					ru_phase=tick ru_t=0
				fi
			fi
			;;
		tick)
			k=$((ru_target - ru_t))     # ticks left
			if ((k > 3 || ++ru_wait >= (4 - k) * 4)); then
				ru_wait=0
				((ru_t++))
				ru_c=$(((ru_c + 1) % 6))
				ru_roll=$((ru_roll + 1))
				((ru_t >= ru_target)) && ru_phase=fire ru_t=0
			fi
			;;
		fire)
			((ru_t++))
			if [[ $RESULT == lose ]] && ((ru_t == 2)); then
				ru_puffs=("24 2 0" "25 4 1" "23 3 2")
			fi
			if [[ $RESULT == win ]] && ((ru_t > 4)); then
				ENDED=1
			elif [[ $RESULT == lose ]] && ((ru_t > 14)); then
				ENDED=1
			fi
			;;
		open)
			((ru_t++))
			((ru_t > 6 + 6 * 3 + 10)) && ENDED=1
			;;
	esac

	canvas_clear -1
	cabinet 30 14
	c=$T_SCREEN
	[[ $ru_phase == fire && $RESULT == lose ]] && ((ru_t >= 2 && ru_t <= 3)) && c=52
	rect 1 1 28 12 "$c"

	# recoil: the gun kicks up for two frames after the shot
	[[ $ru_phase == fire && $RESULT == lose ]] && ((ru_t >= 2 && ru_t <= 3)) && gy=0
	sprite "$RU_GX" "$gy" RU_PAL "${RU_GUN[@]}"

	# cylinder: shading bands roll as it turns; swung out for clean
	cy=$((gy + 2))
	[[ $ru_phase == open ]] && ((ru_t >= 3)) && cy=$((gy + 5))
	for ((y = 0; y < 4; y++)); do
		c=${RU_CYL[(y + ru_roll) % 4]}
		for ((x = 0; x < 6; x++)); do
			P[(cy + y) * W + RU_GX + 4 + x]=$c
		done
		P[(cy + y) * W + RU_GX + 4]=240
		P[(cy + y) * W + RU_GX + 9]=238
	done

	# hammer: cocked while spinning, down once fired
	if [[ $ru_phase == fire || ($ru_phase == open && ru_t -ge 3) ]]; then
		P[(gy + 1) * W + RU_GX + 2]=240
		P[gy * W + RU_GX + 3]=240
	else
		P[gy * W + RU_GX + 1]=240; P[gy * W + RU_GX + 2]=240
		P[(gy + 1) * W + RU_GX + 2]=240
	fi

	if [[ $ru_phase == fire ]]; then
		if [[ $RESULT == win ]] && ((ru_t <= 3)); then   # click sparks
			P[gy * W + RU_GX + 1]=255; P[(gy + 2) * W + RU_GX + 1]=255
			P[(gy + 1) * W + RU_GX]=255
		elif [[ $RESULT == lose ]] && ((ru_t >= 2 && ru_t <= 3)); then
			sprite 24 $((gy + 1)) RU_PAL "${RU_FLASH[@]}"
		elif [[ $RESULT == lose ]] && ((ru_t == 4)); then
			sprite 24 $((gy + 1)) RU_PAL "${RU_FLASH2[@]}"
		fi
	fi

	# smoke puffs drift up and fade
	for ((i = 0; i < ${#ru_puffs[@]}; i++)); do
		read -r x y a <<<"${ru_puffs[i]}"
		((ru_t > 3 && ru_t % 2)) && ((a++)) && ((a % 2)) && ((y--))
		((a % 3 == 0 && ru_t > 3)) && ((x++))
		ru_puffs[i]="$x $y $a"
		((a > 10 || y < 1 || x > 27)) && continue
		((a < 4)) && c=252 || { ((a < 7)) && c=247 || c=242; }
		rect "$x" "$y" 2 2 "$c"
	done

	# chamber strip: bullet in 0, cursor over the chamber under the hammer
	for ((k = 0; k < 6; k++)); do
		x=$((12 + k * 3))
		if ((k == 0)); then
			if [[ $ru_phase == fire && $RESULT == lose ]] && ((ru_t >= 2)); then
				rect "$x" 10 2 2 94                     # spent
			elif [[ $ru_phase == open ]] && ((ru_t >= 6)); then
				rect "$x" 10 2 2 236                    # ejected
			else
				rect "$x" 10 2 2 178; P[10 * W + x]=220
			fi
		else
			rect "$x" 10 2 2 236
		fi
	done
	[[ $ru_phase != open ]] && rect $((12 + ru_c * 3)) 9 2 1 255

	# clean: casings drop out of the open cylinder one after another
	if [[ $ru_phase == open ]]; then
		for ((k = 0; k < 6; k++)); do
			y=$((cy + 2 + ru_t - 6 - k * 3))
			((y < cy + 2 || y > 12)) && continue
			x=$((RU_GX + 4 + k))
			P[y * W + x]=220
			((y + 1 <= 12)) && P[(y + 1) * W + x]=178
		done
	fi
}
