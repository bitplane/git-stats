# Makefile
# ----------------------------------------------------------------------------
# "make" will:
#   1) update-mtimes  -> adjusts file times to last commit
#   2) process-all    -> generates CSV, MD files, graphs
#   3) index          -> builds data/index.md
#
# Repos are listed in repos.txt, ignoring comments or blank lines.
# For each, we produce data/<repo_name>.csv and data/<repo_name>/*.md, *.svg
# ----------------------------------------------------------------------------

REPOS       = $(shell grep -v "^#" repos.txt | grep -v "^$$")
REPO_NAMES  = $(notdir $(basename $(REPOS)))
CSV_FILES   = $(patsubst %,data/%.csv,$(REPO_NAMES))
MD_FILES    = $(patsubst %,data/%/index.md,$(REPO_NAMES))
GRAPH_FILES = $(patsubst %,data/%/commits.svg data/%/lines.svg,$(REPO_NAMES))

SCRIPTS_DIR = scripts
DATA_DIR    = data

# Default target - run everything
all: update-mtimes process-all index

# Weekly target - only runs if CSVs are older than a week
weekly: update-mtimes check-week-old process-all index

# Generate main index from existing CSVs
index: $(CSV_FILES)
	@echo "Generating main index..."
	@$(SCRIPTS_DIR)/index.sh > $(DATA_DIR)/index.md

# 1) Update file modification times per local repo .git
update-mtimes:
	@echo "Updating file modification times from git history..."
	$(SCRIPTS_DIR)/mtime.sh

# 2) Check if CSVs are older than a week (updates repos.txt mtime if so)
check-week-old:
	@echo "Checking if any CSV is newer than a week..."
	$(SCRIPTS_DIR)/weekly-update.sh

# 3) Process all = build CSV, MD, and Graphs
process-all: csv-files md-files graphs

# 3a) Generate CSV
csv-files: $(CSV_FILES)

# 3b) Generate per-repo Markdown
md-files: $(MD_FILES)

# 3c) Generate graphs
graphs: $(GRAPH_FILES)

# ----------------------------------------------------------------------------
# RULE: build data/%.csv by running stats.sh on matching repo
# ----------------------------------------------------------------------------
data/%.csv: repos.txt $(SCRIPTS_DIR)/stats.sh
	@mkdir -p $(DATA_DIR)
	@echo "Generating CSV for $*..."
	@repo_url=$$(grep -E "/$*.git$$" repos.txt); \
	 if [ -z "$$repo_url" ]; then \
	   echo "❌ Repo $* not found in repos.txt" >&2; \
	   exit 1; \
	 fi; \
	 $(SCRIPTS_DIR)/stats.sh "$$repo_url"

# RULE: build data/%/commits.svg and data/%/lines.svg from data/%.csv
data/%/commits.svg data/%/lines.svg: data/%.csv $(SCRIPTS_DIR)/graphs.sh
	@mkdir -p data/$*
	@echo "Generating graphs for $*..."
	@$(SCRIPTS_DIR)/graphs.sh $< data/$*

# ----------------------------------------------------------------------------
# Markdown "docs" generation
data/%/index.md: data/%.csv $(SCRIPTS_DIR)/markdown.sh
	@mkdir -p data/$*
	@echo "Building markdown for $*..."
	@$(SCRIPTS_DIR)/markdown.sh $< > data/$*/index.md

# ----------------------------------------------------------------------------
# Cleanup targets
clean:
	rm -rf $(DATA_DIR)

clean-docs:
	rm -f $(MD_FILES) $(GRAPH_FILES)

list-repos:
	@echo "Available repositories:"
	@for r in $(REPO_NAMES); do echo "  - $$r"; done

.PHONY: all weekly update-mtimes check-week-old process-all csv-files md-files graphs index clean clean-docs list-repos
