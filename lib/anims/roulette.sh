# ---- animation: roulette ----
# A roulette wheel seen at an angle: the pockets turn one way, the ball
# runs the other way on the rim. At the end the ball slows down, drops into
# a red pocket on success or the green zero on failure, and rides the wheel
# until it stops. For clean the wheel turns backwards, without a ball, and
# its pockets empty out.

ANIM_TITLE="ROULETTE"
WIN_MSG="★ RED WINS ★" LOSE_MSG="ZERO! HOUSE WINS" CLEAN_MSG="CLEANED"
W=30 H=14 MSG_LINE=3

# Wheel geometry, computed once: per pixel its layer (0 outside, 1 rim,
# 2 pockets, 3 cone, 4 hub), its pocket slot (0-36) and spoke sector (0-7);
# then 72 ball positions on the rim and 37 pocket centers.
eval "$(awk -v W=$W -v H=$H 'BEGIN {
	cx = 15; cy = 7; rx = 14.4; ry = 6.8; pi = atan2(0, -1)
	for (y = 0; y < H; y++) for (x = 0; x < W; x++) {
		dx = (x + .5 - cx) / rx; dy = (y + .5 - cy) / ry; r = sqrt(dx * dx + dy * dy)
		a = atan2(dy, dx); if (a < 0) a += 2 * pi
		l = r > 1 ? 0 : r > .84 ? 1 : r > .58 ? 2 : r > .32 ? 3 : 4
		L = L " " l; S = S " " int(a / (2 * pi) * 37) % 37; O = O " " int(a / (2 * pi) * 8) % 8
	}
	for (i = 0; i < 72; i++) {
		a = i / 72 * 2 * pi
		TX = TX " " int(cx + .92 * rx * cos(a)); TY = TY " " int(cy + .92 * ry * sin(a))
	}
	for (i = 0; i < 37; i++) {
		a = (i + .5) / 37 * 2 * pi
		PX = PX " " int(cx + .71 * rx * cos(a)); PY = PY " " int(cy + .71 * ry * sin(a))
	}
	print "RO_LAYER=(" L ")\nRO_SLOT=(" S ")\nRO_SPOKE=(" O ")"
	print "RO_TX=(" TX ")\nRO_TY=(" TY ")\nRO_PX=(" PX ")\nRO_PY=(" PY ")"
}')"

anim_init() {
	ro_rot=$((RANDOM % 37))     # wheel rotation, in pockets
	ro_ball=$((RANDOM % 72))    # ball angle, in 72ths of a turn
	ro_bspeed=3 ro_wheel=2      # ball steps per frame, frames per wheel step
	ro_dir=1
	((CLEAN)) && ro_dir=-1
	ro_pocket=-1 ro_slow=0 ro_fade=-1
}

ro_color() {            # pocket -> c
	if (($1 == 0)); then c=28; elif (($1 % 2)); then c=160; else c=233; fi
}

anim_frame() {
	local i x y c p

	# the wheel turns one pocket every ro_wheel frames
	((frame % ro_wheel == 0)) && ro_rot=$(((ro_rot + ro_dir + 37) % 37))

	if [[ -n $RESULT ]]; then
		((ro_slow++))
		if [[ $RESULT == clean ]]; then
			((ro_slow % 6 == 0 && ro_wheel < 8)) && ((ro_wheel++))
			((ro_wheel >= 8)) && ((ro_fade++))
			((ro_fade > 18)) && ENDED=1
		elif ((ro_pocket < 0)); then
			# ball and wheel slow down, then the ball drops into the first
			# fitting pocket (it still passes about one pocket per frame)
			((ro_slow % 8 == 0 && ro_bspeed > 2)) && ((ro_bspeed--))
			((ro_slow % 8 == 4 && ro_wheel < 4)) && ((ro_wheel++))
			if ((ro_bspeed == 2)); then
				p=$(((ro_ball * 37 / 72 + ro_rot) % 37))
				if [[ $RESULT == lose ]]; then
					((p == 0)) && ro_pocket=$p ro_slow=0
				else
					((p % 2)) && ro_pocket=$p ro_slow=0
				fi
			fi
		else
			((ro_slow % 5 == 0 && ro_wheel < 9)) && ((ro_wheel++))
			((ro_wheel >= 9)) && ENDED=1
		fi
	fi
	((ro_pocket < 0)) && ro_ball=$(((ro_ball - ro_bspeed + 72) % 72))

	canvas_clear 22                     # felt
	for ((i = 0; i < W * H; i++)); do
		case ${RO_LAYER[i]} in
			0) continue ;;
			1)                          # rim: lit from above
				((i / W < 7)) && c=137 || c=94
				;;
			2)
				p=$(((RO_SLOT[i] + ro_rot) % 37))
				ro_color "$p"
				# clean: pockets go grey, sweeping around the wheel
				((ro_fade >= 0 && RO_SLOT[i] * 18 / 37 <= ro_fade)) && c=240
				;;
			3)
				(((RO_SPOKE[i] + ro_rot / 2) % 4 == 0)) && c=178 || c=130
				;;
			4)
				c=178
				;;
		esac
		P[i]=$c
	done
	P[6 * W + 14]=220; P[6 * W + 15]=230  # hub highlight

	if [[ $RESULT != clean || ro_fade -lt 0 ]] && ((!CLEAN)); then
		if ((ro_pocket < 0)); then
			x=${RO_TX[ro_ball]} y=${RO_TY[ro_ball]}
		else
			i=$(((ro_pocket - ro_rot + 37) % 37))
			x=${RO_PX[i]} y=${RO_PY[i]}
		fi
		P[y * W + x]=255
	fi
}
