NAME		=	casino_demo

SRC_DIR		=	srcs
INC_DIR		=	includes
BUILD_DIR	=	build

SRCS		=	main.c		\
				jackpot.c

OBJS		=	$(SRCS:%.c=$(BUILD_DIR)/%.o)
DEPS		=	$(OBJS:.o=.d)

CC			=	cc
CFLAGS		=	-Wall -Wextra -Werror -MMD -MP
CPPFLAGS	=	-I$(INC_DIR)

all: $(NAME)

$(NAME): $(OBJS)
	$(CC) $(CFLAGS) $^ -o $@

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@

clean:
	rm -rfv $(BUILD_DIR)

fclean: clean
	rm -fv $(NAME)

re: fclean all

-include $(DEPS)

.PHONY: all clean fclean re
