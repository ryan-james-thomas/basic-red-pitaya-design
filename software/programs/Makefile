CC=gcc
OBJ_S = test_memory.o 

all: savers clean

savers: $(OBJ_S)
	$(CC) -o test_memory test_memory.o

.PHONY: clean

clean:
	rm ./*.o