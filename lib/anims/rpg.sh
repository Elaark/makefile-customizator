# ---- animation: rpg ----
# A knight fights a slime while the build runs, striking as logs come in.
# On success the final blow slays the slime, on failure the slime crushes
# the knight. For clean the slime just melts away.

ANIM_TITLE="QUEST"
WIN_MSG="VICTORY!" LOSE_MSG="YOU DIED" CLEAN_MSG="CLEANED"
W=30 H=14 MSG_LINE=3

declare -A RP_PAL=(
	[H]=250 [S]=223 [K]=16 [B]=33 [L]=94 [W]=255 [Y]=178
	[G]=34 [g]=28 [h]=120 [E]=255
)
declare -A RP_HURT=(
	[H]=210 [S]=210 [K]=16 [B]=203 [L]=167 [W]=255 [Y]=210
	[G]=210 [g]=203 [h]=224 [E]=255
)
RP_IDLE=(
	"......W." "..HHH.W." ".HHHHHW." ".HSKS.W." "..SSS.Y."
	".BBBBBS." "BBBBBB.." ".BBBB..." ".L..L..."
)
RP_ATTACK=(
	"........." "..HHH...." ".HHHHH..." ".HSKS...." "..SSS...."
	".BBBBSYWWW" "BBBBBB...." ".BBBB....." ".L..L....."
)
RP_DEAD=("HH.BBBB.L" "HSSBBBBLL")
RP_SLIME=(
	"...GGGG..." "..GhhGGG.." ".GGGGGGGG." ".GKEGGKEG."
	"GGGGGGGGGG" "GGGGggGGGG" ".gggggggg."
)

anim_init() {
	rp_hp=100 rp_hero=10 rp_atk=-1 rp_cool=0 rp_hurt=0 rp_hero_hurt=0
	rp_mx=18 rp_melt=0 rp_phase=fight rp_t=0
}

anim_frame() {
	local x y i pal bar

	case $rp_phase in
		fight)
			((rp_cool++))
			if ((rp_atk < 0)); then
				if [[ -n $RESULT ]]; then
					case $RESULT in
						win) rp_phase=finish rp_atk=0 ;;
						lose) rp_phase=lunge rp_t=0 ;;
						*) rp_phase=melt rp_t=0 ;;
					esac
				elif ((NEW_LOGS > 0 && rp_cool >= 12 || rp_cool >= 40)); then
					rp_atk=0 rp_cool=0          # strike as the build moves on
				fi
			fi
			;;
		finish)
			((rp_atk < 0)) && rp_phase=melt rp_t=0
			;;
		lunge)
			((rp_t++))
			if ((rp_t <= 6)); then
				((rp_mx--))
			elif ((rp_t == 7)); then
				rp_hero=0 rp_hero_hurt=3
			elif ((rp_t <= 13)); then
				((rp_mx++))
			else
				ENDED=1
			fi
			;;
		melt)
			((rp_t++ % 2)) && ((rp_melt++))
			((rp_melt >= 7)) && ENDED=1
			;;
	esac
	if ((rp_atk >= 0)); then
		if ((++rp_atk == 3)); then              # the blow lands
			rp_hurt=3
			[[ $rp_phase == finish ]] && rp_hp=0 || rp_hp=$((rp_hp - (rp_hp > 15 ? rp_hp / 5 : 0)))
		fi
		((rp_atk >= 6)) && rp_atk=-1
	fi

	canvas_clear "$T_SCREEN"
	rect 0 0 30 1 "$T_BODY"; rect 0 13 30 1 "$T_BODY"
	rect 0 0 1 14 "$T_BODY"; rect 29 0 1 14 "$T_BODY"
	rect 1 11 28 2 238                      # stone floor
	for ((x = 2; x < 27; x += 5)); do P[11 * W + x]=236; P[12 * W + x + 2]=236; done

	rect 2 1 10 1 238                       # health bars
	rect 2 1 "$rp_hero" 1 40
	bar=$(((rp_hp * 10 + 99) / 100))
	rect 18 1 10 1 238
	rect 18 1 "$bar" 1 160

	pal=RP_PAL
	((rp_hero_hurt > 0)) && pal=RP_HURT && ((rp_hero_hurt--))
	if ((rp_hero == 0 && rp_t >= 7)); then
		sprite 3 9 "$pal" "${RP_DEAD[@]}"
	elif ((rp_atk >= 1 && rp_atk <= 4)); then
		sprite 6 2 "$pal" "${RP_ATTACK[@]}"
	else
		sprite 4 2 "$pal" "${RP_IDLE[@]}"
	fi

	if ((rp_melt < 7)); then
		pal=RP_PAL
		((rp_hurt > 0)) && pal=RP_HURT && ((rp_hurt--))
		[[ $rp_phase == melt ]] && pal=RP_HURT
		y=4
		[[ $rp_phase == fight ]] && ((frame / 6 % 2)) && y=5   # idle bounce
		sprite "$rp_mx" $((y + rp_melt)) "$pal" "${RP_SLIME[@]:rp_melt}"
	fi
	if ((rp_atk == 2 || rp_atk == 3)); then  # slash
		for i in 0 1 2; do P[(5 + i) * W + rp_mx + 3 - i]=255; done
	fi
}
