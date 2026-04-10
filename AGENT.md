### AGENTIC ENGINEERING GUIDELINES

#### CORE PRINCIPLES
- **Specification Driven Development**: All new features and changes must be driven by specifications, examples, or tests (BDD/TDD).
- **Behavioral Focus**: We specify the *what* and the *why* before the *how*.
- **DRY (Don't Repeat Yourself)**: Avoid redundant code and logic; abstract common functionality into reusable components.
- **ACID (Data Integrity)**: While typically for databases, we apply these principles to our Predictability Engine's data processing (Atomicity of calculations, Consistency of metrics, Isolation of simulations, Durability of results).
- **YAGNI (You Ain't Gonna Need It)**: Only implement features when they are truly needed; avoid over-engineering.

#### HOLISTIC TESTING STRATEGY (Based on Janet Gregory & Lisa Crispin)
Testing is not a phase — it is woven into every stage of the development lifecycle.

1. **Discover & Plan (Continuous Exploration)**:
   - Use **Example Mapping** to define concrete examples for business rules before coding.
   - Identify risks (e.g., data quality, simulation bias) early.
2. **Understand (Story Level)**:
   - Define **Acceptance Criteria** using Gherkin (`.feature` files) with **Cucumber**.
   - Ensure shared understanding between the User and the Agent (Three Amigos).
3. **Build (Continuous Integration)**:
   - Use **TDD with RSpec** for unit-level design and regression coverage.
   - Use **ATDD/BDD with Cucumber/Aruba** to drive implementation of CLI features.
   - Implement **Dynamic Verification** scenarios in BDD to ensure reports correctly update when input data changes.
   - Enforce code style and quality with **RuboCop**.
4. **Deploy & Release (Continuous Deployment & Release on Demand)**:
   - Automate the pipeline to ensure that every change that passes tests is potentially releasable.
   - Use **SimpleCov** to monitor test coverage (aim for 90%+).
5. **Observe & Learn**:
   - Evaluate AI Agent outputs (LLM-eval) for accuracy, safety, and consistency.
   - Implement observability (logging, metrics) to monitor the engine's performance in "production".

#### CONTINUOUS DELIVERY PIPELINE (SAFe)
- **Continuous Exploration (CE)**: Constantly refining the backlog and exploring new predictability metrics and AI capabilities.
- **Continuous Integration (CI)**: Integrating and testing changes frequently (using GitHub Actions or similar).
- **Continuous Deployment (CD)**: Automating the deployment of the engine to a staging or production-like environment.
- **Release on Demand (RoD)**: The ability to release new features to the end-user whenever the business requires.

#### GIT & VERSION CONTROL
- **Conventional Commits**: Use a standardized commit message format (e.g., `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`) to ensure a readable and automated history.
- **Regular Commits**: Commit changes frequently to maintain a granular and reversible history. This ensures that every meaningful change is documented and can be easily rolled back or reviewed.
- **Git Authoring**: Always include Junie as a co-author when applicable (`--trailer "Co-authored-by: Junie <junie@jetbrains.com>"`).

#### TOOLS & AUTOMATION
- **BDD/Acceptance**: Cucumber & Aruba (CLI testing).
- **Unit Testing**: RSpec.
- **Code Quality**: RuboCop.
- **Visualizations**: **unicode_plot** (CLI), **vega** (HTML/JSON). Wrapped in full HTML templates for browser viewing.
- **Naming Convention**: HTML outputs follow `[input_basename]_[chart_type].html` if not specified.
- **Duplicate Detection**: **jscpd** (Configured for 4 lines / 25 tokens).
- **Browser Validation**: **Playwright** (Used for verifying HTML chart rendering in the pipeline).
- **Coverage**: SimpleCov.
- **AI Evaluation**: Custom evaluation scripts for LLM outputs.
- **CI/CD**: GitHub Actions (ready for implementation).
