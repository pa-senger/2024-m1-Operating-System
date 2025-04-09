CC = gcc
CFLAGS = -Wall -Wextra -g -pedantic

FILENAME = poly

all: $(FILENAME)

a.out: $(FILENAME).c
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f $(FILENAME)

