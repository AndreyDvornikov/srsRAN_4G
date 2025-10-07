MAKEFILE_DIR := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_FILE := $(MAKEFILE_DIR)srsTheory_and_modeling.prj

.PHONY: project

project:
	matlab -desktop -r "openProject('$(PROJECT_FILE)')" &