all:
	@echo "Hello World!"

clean:
	rm -f *.block
	rm -f *.index
	rm -f *.tar

zeroes.txt: zrs.txt
	cp zrs.txt zeroes.txt
