
# Determine where the install directory is located.
TARGET?=$(HOME)/local
GCC ?= gcc
GXX ?= g++
GCC_MAJOR_VERSION := $(shell $(GCC) -dumpversion | cut -d'.' -f1)
GCC_MINOR_VERSION := $(shell $(GCC) -dumpversion | cut -d'.' -f2)
GXX_MAJOR_VERSION := $(shell $(GXX) -dumpversion | cut -d'.' -f1)
GXX_MINOR_VERSION := $(shell $(GXX) -dumpversion | cut -d'.' -f2)
CC  = "ccache $(GCC)"
CXX = "ccache $(GXX)"
SHELL:=/bin/bash

# Determines the number of parallel jobs that will be used to build each of the submodules
JOBS?=8

#determine if node js is used, if using ubuntu 14 it should be disabled
NODEJS_ENABLED := 0

all: install_node install_boost install_userspacercu install_hiredis install_snappy install_cityhash install_zeromq install_libssh2 install_protobuf install_zookeeper install_redis install_pistache

.PHONY: install_node install_boost install_userspacercu install_hiredis install_snappy install_cityhash install_zeromq install_libssh2 install_protobuf install_zookeeper install_redis install_pistache

install_node:
	if [ $(NODEJS_ENABLED) = 1 ]; \
	then \
		echo "node js enabled" && \
		JOBS=$(JOBS) cd node && \
		./recoset_build_node.sh;\
	else \
		echo "node js disabled"; \
	fi

install_boost:
	if [ ! -f boost_1_57_0/b2 ]; \
	then \
		cd boost_1_57_0; \
		./bootstrap.sh --prefix=$(TARGET); \
		sed -i '1i using gcc : : $(GCC) ;' ./project-config.jam; \
	fi
	cd boost_1_57_0; \
	./bjam include=/usr/lib; \
	./b2 -j$(JOBS) variant=release link=shared threading=multi runtime-link=shared --without=graph --without-graph_parallel --without-mpi install;

clean_boost:
	cd boost_1_57_0; \
	rm -rf ./b2 ./bin.v2 ./bjam ./bootstrap.log ./project-config.jam ./tools/build/v2/engine/bootstrap/ ./tools/build/v2/engine/bin.linuxx86_64/

install_userspacercu:
	cd userspace-rcu; \
	./bootstrap; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix=$(TARGET); \
	make install

install_hiredis:
	cd hiredis; \
	CXX=$(CXX) CC=$(CC) PREFIX=$(TARGET) LIBRARY_PATH=lib make install

install_snappy:
	cd snappy; \
	./autogen.sh; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix $(TARGET); \
	make install

install_protobuf:
	cd protobuf; \
	./autogen.sh; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix $(TARGET); \
	make install

DISABLE_SSE42 ?= 0
ifneq ($(DISABLE_SSE42),0)
CITYHASH_CXXFLAGS := -mno-sse4.2
else
CITYHASH_CONFIGURE_FLAGS := --enable-sse4.2
endif

install_cityhash:
	cd cityhash; \
	CXX=$(CXX) CC=$(CC) ./configure $(CITYHASH_CONFIGURE_FLAGS) --prefix $(TARGET); \
	make all check CXXFLAGS="-g -O3 $(CITYHASH_CXXFLAGS)"; \
	make install

install_zeromq:
	cd zeromq3-x; \
	./autogen.sh; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix $(TARGET); \
	make -j$(JOBS) -k; \
	make install

install_libssh2:
	cd libssh2; \
	./buildconf; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix $(TARGET); \
	make -j$(JOBS) -k; \
	make install

install_zookeeper:
	cd zookeeper; \
	(ulimit -v unlimited; JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/ ant compile); \
	cd src/c; \
	autoreconf -if; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix $(TARGET); \
	make -j$(JOBS) -k install; \
	make doxygen-doc
	install -d $(TARGET)/bin/zookeeper; \
	rm -rf $(TARGET)/bin/zookeeper/*; \
	cp -a zookeeper/{bin,build,conf,docs} $(TARGET)/bin/zookeeper/

install_redis:
	cd redis; \
	CXX=$(CXX) CC=$(CC) PREFIX=$(TARGET) make -j$(JOBS) -k install

install_pistache:
	if [ \( $(GCC_MAJOR_VERSION) -gt 4 -o $(GCC_MAJOR_VERSION) -eq 4 -a $(GCC_MINOR_VERSION) -gt 6 \) -a \
		 \( $(GXX_MAJOR_VERSION) -gt 4 -o $(GXX_MAJOR_VERSION) -eq 4 -a $(GCC_MINOR_VERSION) -gt 6 \) ]; \
	then \
		cd pistache; \
		if [ -s CMakeCache.txt ]; then rm CMakeCache.txt; fi; \
		if [ -d CMakeFiles ]; then rm -rf CMakeFiles; fi; \
		if [ -s install_manifest.txt ]; then rm install_manifest.txt; fi; \
		if [ -s Makefile ]; then rm Makefile; fi; \
		if [ -s CTestTestfile.cmake ]; then rm -rf CTestTestfile.cmake; fi; \
		if [ -s cmake_install.cmake ]; then rm cmake_install.cmake; fi; \
		cmake -DCMAKE_INSTALL_PREFIX=$(TARGET) -DCMAKE_CXX_COMPILER=$(GXX) -DCMAKE_C_COMPILER=$(GCC); \
		make -j$(JOBS) -k install; \
	else \
		echo "pistache disabled"; \
	fi

install_cairomm:
	cd cairomm; \
	./autogen.sh; \
	CXX=$(CXX) CC=$(CC) ./configure --prefix=$(TARGET); \
	make install

# Helps troubleshooting deployments via scripts.
.PHONY: test-deploy
test-deploy:
	@echo "=== test-deploy ==="
	@whoami
	@echo "HOME=$(HOME)"
	@echo "TARGET=$(TARGET)"
	@echo "GCC=$(GCC) GXX=$(GXX) CC=$(CC) CXX=$(CXX)"
	@echo "GCC_VERSION= $(GCC_MAJOR_VERSION).$(GCC_MINOR_VERSION)"
	@echo "GXX_VERSION= $(GXX_MAJOR_VERSION).$(GXX_MINOR_VERSION)"
	@echo
	@env | sort
	@echo "=== test-deploy ==="
