#########################
######  STRUCTURE  ######
#########################

SRC_DIR			=	srcs
ASM_SRC_DIR		=	stub_srcs
INC_DIR			=	includes

LIBFT_DIR		= 	libft

BUILD_DIR		=	build
ASM_OBJ_DIR		=	${BUILD_DIR}/asm_obj
OBJ_DIR			=	${BUILD_DIR}/obj
DEP_DIR			=	${BUILD_DIR}/dep

#######################
######  SOURCES  ######
#######################

SRCS 			=	main.c				\
					../stub_srcs/aes.c	\
					data_controller.c	\
					errors.c			\
					file_handling.c		\
					section_slasher.c	\
					segment_slasher.c	\
					stub.c				\
					
HEADERS			=	main.h 				\
					data_controller.h	\
					endian.c			\
					errors.h			\
					file_handling.h		\
					section_slasher.h	\
					segment_slasher.h	\
					stub.h

ASM_SRCS		=	AESEncrypt.s		\
					AESDecrypt.s

STUB_SRCS		=	stub_srcs/main.c 	\
					stub_srcs/aes.c

###########################
######  COMPILATION  ######
###########################

MAKE			=	make
MAKEFLAGS 		+=	--no-print-directory
RED 			=	$(shell tput setaf 1)
GREEN			=	$(shell tput setaf 2)
CYAN			=	$(shell tput setaf 6)
RESET			=	$(shell tput setaf 255)

OBJS			=	${SRCS:%.c=${OBJ_DIR}/%.o}
ASM_OBJS		=	${ASM_SRCS:%.s=${ASM_OBJ_DIR}/%.o}

DEPS			=	${SRCS:%.c=${DEP_DIR}/%.d}
GET_DEP_PATH	=	${@:${OBJ_DIR}/%.o=${DEP_DIR}/.%d}

TEST			=	resources/sample.c
TEST_NAME		=	resources/sample

CC				=	clang
CFLAG			=	-Wall -Werror -Wextra \
					-MMD -MP -g3

ASM_COMPILER	=	nasm
ASM_FLAGS		=	-f elf64 -g
					
X32_FLAGS		=	-m32
X64_FLAGS		=	-m64

MKDIR			=	@mkdir -vp
RM				=	@rm -vrf

NAME			= 	woody_woodpacker
LIBFT_LIB		=	libft.a

STUB_NAME		=	stub

#####################
######  RULES  ######
#####################

all:
	@bash -c "$$SLOT_MACHINE" slot $(MAKE) _all

_all: $(LIBFT_LIB) $(NAME) compile_stub

-include $(DEPS)

$(NAME): $(OBJS) $(ASM_OBJS)
	$(CC) $(CFLAG) $^ -o $@ $(LIBFT_DIR)/$(LIBFT_LIB)

${OBJ_DIR}/%.o: ${SRC_DIR}/%.c
	$(MKDIR) $(dir $@) $(dir $(GET_DEP_PATH))
	$(CC) $(CFLAG) -I$(INC_DIR) -I$(LIBFT_DIR)/$(INC_DIR) \
		-c $< -o $@ \
		-MF $(DEP_DIR)/$(notdir $(basename $<)).d -MT $@

compile_stub: ${STUB_NAME}

$(STUB_NAME): $(STUB_SRCS) $(ASM_OBJS)
	$(CC) $(X64_FLAGS) -g $^ -o $@ 

${ASM_OBJ_DIR}/%.o: $(ASM_SRC_DIR)/%.s
	$(MKDIR) $(dir $@)
	${ASM_COMPILER} $(ASM_FLAGS) $< -o $@
	
basic:
	$(CC) $(X64_FLAGS) $(TEST) -o $(TEST_NAME) 
		
init:
	git submodule init
	git submodule update
		
$(LIBFT_LIB):
	$(MAKE) -C $(LIBFT_DIR)
		
clean:
	@bash -c "$$SLOT_MACHINE" slot --clean $(MAKE) _clean

_clean:
	$(RM) $(BUILD_DIR)
	$(MAKE) clean -C $(LIBFT_DIR)

test:
	$(CC) -Wall -Wextra -Werror -Iincludes/ -g -o compression srcs/bin_compression.c srcs/file_handling.c
	
fclean:
	@bash -c "$$SLOT_MACHINE" slot --clean $(MAKE) _fclean

_fclean: _clean
	rm -rf $(NAME)
	rm -rf $(STUB_NAME)
	$(MAKE) clean -C $(LIBFT_DIR)
	
re: fclean all

.PHONY: init all _all clean _clean fclean _fclean re

############################
######  SLOT MACHINE  ######
############################

# Kept unexpanded with $(value) so the script needs no $$ escaping
define SLOT_MACHINE_SRC
# Runs a command while an arcade pixel-art slot machine spins below its logs.
# 7 7 7 if the command succeeds, GAME OVER if it fails.
# With --clean the reels spin backwards and stop on empty windows.
# Usage: bash -c "$$SLOT_MACHINE" slot [--clean] <command> [args...]
# Env:   NO_SLOT=1      disable the animation
#        SLOT_SPEED=N   reel speed, 1 (slow) .. 6 (fast), default 2
#        SLOT_FPS=N     frames per second, default 25

CLEAN=0
[[ $1 == --clean ]] && { CLEAN=1; shift; }

if [[ ! -t 1 || -n "$NO_SLOT" ]]; then
	exec "$@"
fi

LOG=$(mktemp)
"$@" >"$LOG" 2>&1 &
PID=$!

E=$'\e'
SYNC_ON="$E[?2026h" SYNC_OFF="$E[?2026l"

cleanup() {
	printf '%s' "$SYNC_OFF$E[0m$E[?25h"
	rm -f "$LOG"
}
trap 'kill "$PID" 2>/dev/null; cleanup; echo; exit 130' INT TERM
printf '%s' "$E[?25l"

SPEED=${SLOT_SPEED:-2}
((SPEED < 1)) && SPEED=1
((SPEED > 6)) && SPEED=6
FPS=${SLOT_FPS:-25}
DELAY=$(awk "BEGIN { print 1 / ${FPS} }")

######  SPRITES  ######

# '.' is the reel background (depends on the row, for a curved look)
declare -A COL=(
	[R]=196 [D]=124 [W]=231 [Y]=178 [O]=172 [G]=34 [C]=51 [N]=31
)

SEVEN="RRRRRRR
RDDDDRD
....RD.
...RD..
..RD...
..RD...
..RD..."
CHERRY="....GG.
...G.G.
..G..G.
.G...G.
WRR.WRR
RRD.RRD
.D...D."
BELL="...O...
..YYY..
.YWYYO.
.YWYYO.
.YYYYO.
YYYYYYO
...O..."
DIAMOND="...N...
..NWN..
.NWCCN.
NCCCCCN
.NCCCN.
..NCN..
...N..."
LEMON=".......
..YYYY.
.YWYYYO
YYWYYYO
YYYYYO.
.OYYO..
......."

STRIP=()
for spr in "$SEVEN" "$CHERRY" "$BELL" "$DIAMOND" "$LEMON"; do
	while IFS= read -r line; do STRIP+=("$line"); done <<<"$spr"
	STRIP+=(".......")
done
for ((i = 0; i < 8; i++)); do STRIP+=("......."); done   # empty symbol
NSYM=6
L=${#STRIP[@]}          # 8 rows per symbol
SEVEN_IDX=0
EMPTY_IDX=5

######  MACHINE  ######

# Pixel grid drawn with half blocks: one cell = 2 square pixels.
W=30 HP=14              # 27px machine + lever
FOOT=8                  # title + 7 pixel lines
REEL_BG=(250 254 231 231 231 231 231 254 250)
SHIMMER=(219 213 177 141 135 141 177 213)
TITLE="MAKEFILE SLOTS"
((CLEAN)) && TITLE="MAKEFILE CLEAN"
DIR=1
((CLEAN)) && DIR=-1
off=(3 17 29)
speed=($SPEED $((SPEED + 1)) $SPEED)
P=()

# Border bulbs, listed clockwise so they can chase each other
BULBS=()
for ((x = 0; x < 27; x++)); do BULBS+=($x); done
for ((y = 1; y < 12; y++)); do BULBS+=($((y * W + 26))); done
for ((x = 26; x >= 0; x--)); do BULBS+=($((12 * W + x))); done
for ((y = 11; y > 0; y--)); do BULBS+=($((y * W))); done
NB=${#BULBS[@]}

draw_machine() {        # $1 = lever ball row
	local x y i r row ch c wy bg ball=$1
	for ((i = 0; i < HP * W; i++)); do P[i]=-1; done
	for ((y = 1; y < 12; y++)); do
		c=55
		((y == 1)) && c=92
		((y == 11)) && c=54
		for ((x = 1; x < 26; x++)); do P[y * W + x]=$c; done
	done
	for ((i = 0; i < NB; i++)); do
		if ((state == 1)); then
			((CLEAN)) && c=183 || c=219
		elif ((state == 2)); then
			c=237
		else
			(((i + frame / 3) % 4 == 0)) && c=183 || c=60
		fi
		P[BULBS[i]]=$c
	done
	for ((x = 1; x < 26; x++)); do P[13 * W + x]=53; done
	for ((wy = 0; wy < 9; wy++)); do
		y=$((wy + 2))
		bg=${REEL_BG[wy]}
		((state == 1 && wy > 0 && wy < 8)) && bg=231
		for ((i = 0; i < 3; i++)); do
			r=$(((off[i] + wy) % L))
			row=${STRIP[r]}
			for ((x = 0; x < 7; x++)); do
				ch=${row:x:1}
				[[ $ch == . ]] && c=$bg || c=${COL[$ch]}
				P[y * W + 2 + i * 8 + x]=$c
			done
		done
	done
	P[6 * W + 1]=141                    # payline markers
	P[6 * W + 25]=141
	P[8 * W + 27]=250                   # lever
	for ((y = ball + 2; y <= 8; y++)); do P[y * W + 28]=250; done
	P[ball * W + 28]=219; P[ball * W + 29]=171
	P[(ball + 1) * W + 28]=171; P[(ball + 1) * W + 29]=91
}

# Builds the footer into $out (raw escapes, printed with %s)
render() {              # $1 = lever ball row
	local x y t b i c n=${#TITLE} msg sub

	out+="     $E[1;38;5;${SHIMMER[frame / 4 % 8]}m▶ "
	for ((i = 0; i < n; i++)); do
		if ((state == 1)); then
			c=219
		elif ((state == 2)); then
			c=244
		else
			c=${SHIMMER[(i + frame / 4) % 8]}
		fi
		out+="$E[38;5;${c}m${TITLE:i:1}"
	done
	out+=" $E[38;5;${SHIMMER[(frame / 4 + 4) % 8]}m◀$E[0m$E[K"$'\n'

	# result message, shown beside the reels
	if ((state == 1 && CLEAN)); then
		msg="$E[1;32mCLEANED$E[0m"
		((removed)) && sub="$E[32m$removed files removed$E[0m" || sub="$E[2malready clean$E[0m"
	elif ((state == 1)); then
		msg="$E[1;38;5;213m★ JACKPOT ★$E[0m" sub="$E[32mbuild OK$E[0m"
	elif ((state == 2)); then
		msg="$E[1;38;5;196mGAME OVER$E[0m" sub="$E[2mexit $rc$E[0m"
	else
		((CLEAN)) && msg="NOW CLEANING" || msg="NOW COMPILING"
		msg="$E[1;37m$msg$E[0m" sub=""
	fi

	draw_machine "$1"
	for ((y = 0; y < HP; y += 2)); do
		out+="  "
		for ((x = 0; x < W; x++)); do
			t=${P[y * W + x]} b=${P[(y + 1) * W + x]}
			if ((t < 0 && b < 0)); then out+="$E[0m "
			elif ((t < 0)); then out+="$E[0;38;5;${b}m▄"
			elif ((b < 0)); then out+="$E[0;38;5;${t}m▀"
			else out+="$E[38;5;${t};48;5;${b}m▀"
			fi
		done
		out+="$E[0m"
		((y == 6)) && out+="  $msg"
		((y == 8)) && out+="  $sub"
		out+="$E[K"$'\n'
	done
}

######  LOOP  ######

frame=0 stopping=-1 pause=0 rc="" state=0 shown=0 flash=0
targets=()

while :; do
	out=$SYNC_ON
	((frame > 0)) && out+="$E[${FOOT}A"

	if [[ -z $rc ]] && ! kill -0 "$PID" 2>/dev/null && ((frame > 4)); then
		wait "$PID"; rc=$?
		if ((rc == 0 && CLEAN)); then
			targets=($EMPTY_IDX $EMPTY_IDX $EMPTY_IDX)
		elif ((rc == 0)); then
			targets=($SEVEN_IDX $SEVEN_IDX $SEVEN_IDX)
		else
			targets=(1 3 4)
		fi
		stopping=0
	fi

	# new log lines go above the machine, which overwrites itself in place
	n=$(wc -l <"$LOG")
	if ((n > shown)); then
		while IFS= read -r line; do
			out+="$E[2K${line//$'\t'/    }$E[0m"$'\n'
		done < <(sed -n "$((shown + 1)),${n}p" "$LOG")
		shown=$n
	fi

	for ((i = 0; i < 3; i++)); do
		((i < stopping || stopping == 3)) && continue
		if ((i == stopping && pause == 0)); then
			# keep spinning at full speed, without overshooting the target symbol
			t=$(((targets[i] * 8 - 1 + L) % L))
			d=$(((DIR * (t - off[i]) + 2 * L) % L))
			((d > 5)) && d=5
			off[i]=$(((off[i] + DIR * d + L) % L))
			if ((off[i] == t)); then
				((stopping++)); pause=1
			fi
		elif ((i != stopping)); then
			off[i]=$(((off[i] + DIR * speed[i] + L) % L))
		fi
	done
	((pause > 0)) && ((pause--))

	if ((stopping == 3 && state == 0)); then
		if ((rc == 0)); then
			state=1
			removed=$(grep -c "^removed '" "$LOG")
		else
			state=2
		fi
	fi

	render $((frame < 4 && !CLEAN ? 8 : 2))
	printf '%s' "$out$SYNC_OFF"

	((state == 2)) && break
	((state == 1 && ++flash > 6)) && break
	((frame++))
	sleep "$DELAY"
done

# last log line may lack a trailing newline
[[ -s $LOG && $(tail -c1 "$LOG" | wc -l) -eq 0 ]] && { tail -n1 "$LOG"; echo; }
cleanup
exit "$rc"
endef
export SLOT_MACHINE := $(value SLOT_MACHINE_SRC)
