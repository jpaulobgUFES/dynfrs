CXX  := g++

.PHONY: clean 3rdparty

dapp: dapp.cpp
	make -C 3rdparty
	$(CXX) -std=c++17 -O3 -o $@ $^

clean:
	@rm -rf dapp
	make -C 3rdparty clean
