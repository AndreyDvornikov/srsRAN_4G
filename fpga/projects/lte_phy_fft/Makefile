# Current makefile path
# PS: MAKEFILE_LIST - массив MAKEFILE_LIST 
# которые участвовали в стеке вызова. От первого, который запустился (firstword)
# до последнего, это если firstword замеить на lastword 
# т.к. этот makefile НЕ БУДЕТ корневым (т.е. он будет запускаться другим makefile), то lastword
# если я вызываю из директории lte_phy_math, то THIS_MAKE будет хранить .\vivado\Makefile
THIS_MAKE = $(lastword $(MAKEFILE_LIST)) 

# с помощью realpath мы получаем не относительный путь, а абсолютный путь до ФАЙЛА
# и с помощью dir возвращаем не путь до файла, а путь до директории, где лежит этот файл
# вот так вот
MAKE_DIR  = $(dir $(realpath $(THIS_MAKE)))

# корень проекта (просто алиас к переменной)
REPO_ROOT = $(MAKE_DIR)

# SIM_FWD_DIR 	:= $(REPO_ROOT)/devl/simulation_128
# SIM_INV_DIR 	:= $(REPO_ROOT)/devl/simulation_128_inv
# XSIM_TCL_FN 	:= xsim-simulate.tcl
# PREFWD_TCL_FN	:= fwd-presim.tcl

VIVADO ?= vivado

project:
	@echo "Create project" 
	@cd $(REPO_ROOT)/vivado/ && "$(VIVADO)" -mode batch -notrace -source "system_bd.tcl" && cd ..

clean: 
	@echo "Clean project"
	rm -rf $(REPO_ROOT)/vivado/lte_phy_fft.*

# sim-fwd:
# 	@echo "SIM (forward) in $(SIM_FWD_DIR)"
# 	cd "$(SIM_FWD_DIR)" && tclsh "../$(PREFWD_TCL_FN)"

# sim-fwd-clean:
# 	@echo "SIM CLEAN (forward) in $(SIM_FWD_DIR)"
# 	$(MAKE) -f $(REPO_ROOT)/devl/Makefile fwd-clean

# sim-inv:
# 	@echo "SIM (inverse) in $(SIM_INV_DIR)"
# 	cd "$(SIM_INV_DIR)" && tclsh "$(XSIM_TCL_FN)"

# sim-inv-clean:
# 	@echo "SIM CLEAN (forward) in $(SIM_FWD_DIR)"
# 	cd "$(SIM_FWD_DIR)" && tclsh "$(XSIM_TCL_FN)"

help:
	@echo "make project"
	