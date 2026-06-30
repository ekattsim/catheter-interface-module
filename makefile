PROJECT := $(notdir $(shell pwd))
XPR := build/$(PROJECT).xpr

all: bitstream

project:
	mkdir -p build
	vivado -mode batch -source scripts/create_project.tcl -nojournal -nolog

bitstream: $(XPR)
	vivado -mode batch -source scripts/build_bitstream.tcl -nojournal -nolog
	mkdir -p out
	cp build/$(PROJECT).runs/impl_1/*.bit out/

$(XPR):
	$(MAKE) project

clean:
	rm -rf build out *.jou *.log
