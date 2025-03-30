# Makefile for repository statistics

# Extract repository list (skipping comments and empty lines)
REPOS = $(shell grep -v "^#" repos.txt | grep -v "^$$")
REPO_NAMES = $(notdir $(basename $(REPOS)))
CSV_FILES = $(patsubst %,data/%.csv,$(REPO_NAMES))
MD_FILES = $(patsubst %,data/%/index.md,$(REPO_NAMES))
GRAPH_FILES = $(patsubst %,data/%/commits.svg data/%/lines.svg,$(REPO_NAMES))

# Directories
SCRIPTS_DIR = scripts
DATA_DIR = data

# Default target - first update mtimes, then process files
all: update-mtimes process-all index

# Weekly update target - only run if CSVs are older than a week
weekly: update-mtimes check-week-old process-all index

# Generate main index file
index: $(CSV_FILES)
	@echo "Generating main index..."
	@$(SCRIPTS_DIR)/index.sh > $(DATA_DIR)/index.md

# Update file modification times to match git history
update-mtimes:
	@echo "Updating file modification times from git history..."
	$(SCRIPTS_DIR)/mtime.sh

# Check if CSVs are older than a week, update repos.txt timestamp if needed
check-week-old:
	@echo "Checking if any CSV is newer than a week..."
	$(SCRIPTS_DIR)/weekly-update.sh

# Process all files
process-all: csv-files md-files graphs

# CSV files generation
csv-files: $(CSV_FILES)

# Markdown files generation
md-files: $(MD_FILES)

# Graph generation
graphs: $(GRAPH_FILES)

# Rule to generate CSV for each repository
data/%.csv: repos.txt $(SCRIPTS_DIR)/stats.sh
	@mkdir -p $(DATA_DIR)
	@echo "Generating CSV for $*..."
	@$(SCRIPTS_DIR)/stats.sh $(filter %/$*.git,$(REPOS))

# Rule to generate graph files
data/%/commits.svg data/%/lines.svg: data/%.csv $(SCRIPTS_DIR)/graphs.sh
	@mkdir -p data/$*
	@echo "Generating graphs for $*..."
	@$(SCRIPTS_DIR)/graphs.sh $< data/$*

# Clean all generated files
clean:
	rm -rf $(DATA_DIR)

# Clean just the markdown and graph files, keeping CSVs
clean-docs:
	rm -f $(MD_FILES) $(GRAPH_FILES)

# Show available repos
list-repos:
	@echo "Available repositories:"
	@for repo in $(REPO_NAMES); do echo "  - $$repo"; done

.PHONY: all process-all weekly update-mtimes check-week-old csv-files md-files graphs index clean clean-docs list-repos
