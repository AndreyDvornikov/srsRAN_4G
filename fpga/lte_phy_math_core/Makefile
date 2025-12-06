# последний загруженный makefile
THIS_MAKEFILE := $(lastword $(MAKEFILE_LIST))
THIS_MAKEFILE_DIR := $(abspath $(dir $(THIS_MAKEFILE)))

FILE_PATH := $(THIS_MAKEFILE_DIR)


.PHONY: tb-vector

tb-vector:
	@echo "Start vector testbench"
	@echo "Makefile dir is: $(FILE_PATH)"
	cd $(FILE_PATH)/tb/tb_vector && vsim -do tb_vector.tcl
	cd ./../../
