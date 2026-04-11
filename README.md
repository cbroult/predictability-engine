# Predictability Engine

A turn-key solution for implementing Daniel Vacanti's Actionable Agile Metrics and forecasting methodologies, integrated with Agentic AI.

## Features

- **Flow Metrics Calculation**: Automated calculation of Cycle Time (distribution & percentiles), Throughput (daily & average), and WIP.
- **Visualizations**: Graphical representations of Cycle Time Scatter Plots, Throughput Histograms, and Cumulative Flow Diagrams (CFD) both in the terminal (ASCII) and as high-quality HTML/SVG.
- **Monte Carlo Simulations**: Statistical forecasting for "When will it be done?" and "How many items will be finished?".
- **Agentic AI Assistant**: A ReAct-based AI agent that can analyze your data, detect anomalies in Cumulative Flow Diagrams (CFD), and answer complex forecasting questions in natural language.
- **CLI Interface**: Simple command-line interface for easy interaction.

## Getting Started

### Prerequisites

- Ruby 4.0+
- Bundler
- OpenAI API Key (for the AI features)

### Installation

1. Clone the repository:
   ```bash
   git clone <repo_url>
   cd predictability-engine
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up your environment:
   ```bash
   echo "OPENAI_API_KEY=your_key_here" > .env
   ```

### Usage

The engine uses a simple CSV format for data ingestion. The CSV should have the following headers: `id`, `title`, `start_date`, `end_date`.

#### Summary of Current State
Get a quick snapshot of your flow metrics:
```bash
./bin/predictability-engine summary sample_data.csv
```

#### Forecast Completion
Run 10,000 Monte Carlo simulations for a backlog of X items:
```bash
./bin/predictability-engine forecast sample_data.csv 10
```

#### Ask the AI Agent
Ask questions about your data in natural language:
```bash
./bin/predictability-engine ask sample_data.csv "When will the next 15 items be done? Also, are there any anomalies in our flow?"
```

#### Visualizations
Generate visual representations of your metrics:
```bash
# Terminal-based scatter plot
./bin/predictability-engine viz scatter sample_data.csv

# Terminal-based CFD
./bin/predictability-engine viz cfd sample_data.csv

# High-quality HTML scatter plot
./bin/predictability-engine viz html_scatter sample_data.csv

# Show all terminal visualizations at once
./bin/predictability-engine viz all sample_data.csv

# Generate a combined HTML dashboard
./bin/predictability-engine viz html_all sample_data.csv
```

## Documentation
- [Engineering Guidelines (AGENT.md)](AGENT.md)
- [Architecture Documentation (ARCHITECTURE.md)](ARCHITECTURE.md)
- [API Documentation (YARD)](doc/index.html)

## Quality & Testing

We use a suite of tools to ensure high-quality code and accurate metrics:

- **BDD/Acceptance**: `bundle exec cucumber` (Aruba CLI testing).
- **Unit Testing**: `bundle exec rspec` (Logic validation).
- **Linting**: `bundle exec rubocop` (Style enforcement).
- **Duplicate Detection**: `npx jscpd .` (Copy-paste detection).
- **Security Analysis**: `bundle exec rake audit` (Vulnerability scanning).
- **API Documentation**: `bundle exec rake docs` (YARD documentation).
- **Performance Benchmarking**: `bundle exec rake bench` (Monte Carlo simulation performance).
- **Full Quality Check**: Run the entire validation pipeline with a single command:
  ```bash
  bundle exec rake
  ```

## Methodology

This engine is based on the principles described in:
- *Actionable Agile Metrics for Predictability* by Daniel S. Vacanti
- *When Will It Be Done?* by Daniel S. Vacanti

Key metrics used:
- **Cycle Time**: The time it takes for a single work item to go from start to finish.
- **Throughput**: The number of work items completed per unit of time.
- **WIP (Work in Progress)**: The number of items currently being worked on.
- **Monte Carlo Simulation**: Using historical throughput to sample and simulate thousands of possible future outcomes.

## Agentic AI

The engine uses `langchainrb` to implement an agent with tool-calling capabilities. The agent can:
- Fetch real-time metrics from the engine.
- Run simulations on the fly.
- Perform trend analysis on CFDs to detect bottlenecking or growing WIP.
