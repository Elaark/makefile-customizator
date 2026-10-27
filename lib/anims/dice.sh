# ---- animation: dice ----
# A dice cup rattles on the table while the build runs. At the end it tips
# over and two dice tumble out, bouncing and spinning: double six on
# success, snake eyes on failure. For clean they come out blank and roll
# off the table.

ANIM_TITLE="DICE"
WIN_MSG="DOUBLE SIX!" LOSE_MSG="SNAKE EYES" CLEAN_MSG="CLEANED"
W=30 H=16 MSG_LINE=3

declare -A DI_PAL=([G]=178 [L]=130 [W]=173 [D]=94 [K]=58)
DI_CUP=(
	"GGGGGGG" "LLWLLLD" "LLWLLLD" "LLWLLLD"
	"LLWLLLD" "LLLLLLD" "LLLLLLD" "GGGGGGG"
)
DI_CUP_DOWN=(
	"KGLLLLG" "KGWWWLG" "KGLLLLG" "KGLLLLG" "KGLLLDG" "KGDDDDG"
)
# 2x2 pip positions inside a 10x10 die, per face (0 = blank)
DI_PIPS=(
	"" "4,4" "1,1 7,7" "1,1 4,4 7,7" "1,1 7,1 1,7 7,7"
	"1,1 7,1 4,4 1,7 7,7" "1,1 1,4 1,7 7,1 7,4 7,7"
)
# height above the floor at each step of a throw: bounces get lower
DI_HOP=(1 2 3 3 2 1 0 1 2 1 0 1 0 0)
DI_FLOOR=4              # top row of a die resting on the felt (rows 4-13)

anim_init() {
	di_phase=shake di_t=0
	di_face=(3 5) di_x=(10 10)
	di_final=(0 0)
}

die() {                 # x y face turned
	local x=$1 y=$2 pip c=16 face=255 edge=250
	(($4)) && face=252 edge=246                     # mid-roll shading
	rect "$x" "$y" 10 10 "$face"
	rect $((x + 9)) "$y" 1 10 "$edge"
	rect "$x" $((y + 9)) 10 1 "$edge"
	P[y * W + x]=22; P[y * W + x + 9]=22             # rounded corners
	P[(y + 9) * W + x]=22; P[(y + 9) * W + x + 9]=22
	(($3 == 1)) && c=160
	for pip in ${DI_PIPS[$3]}; do
		rect $((x + ${pip%,*})) $((y + ${pip#*,})) 2 2 "$c"
	done
}

anim_frame() {
	local i x y t h jx=0 jy=0 n=${#DI_HOP[@]} target

	case $di_phase in
		shake)
			jx=$((frame / 2 % 2)) jy=$((frame / 3 % 2))
			if [[ -n $RESULT ]]; then
				di_phase=throw di_t=0
				case $RESULT in
					win) di_final=(6 6) ;;
					lose) di_final=(1 1) ;;
					*) di_final=(0 0) ;;
				esac
			fi
			;;
		throw)
			((di_t++))
			# clean: the dice keep rolling right, off the table
			[[ $RESULT == clean ]] && ((di_t > 3 * n)) && ENDED=1
			[[ $RESULT != clean ]] && ((di_t > n + 2 + 8)) && ENDED=1
			;;
	esac

	canvas_clear "$T_BODY"                  # table rail
	rect 1 1 28 14 22                       # felt
	rect 12 2 16 1 28                       # table marking
	rect 27 2 1 4 28

	if [[ $di_phase == shake ]]; then
		sprite $((3 + jx)) $((6 + jy)) DI_PAL "${DI_CUP[@]}"
		if ((frame % 6 < 3)); then          # rattle marks
			P[5 * W + 2]=250; P[4 * W + 3]=250
			P[5 * W + 11]=250; P[4 * W + 10]=250
		fi
		return
	fi
	sprite 1 8 DI_PAL "${DI_CUP_DOWN[@]}"

	for i in 0 1; do
		t=$((di_t - 2 * i))                 # the second die follows
		((t < 0)) && continue
		if [[ $RESULT == clean ]]; then
			x=$((8 + t * 2 + i * 10))
			((x >= W - 1)) && continue
			h=${DI_HOP[t % n]}
		else
			target=$((8 + i * 10))
			x=$((8 + (target - 8) * (t < n ? t : n) / n))
			((t < n)) && h=${DI_HOP[t]} || h=0
		fi
		y=$((DI_FLOOR - h))
		rect $((x + 1)) 14 8 1 28           # shadow
		if [[ $RESULT != clean ]] && ((t >= n)); then
			die "$x" "$y" "${di_final[i]}" 0
		else
			((t % 2 == 0)) && di_face[i]=$((RANDOM % 6 + 1))
			[[ $RESULT == clean ]] && di_face[i]=0
			die "$x" "$y" "${di_face[i]}" $((t % 2))
		fi
	done

	# a few twinkles around the double six
	if [[ $RESULT == win ]] && ((di_t > n + 2)); then
		for x in 9 19 28; do
			y=$(((x + di_t) % 3 + 2))
			c=$(((di_t + x) % 4 < 2 ? 230 : 255))
			((x < W - 1)) && P[y * W + x]=$c
		done
	fi
}
