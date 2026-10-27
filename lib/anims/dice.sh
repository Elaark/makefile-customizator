# ---- animation: dice ----
# Two big dice, drawn in 3D, hop and tumble on the felt of an arcade
# cabinet while the build runs. At the end they settle: double six on
# success, snake eyes on failure. For clean their faces go blank and they
# fade away.

ANIM_TITLE="DICE"
WIN_MSG="DOUBLE SIX!" LOSE_MSG="SNAKE EYES" CLEAN_MSG="CLEANED"
W=28 H=18 MSG_LINE=4

# A die is 12x12: top face (T), right side (S) and a 10x10 front face (F)
DI_SHAPE=(
	"..TTTTTTTTTS" ".TTTTTTTTTSS" "FFFFFFFFFFSS" "FFFFFFFFFFSS"
	"FFFFFFFFFFSS" "FFFFFFFFFFSS" "FFFFFFFFFFSS" "FFFFFFFFFFSS"
	"FFFFFFFFFFSS" "FFFFFFFFFFSS" "FFFFFFFFFFS." "FFFFFFFFFF.."
)
declare -A DI_LIT=([T]=255 [F]=252 [S]=245)     # light from above
declare -A DI_TURN=([T]=246 [F]=255 [S]=250)    # mid-tumble
# 2x2 pip positions on the front face, per face (0 = blank)
DI_PIPS=(
	"" "4,4" "1,1 7,7" "1,1 4,4 7,7" "1,1 7,1 1,7 7,7"
	"1,1 7,1 4,4 1,7 7,7" "1,1 1,4 1,7 7,1 7,4 7,7"
)
DI_HOP=(0 1 1 1 0 0 0 0)            # hop height while rolling, per frame
DI_SETTLE=(1 1 1 0 1 0 0 0 0)       # last bounces once the result is known
DI_REST=2                           # top row of a die resting on the felt

anim_init() {
	di_face=(3 5) di_t=-1 di_fade=0
}

die() {                 # x y face palette
	local pip c=16
	sprite "$1" "$2" "$4" "${DI_SHAPE[@]}"
	(($3 == 1)) && c=160
	for pip in ${DI_PIPS[$3]}; do
		rect $(($1 + ${pip%,*})) $(($2 + 2 + ${pip#*,})) 2 2 "$c"
	done
}

anim_frame() {
	local i x y h n=${#DI_SETTLE[@]} pal face

	if [[ -n $RESULT ]]; then
		((di_t++))
		if [[ $RESULT == clean ]]; then
			((di_t > 4 && di_fade < 12)) && ((di_fade++))
			((di_fade >= 12)) && ENDED=1
		else
			((di_t > n + 6)) && ENDED=1
		fi
	fi

	canvas_clear -1
	cabinet 28 16
	rect 1 1 26 14 22                       # felt
	rect 2 2 24 1 28                        # table markings
	rect 2 14 24 1 28

	for i in 0 1; do
		x=$((1 + i * 13))
		if ((di_t < 0)); then               # rolling: hop and tumble
			h=${DI_HOP[(frame + i * 3) % 8]}
			(((frame + i) % 3 == 0)) && di_face[i]=$((RANDOM % 6 + 1))
			pal=DI_LIT
			((h > 0 && (frame + i) % 2)) && pal=DI_TURN
			face=${di_face[i]}
		elif ((di_t < n)); then             # settling bounces
			h=${DI_SETTLE[di_t]}
			pal=DI_LIT
			((h > 0)) && pal=DI_TURN && ((di_t % 2 == 0)) && di_face[i]=$((RANDOM % 6 + 1))
			face=${di_face[i]}
			((h == 0)) && face=-1
		else
			h=0 pal=DI_LIT face=-1
		fi
		if ((face < 0)); then               # landed
			case $RESULT in
				win) face=6 ;;
				lose) face=1 ;;
				*) face=0 ;;
			esac
		fi
		y=$((DI_REST - h))
		rect $((x + 1)) 14 10 1 233         # shadow
		die "$x" "$y" "$face" "$pal"
		# clean: the dice fade into the felt from the top down
		((di_fade > 0)) && rect "$x" "$y" 12 "$di_fade" 22
	done

	if [[ $RESULT == win ]] && ((di_t >= n)); then
		for x in 1 13 25; do                # twinkles
			y=$(((x + di_t) % 4 + 1))
			P[y * W + x]=$((((x + di_t) / 2) % 2 ? 231 : T_WIN))
		done
	fi

	panel 16
	((di_t < 0)) && c=46 || c=22
	rect 4 17 3 1 "$c"                      # roll button
}
