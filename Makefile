CC = gcc
objs = replay-log.o log-writes.o
progs = replay-log
CFLAGS = -g -Wall

replay-log: $(objs)
	$(CC) $(CFLAGS) -o replay-log $(objs)

all: $(progs)
