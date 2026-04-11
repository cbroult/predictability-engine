### ARCHITECTURE

#### Overview
The Predictability Engine is a tool designed to answer "When will it be done?" using historical flow metrics and probabilistic forecasting (Monte Carlo simulations).

#### System Context
The engine sits between the project data sources (like Jira or CSV files) and the user who needs to make informed decisions based on data.

```mermaid
C4Context
  title System Context diagram for Predictability Engine

  Person(user, "User/Stakeholder", "A project manager or developer wanting to know 'When will it be done?'.")
  System(pe, "Predictability Engine", "Calculates flow metrics and runs Monte Carlo simulations to provide probabilistic forecasts.")

  System_Ext(jira, "Jira", "Source of agile project data (issues, status changes).")
  System_Ext(files, "CSV/Excel Files", "Exported project data.")

  Rel(user, pe, "Requests summary, forecasts, or visualizations")
  Rel(pe, jira, "Fetches data from")
  Rel(pe, files, "Reads data from")
  Rel(pe, user, "Provides ASCII charts, HTML dashboards, and PDF reports")
```

#### Containers
The system is structured as a modular Ruby library with a CLI entry point.

```mermaid
C4Container
  title Container diagram for Predictability Engine

  Person(user, "User", "Uses CLI to interact with the system.")
  
  System_Boundary(pe_boundary, "Predictability Engine") {
    Container(cli, "CLI Application", "Ruby/Thor", "Handles user commands and coordinates report generation.")
    Container(engine, "Core Engine", "Ruby", "Calculates metrics (Cycle Time, Throughput) and runs Monte Carlo simulations.")
    Container(agent, "AI Assistant", "Ruby/Langchain", "Provides natural language analysis and anomaly detection.")
    Container(visualizer, "Visualization Engine", "Ruby (UnicodePlot/Vega)", "Renders ASCII and HTML/SVG charts.")
  }

  System_Ext(jira, "Jira API", "External issue tracking system.")
  System_Ext(files, "Local File System", "Reads CSV/Excel input files and writes HTML/PDF reports.")

  Rel(user, cli, "Runs commands")
  Rel(cli, engine, "Calls for data processing and simulations")
  Rel(cli, agent, "Delegates natural language queries")
  Rel(cli, visualizer, "Requests chart rendering")
  Rel(engine, jira, "Fetches data using API")
  Rel(engine, files, "Reads data from")
  Rel(visualizer, files, "Writes reports to")
```

#### Components
The **Core Engine** consists of several key components:
- **Models**: `WorkItem` represent the basic units of work.
- **Data Sources**: Strategy pattern for `Csv`, `Excel`, and `Jira` ingestion.
- **Calculators**: Logic for `CycleTime`, `Throughput`, and `Cfd` (Cumulative Flow Diagram).
- **Simulators**: `MonteCarlo` engine for probabilistic forecasting.

#### Patterns & Principles
- **Strategy Pattern**: Used for data ingestion (`DataSource::Base`).
- **Unified Reporting**: A single `Report` class orchestrates multiple visualizers for consistent output across mediums.
- **Clean Architecture**: Separation of concerns between CLI, business logic (Engine), and external integrations.
- **Agentic AI**: ReAct pattern for the AI Assistant to use engine tools for analysis.
