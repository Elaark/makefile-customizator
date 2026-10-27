# ---- canvas: pixel grid helpers shared by the animations ----
# P holds one 256-color code per pixel (-1 = terminal background), W x H.

P=()

canvas_clear() {        # color
	local i n=$((W * H))
	for ((i = 0; i < n; i++)); do P[i]=$1; done
}

rect() {                # x y w h color
	local x y
	for ((y = $2; y < $2 + $4; y++)); do
		for ((x = $1; x < $1 + $3; x++)); do P[y * W + x]=$5; done
	done
}

# Draws rows of characters: '.' is transparent, any other character is
# looked up in the associative array named by palette. Clipped to the grid.
sprite() {              # x y palette row...
	local x0=$1 y=$2 x row ch
	local -n pal=$3
	shift 3
	for row; do
		if ((y >= 0 && y < H)); then
			for ((x = 0; x < ${#row}; x++)); do
				ch=${row:x:1}
				[[ $ch == . ]] && continue
				((x0 + x >= 0 && x0 + x < W)) && P[y * W + x0 + x]=${pal[$ch]}
			done
		fi
		((y++))
	done
}

# Arcade cabinet: body with chasing bulbs around it, base row below if room.
cabinet() {             # width height
	local cw=$1 ch=$2 x y c
	for ((y = 1; y < ch - 1; y++)); do
		c=$T_BODY
		((y == 1)) && c=$T_BODY_HI
		((y == ch - 2)) && c=$T_BODY_LO
		for ((x = 1; x < cw - 1; x++)); do P[y * W + x]=$c; done
	done
	bulb_n=0
	for ((x = 0; x < cw; x++)); do bulb "$x" 0; done
	for ((y = 1; y < ch - 1; y++)); do bulb $((cw - 1)) "$y"; done
	for ((x = cw - 1; x >= 0; x--)); do bulb "$x" $((ch - 1)); done
	for ((y = ch - 2; y > 0; y--)); do bulb 0 "$y"; done
	if ((ch < H)); then
		for ((x = 1; x < cw - 1; x++)); do P[ch * W + x]=$T_BASE; done
	fi
}

bulb() {                # x y
	local c
	if ((ENDED)); then
		case $RESULT in
			win) c=$T_WIN ;;
			lose) c=$T_DEAD ;;
			*) c=$T_BULB_ON ;;
		esac
	else
		(((bulb_n + frame / 3) % 4 == 0)) && c=$T_BULB_ON || c=$T_BULB_OFF
	fi
	P[$2 * W + $1]=$c
	bulb_n=$((bulb_n + 1))
}

# Moves variable $1 towards $2 on a loop of length $3, at most $4 per call,
# in direction $5 (1 or -1), slowing down near the end. Succeeds on arrival.
approach() {
	local -n v=$1
	local d s
	d=$((($5 * ($2 - v) % $3 + 2 * $3) % $3))
	s=$((d / 4 + 1))
	((s > $4)) && s=$4
	((s > d)) && s=$d
	v=$(((v + $5 * s + $3) % $3))
	((d == s))
}
