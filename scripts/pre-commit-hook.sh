#!/bin/bash
# Pre-commit hook to generate sample reports
echo "Pre-commit: Generating sample reports..."
bundle exec rake reports:generate_samples
git add data/samples/reports/
