#==============================================================================#
#                                    CONFIG                                    #
#==============================================================================#

MAKE		= make --no-print-directory
SHELL		:= bash --rcfile ~/.bashrc

PYTHON	:= $(shell which python3 2>/dev/null || which python 2>/dev/null || echo "python")
VENV		= .venv

#==============================================================================#
#                                     NAMES                                    #
#==============================================================================#

PROJECT_NAME		= $(shell basename $(CURDIR))
PROJECT_DESCRIPTION	= ...
PROJECT_VERSION		= 0.1.0
AUTHOR_NAME			= Zedro
AUTHOR_EMAIL		= 45104292+PedroZappa@users.noreply.github.com

SRC		= src
NAME	= main
MAIN	= $(SRC)/$(NAME).py
ARGS	= 

MAIN_TEST = test_$(NAME).py
TEST_FILE ?= $(MAIN_TEST)
EXEC			= ./scripts/run.sh && $(PYTHON) $(MAIN)

# Define a function to add directory if it exists
add-if-exists = $(if $(wildcard $(1)/.),$(1))

EXCLUDE_DIRS = $(VENV) \
               $(call add-if-exists,__*) \
               $(call add-if-exists,build) \
               $(call add-if-exists,dist) \
               $(call add-if-exists,.*_cache) \
               $(call add-if-exists,*/*-info) \

#==============================================================================#
#                                COMMANDS                                      #
#==============================================================================#

### Core Utils
RM			= rm -rf
MKDIR_P	= mkdir -p

#==============================================================================#
#                                  RULES                                       #
#==============================================================================#

##@ Project Scaffolding 󰛵

all: init build			## Build and run project

DEPS			=
DEV_DEPS	= black ruff mypy pytest debugpy

POETRY_INIT_ARGS = --name "$(PROJECT_NAME)" \
									 --description "$(PROJECT_DESCRIPTION)" \
									 --author "$(AUTHOR_NAME)" \
									 $(if $(DEPS),$(foreach dep,$(DEPS),--dependency="$(dep)"),) \
									 $(foreach dep,$(DEV_DEPS),--dev-dependency="$(dep)") \
									 --verbose \
									 -n

init:			## Initialize project
	@if [ ! -f "pyproject.toml" ]; then \
		echo "$(B)Initializing project: $(PROJECT_NAME) v$(PROJECT_VERSION)$(D)"; \
		poetry init $(POETRY_INIT_ARGS); \
		awk '/^\[tool\.poetry\]/{print; print "packages = [{ include = \"*\", from = \"src\" }]"; next}1' pyproject.toml > tmp && mv tmp pyproject.toml; \
	fi

env:			## Create virtual environment
	@echo "$(B)Project: $(PROJECT_NAME) v$(PROJECT_VERSION)$(D)"
	@echo "Setting up Poetry virtual environment..."
	@if ! command -v poetry >/dev/null 2>&1; then \
	  echo "$(RED)Error: Poetry is not installed$(D)"; \
	  exit 1; \
	fi
	poetry env use "$(PYTHON)" || true
	poetry install --no-root --only dev >/dev/null

deps: env
	@echo "$(B)Installing all dependencies (including dev)$(D)"
	poetry install

build: deps ## Build project
	@echo "$(B)Building source and wheel distributions...$(D)"
	poetry build
	@echo "$(GRN)✅ Build complete: dist/$(D)"

run:
	@echo "$(B)Running $(MAG)$(PROJECT_NAME)$(BWHI) application$(D)"
	poetry run python $(MAIN)

##@ Utility Rules 

lint:			## Lint project
	@echo "$(B)Linting & type checking$(D)"
	poetry run ruff .
	poetry run mypy $(SRC)
	poetry run black . --check


##@ Documentation Rules 

SPHINX_START_ARGS = -q \
                    -p $(NAME) \
                    -a $(AUTHOR_NAME) \
                    -v "1.0" \
                    --makefile
DOCS_SRC					= docs/source

sphinx:		## Generate .rst files
	@if [ ! -d "$(DOCS_SRC)" ]; then \
		sphinx-quickstart $(SPHINX_START_ARGS) $(DOCS_SRC); \
	fi
	sphinx-apidoc -o $(DOCS_SRC) $(SRC)
	$(MAKE) -C $(DOCS_SRC) html

docs: 		## Open docs index in browser
	xdg-open $(DOCS_SRC)/_build/html/index.html

##@ Test/Debug Rules 

test:			# Test project
	@echo "$(B)Running test suite$(D)"
	poetry run pytest $(MAIN_TEST)


test_all:## Run all tests
	@echo "* $(MAG)$(NAME) $(YEL)starting test suite$(D):"
	@echo ""
	@$(MAKE) doctest; DOCTEST_EXIT=$$?; \
	$(MAKE) pytest; PYTEST_EXIT=$$?; \
	$(MAKE) mypy; MYPY_EXIT=$$?; \
	echo ""; \
	echo "$(MAG)$(TEST_BOX_TOP)$(D)"; \
	echo "$(MAG)$(TEST_HEADER)$(D)"; \
	echo "$(MAG)$(TEST_BOX_MID)$(D)"; \
	print_test_result() { \
		test_name="$$2"; \
		name_length=$${#test_name}; \
		if [ $$1 -eq 0 ]; then \
			status="$(GRN)PASSED$(D)"; \
			icon="$(GRN)✓$(D)"; \
		else \
			status="$(RED)FAILED$(D)"; \
			icon="$(RED)✗$(D)"; \
		fi; \
		padding=$$((25 - name_length)); \
		printf "$(MAG)║$(D) %s %s %s%*s$(MAG)║$(D)\n" \
			"$$icon" "$$test_name" "$$status" "$$padding" ""; \
	}; \
	print_test_result $$DOCTEST_EXIT "Doctest"; \
	print_test_result $$PYTEST_EXIT "Pytest"; \
	print_test_result $$MYPY_EXIT "MyPy"; \
	echo "$(MAG)$(TEST_BOX_BOT)$(D)"; \
	echo ""; \
	TOTAL_FAILED=$$(($$DOCTEST_EXIT + $$PYTEST_EXIT + $$MYPY_EXIT)); \
	if [ $$TOTAL_FAILED -eq 0 ]; then \
		echo "$(GRN)🎉 All tests passed successfully!$(D)"; \
		exit 0; \
	else \
		echo "$(RED)❌ $$TOTAL_FAILED test suite(s) failed$(D)"; \
		exit 1; \
	fi

doctest: sphinx		## Run sphinx doctests
	$(MAKE) -C docs doctest

pytest:		## run pytest
	@echo "* $(MAG)$(NAME) $(YEL)running pytest$(D):"
	pytest $(MAIN_TEST)
	python -m pytest $(TEST_FILE)
	@echo "* $(MAG)$(NAME) pytest suite $(YEL)finished$(D):"

MYPY_FLAGS := --install-types --ignore-missing-imports

mypy:			## Run mypy static checker
	@echo "* $(MAG)$(NAME) $(YEL)running type checker$(D):"
	mypy $(MYPY_FLAGS) $(MAIN)
	@echo "* $(MAG)$(NAME) type checker $(YEL)finished$(D):"

posting:	## Run posting API testing client
	posting --collection $(NAME)_posting --env .env

##@ Clean-up Rules 󰃢

# Define files/directories to clean
CLEAN_TARGETS := $(EXCLUDE_DIRS) \
                 *.sqlite \
                 *.pyc \
                 *_dump.csv

clean: ## Remove temporary files
	@echo "*** $(YEL)Removing $(MAG)$(NAME)$(D) and $(YEL)deps$(D)"
	@for target in $(CLEAN_TARGETS); do \
		if [ "$$target" = ".venv" ]; then \
			continue; \
		fi; \
		if [ -e "$$target" ] || [ -d "$$target" ]; then \
			$(RM) "$$target"; \
			echo "*** $(YEL)Removed $(CYA)$$target$(D)"; \
		fi; \
	done
	@echo "$(_SUCCESS) Clean completed!"

fclean: clean ## Remove temporary files & .venv
	@echo "*** $(YEL)Removing $(MAG)$(NAME)$(D) $(YEL)$(VENV)$(D)"
	@$(RM) $(VENV)

##@ Help 󰛵

help: 	## Display this help page
	@awk 'BEGIN {FS = ":.*##"; \
			printf "\n=> Usage:\n\tmake $(GRN)<target>$(D)\n"} \
		/^[a-zA-Z_0-9-]+:.*?##/ { \
			printf "\t$(GRN)%-18s$(D) %s\n", $$1, $$2 } \
		/^##@/ { \
			printf "\n=> %s\n", substr($$0, 5) } ' Makefile
## Tweaked from source:
### https://www.padok.fr/en/blog/beautiful-makefile-awk

.PHONY: test mypy black posting clean help docs build

#==============================================================================#
#                                  UTILS                                       #
#==============================================================================#

# Colors
#
# Run the following command to get list of available colors
# bash -c 'for c in {0..255}; do tput setaf $c; tput setaf $c | cat -v; echo =$c; done'

B  		= $(shell tput bold)
BLA		= $(shell tput setaf 0)
RED		= $(shell tput setaf 1)
GRN		= $(shell tput setaf 2)
YEL		= $(shell tput setaf 3)
BLU		= $(shell tput setaf 4)
MAG		= $(shell tput setaf 5)
CYA		= $(shell tput setaf 6)
WHI		= $(shell tput setaf 7)
GRE		= $(shell tput setaf 8)
BRED 	= $(shell tput setaf 9)
BGRN	= $(shell tput setaf 10)
BYEL	= $(shell tput setaf 11)
BBLU	= $(shell tput setaf 12)
BMAG	= $(shell tput setaf 13)
BCYA	= $(shell tput setaf 14)
BWHI	= $(shell tput setaf 15)
D 		= $(shell tput sgr0)
BEL 	= $(shell tput bel)
CLR 	= $(shell tput el 1)


### Message Vars
_SUCCESS			= [$(GRN)SUCCESS$(D)]
_INFO					= [$(BLU)INFO$(D)]
_NORM_SUCCESS = $(GRN)=== OK:$(D)
_NORM_INFO 		= $(BLU)File no:$(D)
_NORM_ERR 		= $(RED)=== KO:$(D)
_SEP					= =====================

# Test summary box components
TEST_BOX_TOP	:= ╔═══════════════════════════════════╗
TEST_BOX_MID	:= ╠═══════════════════════════════════╣
TEST_BOX_BOT	:= ╚═══════════════════════════════════╝
TEST_HEADER		:= ║           TEST SUMMARY            ║





