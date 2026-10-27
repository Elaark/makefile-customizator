# ---- animation: slot machine ----
# Three reels: 7 7 7 on success, a losing combo on failure,
# a backwards spin onto empty windows for clean.

ANIM_TITLE="SLOTS"
WIN_MSG="★ JACKPOT ★" LOSE_MSG="GAME OVER" CLEAN_MSG="CLEANED"
W=30 H=14 MSG_LINE=3

# '.' is the reel background (depends on the row, for a curved look)
declare -A SL_PAL=(
	[R]=196 [D]=124 [W]=231 [Y]=178 [O]=172 [G]=34 [C]=51 [N]=31
)
SL_SYMBOLS=(
	"RRRRRRR RDDDDRD ....RD. ...RD.. ..RD... ..RD... ..RD..."
	"....GG. ...G.G. ..G..G. .G...G. WRR.WRR RRD.RRD .D...D."
	"...O... ..YYY.. .YWYYO. .YWYYO. .YYYYO. YYYYYYO ...O..."
	"...N... ..NWN.. .NWCCN. NCCCCCN .NCCCN. ..NCN.. ...N..."
	"....... ..YYYY. .YWYYYO YYWYYYO YYYYYO. .OYYO.. ......."
	"....... ....... ....... ....... ....... ....... ......."
)
SL_STRIP=()
for sym in "${SL_SYMBOLS[@]}"; do
	SL_STRIP+=($sym ".......")
done
SL_L=${#SL_STRIP[@]}    # 8 rows per symbol
SL_BG=(250 254 231 231 231 231 231 254 250)

anim_init() {
	sl_off=(3 17 29)
	sl_speed=($SPEED $((SPEED + 1)) $SPEED)
	sl_dir=1
	((CLEAN)) && sl_dir=-1
	sl_stop=-1
}

anim_frame() {
	local i x y wy row ch c ball

	if [[ -n $RESULT ]] && ((sl_stop < 0)); then
		case $RESULT in
			win) sl_target=(0 0 0) ;;      # 7 7 7
			clean) sl_target=(5 5 5) ;;    # empty
			*) sl_target=(1 3 4) ;;
		esac
		sl_stop=0
	fi
	for ((i = 0; i < 3; i++)); do
		((sl_stop >= 0 && i < sl_stop)) && continue
		if ((i == sl_stop)); then
			approach "sl_off[$i]" $(((sl_target[i] * 8 - 1 + SL_L) % SL_L)) "$SL_L" 5 "$sl_dir" &&
				((sl_stop++))
		else
			sl_off[i]=$(((sl_off[i] + sl_dir * sl_speed[i] + SL_L) % SL_L))
		fi
	done
	((sl_stop == 3)) && ENDED=1

	canvas_clear -1
	cabinet 27 13
	for ((wy = 0; wy < 9; wy++)); do
		y=$((wy + 2))
		for ((i = 0; i < 3; i++)); do
			row=${SL_STRIP[(sl_off[i] + wy) % SL_L]}
			for ((x = 0; x < 7; x++)); do
				ch=${row:x:1}
				[[ $ch == . ]] && c=${SL_BG[wy]} || c=${SL_PAL[$ch]}
				P[y * W + 2 + i * 8 + x]=$c
			done
		done
	done
	P[6 * W + 1]=$T_MARK                # payline markers
	P[6 * W + 25]=$T_MARK

	ball=2                              # lever, pulled at start
	((frame < 4 && !CLEAN)) && ball=8
	P[8 * W + 27]=250
	for ((y = ball + 2; y <= 8; y++)); do P[y * W + 28]=250; done
	P[ball * W + 28]=$T_LEVER_HI; P[ball * W + 29]=$T_LEVER
	P[(ball + 1) * W + 28]=$T_LEVER; P[(ball + 1) * W + 29]=$T_LEVER_LO
}
