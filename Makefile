LDLIBS=-lfl

all:
	@make clean
	@make htmlinfo
	@make data

clean:
	rm -f  htmlinfo

data:
	wget -q  -O ./test/campusvirtualUVa.html https://campusvirtual.uva.es
	wget -q  -O ./test/wikipedia.html https://www.wikipedia.org/
	./htmlinfo ./test/campusvirtualUVa.html > ./test/campusvirtualUVa.info 
	./htmlinfo ./test/wikipedia.html > ./test/wikipedia.info 
