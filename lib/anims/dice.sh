# ---- animation: dice ----
# Two dice tumble on the felt: double six on success, snake eyes on
# failure, blank faces for clean.

ANIM_TITLE="DICE"
WIN_MSG="DOUBLE SIX!" LOSE_MSG="SNAKE EYES" CLEAN_MSG="CLEANED"
W=28 H=14 MSG_LINE=3

# 2x2 pip positions inside a 10x10 die, per face (0 = blank)
DI_PIPS=(
	""
	"4,4"
	"1,1 7,7"
	"1,1 4,4 7,7"
	"1,1 7,1 1,7 7,7"
	"1,1 7,1 4,4 1,7 7,7"
	"1,1 1,4 1,7 7,1 7,4 7,7"
)

anim_init() {
	di_face=(3 5)
	di_settle=-1
}

die() {                 # x y face
	local x=$1 y=$2 pip c=16
	rect "$x" "$y" 10 10 255
	rect $((x + 9)) "$y" 1 10 250       # shaded edges
	rect "$x" $((y + 9)) 10 1 250
	P[y * W + x]=22; P[y * W + x + 9]=22  # rounded corners
	P[(y + 9) * W + x]=22; P[(y + 9) * W + x + 9]=22
	(($3 == 1)) && c=160
	for pip in ${DI_PIPS[$3]}; do
		rect $((x + ${pip%,*})) $((y + ${pip#*,})) 2 2 "$c"
	done
}

anim_frame() {
	local i bounce=0 jitter=0 every=3

	if [[ -n $RESULT ]] && ((di_settle < 0)); then
		di_settle=0
	fi
	if ((di_settle < 14)); then
		# rolling: faces change, slower and slower once the result is known
		((di_settle >= 0)) && every=$((3 + di_settle / 3)) && ((di_settle++))
		if ((frame % every == 0)); then
			for i in 0 1; do di_face[i]=$((RANDOM % 6 + 1)); done
		fi
		((frame / 2 % 2)) && bounce=-1
		jitter=$((frame / 3 % 2))
	else
		case $RESULT in
			win) di_face=(6 6) ;;
			lose) di_face=(1 1) ;;
			*) di_face=(0 0) ;;
		esac
		ENDED=1
	fi

	canvas_clear -1
	cabinet 28 14
	rect 1 1 26 12 22                   # felt
	rect 4 12 9 1 233                   # shadows
	rect 16 12 9 1 233
	die $((3 + jitter)) $((2 + bounce)) "${di_face[0]}"
	die $((15 - jitter)) $((2 + bounce)) "${di_face[1]}"
}
