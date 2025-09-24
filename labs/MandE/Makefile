# Makefile

SHELL := /bin/zsh
HOME_DIR = $(shell pwd)

# Get the full absolute path of the current Makefile
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))

# Get the directory of the current Makefile
MAKEFILE_DIR := $(dir $(MAKEFILE_PATH))

COMMON_PATH := ../../common

ANSIBLE_ARGS ?=
SITES ?= $(wildcard sites/*/)

include ../../common/Makefile-common.mk
