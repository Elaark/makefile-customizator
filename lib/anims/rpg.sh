# ---- animation: rpg ----
# A knight walks into a dungeon and fights a slime while the build runs,
# striking as new logs come in. On success the final blow bursts the slime
# and it drops a coin; on failure the slime leaps onto the knight. For clean
# the slime just melts away.

ANIM_TITLE="QUEST"
WIN_MSG="VICTORY!" LOSE_MSG="YOU DIED" CLEAN_MSG="CLEANED"
W=30 H=16 MSG_LINE=3

declare -A RP_PAL=(
	[H]=250 [S]=223 [K]=16 [B]=33 [L]=94 [W]=255 [Y]=178 [N]=67
	[G]=34 [g]=28 [h]=120 [E]=255
)
declare -A RP_HURT=(
	[H]=210 [S]=210 [K]=16 [B]=203 [L]=167 [W]=255 [Y]=210 [N]=210
	[G]=210 [g]=203 [h]=224 [E]=255
)
RP_IDLE=(
	"......W..." "..HHH.W..." ".HHHHHW..." ".HSKS.W..." "..SSS.Y..."
	"NBBBBBS..." "NBBBBB...." "NBBBB....." ".L..L....."
)
RP_WALK=(
	"......W..." "..HHH.W..." ".HHHHHW..." ".HSKS.W..." "..SSS.Y..."
	"NBBBBBS..." "NBBBBB...." "NBBBB....." "L....L...."
)
RP_ATTACK=(
	".........." "..HHH....." ".HHHHH...." ".HSKS....." "..SSS....."
	"NBBBBSYWWW" "NBBBBB...." "NBBBB....." ".L...L...."
)
RP_VICTORY=(
	".....W...." "..HHHW...." ".HHHHHY..." ".HSKSS...." "..SSS....."
	"NBBBBB...." "NBBBBB...." "NBBBB....." ".L..L....."
)
RP_DEAD=("HH.BBBBB.L" "HSSBBBBBLL")
RP_SLIME=(
	"...GGGG..." "..GhhGGG.." ".GGGGGGGG." ".GKEGGKEG."
	"GGGGGGGGGG" "GGGGggGGGG" ".gggggggg."
)
RP_SQUASH=(
	"..GGGGGG.." ".GhhGGGGG." "GGKEGGKEGG" "GGGGGGGGGG"
	"GGGGggGGGG" "gggggggggg"
)
RP_FLOOR=13             # bottom row where feet rest

anim_init() {
	rp_hp=100 rp_hero=10 rp_atk=-1 rp_cool=0 rp_hurt=0 rp_hero_hurt=0
	rp_hx=-8 rp_mx=18 rp_my=0 rp_melt=0 rp_phase=walk rp_t=0
	rp_coin_y=-1 rp_coin_v=0
	rp_parts=()             # particles: "x y vx vy color", in half pixels
}

burst() {               # x y count color: particles flying up and out
	local i
	for ((i = 0; i < $3; i++)); do
		rp_parts+=("$(($1 * 2)) $(($2 * 2)) $((RANDOM % 7 - 3)) $((-2 - RANDOM % 4)) $4")
	done
}

anim_frame() {
	local x y i c pal vx vy col bar parts=()

	case $rp_phase in
		walk)                                   # the knight walks in
			rp_hx=$((rp_hx + 1))
			((rp_hx >= 3)) && rp_phase=fight
			;;
		fight)
			((rp_cool++))
			if ((rp_atk < 0)); then
				if [[ -n $RESULT ]]; then
					case $RESULT in
						win) rp_phase=finish rp_atk=0 ;;
						lose) rp_phase=leap rp_t=0 ;;
						*) rp_phase=melt rp_t=0 ;;
					esac
				elif ((NEW_LOGS > 0 && rp_cool >= 12 || rp_cool >= 40)); then
					rp_atk=0 rp_cool=0          # strike as the build moves on
				fi
			fi
			;;
		finish)
			if ((rp_atk < 0)); then
				rp_phase=won rp_t=0
				burst $((rp_mx + 5)) 9 12 34
				burst $((rp_mx + 5)) 9 6 120
				rp_coin_y=8 rp_coin_v=-2
			fi
			;;
		won)                                    # the coin bounces, then rests
			((rp_t++))
			if ((rp_coin_y >= 0)); then
				rp_coin_y=$((rp_coin_y + rp_coin_v))
				((rp_coin_v++))
				if ((rp_coin_y >= RP_FLOOR - 1)); then
					rp_coin_y=$((RP_FLOOR - 1))
					((rp_coin_v > 2)) && rp_coin_v=$((-rp_coin_v / 2)) || rp_coin_v=0
				fi
			fi
			((rp_t > 16)) && ENDED=1
			;;
		leap)                                   # the slime jumps on the knight
			((rp_t++))
			if ((rp_t <= 8)); then
				rp_mx=$((18 - rp_t * 10 / 8))
				rp_my=$((-(rp_t * (8 - rp_t)) / 3))
			elif ((rp_t == 9)); then
				rp_hero=0 rp_hero_hurt=4 rp_my=0
				burst $((rp_hx + 4)) 9 8 203
			elif ((rp_t <= 16)); then
				rp_mx=$((rp_mx + 1))
				rp_my=$(((rp_t % 4 < 2) ? -1 : 0))
			else
				rp_my=0
				((rp_t > 22)) && ENDED=1
			fi
			;;
		melt)
			((rp_t++ % 2)) && ((rp_melt++))
			((rp_melt >= 7)) && ENDED=1
			;;
	esac
	if ((rp_atk >= 0)); then
		((rp_atk++))
		if ((rp_atk == 4)); then                # the blow lands
			rp_hurt=3
			if [[ $rp_phase == finish ]]; then
				rp_hp=0
			else
				((rp_hp > 15)) && rp_hp=$((rp_hp - rp_hp / 5))
				burst $((rp_mx + 2)) 8 3 34
			fi
		fi
		((rp_atk >= 7)) && rp_atk=-1
	fi

	# dungeon: brick wall, torch, stone floor
	canvas_clear 235
	for ((y = 2; y < 11; y++)); do
		for ((x = 1; x < 29; x++)); do
			if ((y % 2 == 0)) || (((x + (y / 2 % 2) * 2) % 4 == 0)); then
				c=235
			else
				(((x / 4 + y) % 3)) && c=237 || c=238
			fi
			P[y * W + x]=$c
		done
	done
	rect 14 7 2 2 94                            # torch
	((frame / 4 % 2)) && c=214 || c=208
	rect 14 5 2 2 "$c"
	P[4 * W + 14 + frame / 4 % 2]=226
	rect 1 11 28 4 239                          # floor
	for ((x = 1; x < 29; x += 6)); do rect "$x" 11 1 4 237; done
	rect 1 11 28 1 241
	rect 0 0 30 1 "$T_BODY"; rect 0 15 30 1 "$T_BODY"
	rect 0 0 1 16 "$T_BODY"; rect 29 0 1 16 "$T_BODY"

	# health bars
	rect 1 1 12 1 240; rect 2 1 10 1 236; rect 2 1 "$rp_hero" 1 40
	bar=$(((rp_hp * 10 + 99) / 100))
	rect 17 1 12 1 240; rect 18 1 10 1 236; rect $((28 - bar)) 1 "$bar" 1 160

	# knight
	pal=RP_PAL
	((rp_hero_hurt > 0)) && pal=RP_HURT && ((rp_hero_hurt--))
	y=$((RP_FLOOR - 8))
	if ((rp_hero == 0)); then
		sprite "$rp_hx" $((RP_FLOOR - 1)) "$pal" "${RP_DEAD[@]}"
		rect $((rp_hx + 11)) "$RP_FLOOR" 3 1 255            # dropped sword
	elif [[ $rp_phase == walk ]]; then
		if ((frame % 2)); then sprite "$rp_hx" "$y" "$pal" "${RP_WALK[@]}"
		else sprite "$rp_hx" "$y" "$pal" "${RP_IDLE[@]}"; fi
	elif [[ $rp_phase == won ]]; then
		sprite "$rp_hx" "$y" "$pal" "${RP_VICTORY[@]}"
	elif ((rp_atk >= 3 && rp_atk <= 5)); then
		sprite $((rp_hx + 3)) "$y" "$pal" "${RP_ATTACK[@]}"
	elif ((rp_atk >= 1 && rp_atk <= 6)); then
		sprite $((rp_hx + 1 + (rp_atk == 2 || rp_atk == 6))) "$y" "$pal" "${RP_WALK[@]}"
	else
		sprite "$rp_hx" "$y" "$pal" "${RP_IDLE[@]}"
	fi

	# slime: bounces while idle, pushed back by hits
	if [[ $rp_phase != won ]] && ((rp_melt < 7)); then
		pal=RP_PAL
		((rp_hurt > 0)) && pal=RP_HURT && ((rp_hurt--))
		[[ $rp_phase == melt ]] && pal=RP_HURT
		x=$rp_mx
		((rp_atk == 4 || rp_atk == 5)) && x=$((x + 1))
		if [[ $rp_phase == fight ]] && ((frame / 5 % 2)); then
			sprite "$x" $((RP_FLOOR - 5 + rp_my)) "$pal" "${RP_SQUASH[@]}"
		else
			sprite "$x" $((RP_FLOOR - 6 + rp_my + rp_melt)) "$pal" "${RP_SLIME[@]:rp_melt}"
		fi
	fi
	if ((rp_atk == 3 || rp_atk == 4)); then     # slash arc
		for i in 0 1 2 3; do P[(6 + i) * W + rp_mx + 1 + (i < 2 ? i : 3 - i)]=231; done
	fi

	# particles, with gravity
	for i in "${rp_parts[@]}"; do
		read -r x y vx vy col <<<"$i"
		x=$((x + vx)) y=$((y + vy)) vy=$((vy + 1))
		((y / 2 > RP_FLOOR || x < 2 || x / 2 > 28)) && continue
		parts+=("$x $y $vx $vy $col")
		P[y / 2 * W + x / 2]=$col
	done
	rp_parts=("${parts[@]}")

	if ((rp_coin_y >= 0)); then
		rect $((rp_mx + 4)) "$rp_coin_y" 2 2 178
		P[rp_coin_y * W + rp_mx + 4]=220
	fi
}
