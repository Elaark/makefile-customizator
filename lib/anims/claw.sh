# ---- animation: claw machine ----
# The claw sweeps over a pile of prizes, steered by the joystick on the
# control panel. At the end it goes down and closes on a prize: it drops it
# in the chute on success, loses it on the way up on failure. For clean the
# pile empties out.

ANIM_TITLE="CLAW MACHINE"
WIN_MSG="★ PRIZE! ★" LOSE_MSG="SO CLOSE..." CLEAN_MSG="CLEANED"
W=28 H=16 MSG_LINE=3

declare -A CL_PAL=([C]=250 [c]=244)
CL_OPEN=("...c..." ".CCCCC." "C.....C" "C.....C")
CL_HALF=("...c..." ".CCCCC." ".C...C." ".C...C.")
CL_SHUT=("...c..." ".CCCCC." ".C...C." ".C...C." "..C.C..")
CL_COLORS=(196 33 46 201 51 208 141 220 39 213 118)
CL_GRAB_X=7 CL_CHUTE_X=20 CL_TOP=3 CL_LOW=5

anim_init() {
	local x i=0
	cl_px=() cl_py=() cl_pc=() cl_alive=()
	for x in 1 4 7 10 13 16 2 5 8 11 14; do
		cl_px+=($x)
		((i < 6)) && cl_py+=(10) || cl_py+=(7)
		cl_pc+=(${CL_COLORS[i]})
		cl_alive+=(1)
		((i++))
	done
	cl_target=8             # the prize at (8, 7), right under the grab spot
	cl_x=2 cl_y=$CL_TOP cl_dx=1 cl_grip=0 cl_held=0
	cl_phase=sweep cl_t=0 cl_drop_y=-1 cl_drop_x=0 cl_bounce=0 cl_moved=0
}

prize() {               # x y color: a round capsule with a highlight
	rect $(($1 + 1)) "$2" 1 3 "$3"
	rect "$1" $(($2 + 1)) 3 1 "$3"
	P[($2 + 1) * W + $1 + 1]=231
}

anim_frame() {
	local i x y c

	cl_moved=0
	case $cl_phase in
		sweep)
			if ((frame % 2 == 0)); then
				((cl_x += cl_dx)) && cl_moved=$cl_dx
				((cl_x <= 1 || cl_x >= 18)) && ((cl_dx = -cl_dx))
			fi
			if [[ -n $RESULT ]]; then
				[[ $RESULT == clean ]] && cl_phase=empty || cl_phase=goto
			fi
			;;
		goto)
			((cl_x < CL_GRAB_X)) && ((cl_x++)) && cl_moved=1
			((cl_x > CL_GRAB_X)) && ((cl_x--)) && cl_moved=-1
			((cl_x == CL_GRAB_X)) && cl_phase=down
			;;
		down)
			((frame % 2)) && ((cl_y++))
			((cl_y == CL_LOW)) && cl_phase=grab cl_t=0
			;;
		grab)
			((cl_t++))
			((cl_t == 2)) && cl_grip=1
			((cl_t == 4)) && cl_grip=2 cl_held=1 cl_alive[cl_target]=0
			((cl_t == 6)) && cl_phase=up
			;;
		up)
			((frame % 2)) && ((cl_y--))
			if [[ $RESULT == lose ]] && ((cl_held && cl_y == 4)); then
				cl_held=0 cl_grip=0             # slips out of the claw
				cl_drop_x=$((cl_x + 2)) cl_drop_y=$((cl_y + 2))
			fi
			((cl_y == CL_TOP)) && cl_phase=carry
			;;
		carry)
			if ((cl_drop_y >= 0)); then         # lost prize falls back, bounces
				if ((cl_drop_y < cl_py[cl_target])); then
					((cl_drop_y++))
				elif ((cl_bounce < 2)); then
					((cl_bounce++))
					((cl_bounce == 1)) && ((cl_drop_y--))
				else
					cl_drop_y=-1 cl_alive[cl_target]=1
				fi
			elif [[ $RESULT == lose ]]; then
				ENDED=1
			elif ((cl_x < CL_CHUTE_X)); then
				((cl_x++)) && cl_moved=1
			else
				cl_held=0 cl_grip=0 cl_phase=chute cl_t=0
				cl_drop_x=$((cl_x + 2)) cl_drop_y=$((cl_y + 2))
			fi
			;;
		chute)
			((cl_t++))
			((cl_drop_y >= 0)) && ((cl_drop_y++))
			((cl_drop_y > 10)) && cl_drop_y=-1
			((cl_t > 16)) && ENDED=1
			;;
		empty)
			if ((frame % 2 == 0)); then
				for ((i = ${#cl_alive[@]} - 1; i >= 0; i--)); do
					((cl_alive[i])) && { cl_alive[i]=0; break; }
				done
				((i < 0)) && ENDED=1
			fi
			;;
	esac

	canvas_clear -1
	cabinet 28 14
	rect 1 1 26 12 "$T_SCREEN"          # glass, with two reflections
	for ((i = 0; i < 5; i++)); do
		P[(2 + i) * W + 23 - i]=236; P[(3 + i) * W + 25 - i]=235
	done
	rect 1 1 26 1 240                   # rail
	rect 20 7 1 6 245                   # chute
	rect 21 12 5 1 232
	for ((i = 0; i < ${#cl_px[@]}; i++)); do
		((cl_alive[i])) && prize "${cl_px[i]}" "${cl_py[i]}" "${cl_pc[i]}"
	done

	rect $((cl_x + 2)) 1 3 1 252        # carriage and cable
	for ((y = 2; y < cl_y; y++)); do P[y * W + cl_x + 3]=245; done
	case $cl_grip in
		0) sprite "$cl_x" "$cl_y" CL_PAL "${CL_OPEN[@]}" ;;
		1) sprite "$cl_x" "$cl_y" CL_PAL "${CL_HALF[@]}" ;;
		*) sprite "$cl_x" "$cl_y" CL_PAL "${CL_SHUT[@]}" ;;
	esac
	if ((cl_held)); then                # carried prize wobbles a little
		x=$((cl_x + 2))
		[[ $cl_phase == carry ]] && ((frame / 2 % 2)) && x=$((x + 1))
		((x > cl_x + 2)) && x=$((cl_x + 2))
		prize "$x" $((cl_y + 2)) "${cl_pc[cl_target]}"
	fi
	((cl_drop_y >= 0)) && prize $((cl_drop_x)) "$cl_drop_y" "${cl_pc[cl_target]}"

	# twinkles at the chute once the prize is in
	if [[ $cl_phase == chute ]] && ((cl_drop_y < 0)); then
		for x in 21 23 25; do
			y=$((8 + (x + cl_t) % 3))
			((((x + cl_t) / 2) % 2)) && c=231 || c=$T_WIN
			P[y * W + x]=$c
		done
	fi

	# control panel: joystick follows the claw, button lights when grabbing
	rect 1 14 26 2 "$T_BASE"
	P[15 * W + 6]=240
	P[14 * W + 6 + cl_moved]=196
	[[ $cl_phase == grab || $cl_phase == down ]] && c=46 || c=22
	rect 11 15 2 1 "$c"
	rect 15 15 4 1 236                  # coin slot
}
