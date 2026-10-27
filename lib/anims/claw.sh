# ---- animation: claw machine ----
# The claw sweeps over a pile of prizes, then goes down and grabs one: it
# drops it in the chute on success, loses it on the way up on failure.
# For clean the pile empties out.

ANIM_TITLE="CLAW MACHINE"
WIN_MSG="★ PRIZE! ★" LOSE_MSG="SO CLOSE..." CLEAN_MSG="CLEANED"
W=28 H=14 MSG_LINE=3

declare -A CL_PAL=([C]=250)
CL_OPEN=("..CC.." "CCCCCC" "C....C" "C....C")
CL_SHUT=("..CC.." "CCCCCC" ".C..C." ".C..C.")
CL_COLORS=(196 33 46 201 51 208 141 220)
CL_GRAB_X=9 CL_CHUTE_X=20 CL_TOP=3 CL_LOW=6

anim_init() {
	local i x
	cl_px=() cl_py=() cl_pc=() cl_alive=()
	for x in 2 4 6 8 10 12 14 16 18 3 5 7 9 11 13 15 17; do
		i=${#cl_px[@]}
		cl_px+=($x)
		((i < 9)) && cl_py+=(10) || cl_py+=(8)
		cl_pc+=(${CL_COLORS[i % 8]})
		cl_alive+=(1)
	done
	cl_target=13            # the prize at (11, 8), right under the grab spot
	cl_x=2 cl_y=$CL_TOP cl_dx=1 cl_shut=0 cl_held=0
	cl_phase=sweep cl_t=0 cl_drop_y=-1 cl_drop_x=0
}

anim_frame() {
	local i x y

	case $cl_phase in
		sweep)
			if ((frame % 2 == 0)); then
				((cl_x += cl_dx))
				((cl_x <= 2 || cl_x >= 18)) && ((cl_dx = -cl_dx))
			fi
			if [[ -n $RESULT ]]; then
				[[ $RESULT == clean ]] && cl_phase=empty || cl_phase=goto
			fi
			;;
		goto)
			((cl_x < CL_GRAB_X)) && ((cl_x++))
			((cl_x > CL_GRAB_X)) && ((cl_x--))
			((cl_x == CL_GRAB_X)) && cl_phase=down
			;;
		down)
			((frame % 2)) && ((cl_y++))
			((cl_y == CL_LOW)) && cl_phase=grab cl_t=0
			;;
		grab)
			if ((++cl_t == 4)); then
				cl_shut=1 cl_held=1 cl_alive[cl_target]=0 cl_phase=up
			fi
			;;
		up)
			((frame % 2)) && ((cl_y--))
			if [[ $RESULT == lose ]] && ((cl_held && cl_y == 4)); then
				cl_held=0 cl_shut=0             # slips out of the claw
				cl_drop_x=$((cl_x + 2)) cl_drop_y=$((cl_y + 2))
			fi
			((cl_y == CL_TOP)) && cl_phase=carry
			;;
		carry)
			if ((cl_drop_y >= 0)); then         # lost prize falls back
				((cl_drop_y < cl_py[cl_target])) && ((cl_drop_y++)) || {
					cl_drop_y=-1 cl_alive[cl_target]=1
				}
			elif [[ $RESULT == lose ]]; then
				ENDED=1
			elif ((cl_x < CL_CHUTE_X)); then
				((cl_x++))
			else
				cl_held=0 cl_shut=0 cl_phase=chute
				cl_drop_x=$((cl_x + 2)) cl_drop_y=$((cl_y + 2))
			fi
			;;
		chute)
			((cl_drop_y++))
			((cl_drop_y > 11)) && cl_drop_y=-1 ENDED=1
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
	cabinet 28 13
	rect 1 1 26 11 "$T_SCREEN"          # glass
	rect 1 1 26 1 240                   # rail
	rect 20 7 1 5 245                   # chute
	rect 21 11 5 1 232
	for ((i = 0; i < ${#cl_px[@]}; i++)); do
		((cl_alive[i])) && rect "${cl_px[i]}" "${cl_py[i]}" 2 2 "${cl_pc[i]}"
	done
	rect $((cl_x + 1)) 1 4 1 252        # carriage and cable
	for ((y = 2; y < cl_y; y++)); do P[y * W + cl_x + 2]=245; done
	if ((cl_shut)); then
		sprite "$cl_x" "$cl_y" CL_PAL "${CL_SHUT[@]}"
	else
		sprite "$cl_x" "$cl_y" CL_PAL "${CL_OPEN[@]}"
	fi
	((cl_held)) && rect $((cl_x + 2)) $((cl_y + 2)) 2 2 "${cl_pc[cl_target]}"
	((cl_drop_y >= 0)) && rect "$cl_drop_x" "$cl_drop_y" 2 2 "${cl_pc[cl_target]}"
}
