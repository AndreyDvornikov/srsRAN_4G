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

VIVADO ?= vivado

project:
	@echo "Create project" 
	@cd $(REPO_ROOT)/vivado/ && "$(VIVADO)" -mode batch -notrace -source "system_bd.tcl" && cd ..

clean: 
	@echo "Clean project"
	rm -rf $(REPO_ROOT)vivado/lte_phy_math.*
	rm -rf $(REPO_ROOT)vivado/.Xil
	rm -f $(REPO_ROOT)vivado/vivado_*.backup.log
	rm -f $(REPO_ROOT)vivado/vivado_*.backup.jou
	rm -f $(REPO_ROOT)vivado/vivado_pid*.str
	rm -f $(REPO_ROOT)vivado/vivado.log
	rm -f $(REPO_ROOT)vivado/vivado.jou

help:
	@echo "make project"
	