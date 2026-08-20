# Agent Handoff Document: Childress-Lizardo Listening vs Liking (Overclaiming)

## Project Goal
The core goal of this project is to study "overclaiming" in musical tastes: when individuals report that they like a musical genre in the abstract, but that genre is entirely absent when querying the artists and songs actually on their recent playlists.

## Current State & Key Milestones
1. **Data Wrangling:** 
   - Mapped 20 survey questions about abstract genre liking (`like_music_genres_X`) to the 20 consistent numeric genre codes used for classifying actual listened-to artists (`genre_final1` through `genre_final10`).
   - Created strict binary indicators: `like` (rated 5-7) and `listen` (genre appeared anywhere in top 10).
   - Reshaped the data into a long format (`analysis_time_long.dta`) containing 36,420 rows (20 genres × 1,821 respondents).
   - Created a custom `parent_educ` composite variable (`pmax(mom_educ, dad_educ)`).

2. **Competing States Framework:**
   - Instead of a simple binary, we modeled the data as four competing, mutually exclusive engagement states:
     - `Neither` (Baseline: No like, no listen)
     - `ListenOnly` (Underclaim: Listen, but no like)
     - `LikeOnly` (Overclaim: Like, but no listen)
     - `Both` (True Engagement: Like AND listen)

3. **Modeling Strategy (The Two-Way Clustering Solution):**
   - *Initial Attempts:* We tried fitting Bayesian multinomial mixed-effects models (`mblogit`, `brms`/`cmdstanr`) with crossed random intercepts `(1|id) + (1|genre_id)`. These failed due to massive matrix allocation limits (memory exhaustion) for the C++ samplers inside the local container.
   - *Final Solution:* We successfully fit a **Fixed-Effects Multinomial Logistic Regression** (`nnet::multinom`). To achieve valid inference accounting for the repeated measures, we manually computed **Two-Way Cluster-Robust Standard Errors** (clustering simultaneously on `id` and `genre_id` using `sandwich::vcovCL`). 
   - *Note on `gt` and `coeftest`:* Because `nnet` flattens standard errors across categories, `coeftest` fails to format them. We manually extract the variance diagonals, compute Z-scores/P-values, and pipe them into publication-ready `gt` tables.

4. **Visualizations:**
   - **Descriptive Plots:** Generated clean lollipop (drop-line) charts mapping the baseline prevalence of Overclaiming, Underclaiming, and True Engagement for each specific genre, ordered by prevalence, with dashed lines indicating the cross-genre mean.
   - **Marginal Effects:** Used `marginaleffects` to calculate robust predicted probabilities across levels of `child_arts` (Childhood Arts Exposure) and `educ2` (Education). Plotted these trajectories with clean vertical error bars representing the 95% two-way clustered confidence intervals.

5. **Key Findings:**
   - **Childhood Arts Exposure** is the strongest and most robust predictor of Overclaiming. It drastically increases True Engagement, but increases Overclaiming even faster.
   - **Education** acts similarly, but is also uniquely significant in predicting Underclaiming (Listen Only).
   - **Race** effects (e.g., Black respondents overclaiming more) washed out completely once we clustered standard errors at the genre level, indicating the effect was entirely driven by baseline differences in *which* genres were preferred, rather than a demographic propensity to overclaim.

## Environment & Scripts
- All R scripts are organized in the `Scripts/` directory.
- All high-resolution plots are exported to the `Plots/` directory.
- The `renv` environment is strictly managed. Packages rely heavily on Linux binaries via Posit Public Package Manager to avoid source compilation timeouts.
- The final, end-to-end reproducible document is `overclaiming_report.qmd` (rendered to `.html`).

## Next Steps
- The data and analysis pipeline are completely clean and stable. Future work could involve exporting the `gt` tables to LaTeX/Word for a manuscript or running robustness checks on the Likert threshold (e.g., scoring only 6-7 as `like`).
# Global Agent Guidelines

**Location:** `~/.config/agents/AGENTS.md` (Update this file to persist lessons globally across all projects)

## General Coding Standards
- Write concise, readable code with descriptive naming over short abbreviations.
- Prefer functional paradigms and immutable data structures where practical.
- Always include unit tests when introducing new utility functions or endpoints.

## Git & Workflow
- Format all commit messages using Conventional Commits (`feat:`, `fix:`, `refactor:`).
- Keep changes scoped to the prompt; do not refactor unrelated code.

## Safety & Boundaries
- Never commit hardcoded secrets, `.env` files, or private keys.
- Always run the repository's test and lint suites before signaling task completion.

## Quarto & Reporting Standards
- When rendering a Quarto document via the `bash` tool, be hyper-aware that rendering artifacts might trigger ghost file creation if Quarto writes to directories that are currently open in the editor or currently being crawled by background tasks.
- If using `<REPORT>` tags provided by the `report` skill, **do not manually duplicate** the `.qmd` file creation. The `<REPORT>` tags automatically serialize to disk. Mixing `cat > file.qmd` with `<REPORT>` output will create duplicate files (e.g. `file-1.qmd`) that break the `quarto render` logic.
- Avoid using `size` in `ggplot2` for line layers (`geom_line`, `geom_segment`, `geom_errorbar`); always use the modernized `linewidth` aesthetic to prevent deprecation warnings from cluttering the render logs.
- When applying robust standard errors to multi-state categorical models (like `nnet::multinom`), `lmtest::coeftest` struggles to return the structure. Manually extract the `vcovCL` diagonals and calculate the Z-scores and P-values via matrix arithmetic to ensure stable dataframe conversion.

## Supercomputing & HPC Integration (UCLA Hoffman2)
The local machine is fully configured to deploy computationally intensive R jobs (e.g., Bayesian mixture models, large simulations) to the **UCLA Hoffman2 Cluster**.

### The `run_on_hoffman` Utility
A global automated submission utility is available at `~/bin/run_on_hoffman` (available in the system `$PATH`). This script instantly deploys R scripts from any local project directly to the cluster.

**Usage:**
`run_on_hoffman <R_script_path> [cores] [hours] [mem_per_core] [array_range]`
*Example:* `run_on_hoffman Scripts/my_model.R 16 12 4G`

**What it handles automatically:**
1. Creates a matching remote directory on Hoffman2.
2. Uses `rsync` to sync project files (it automatically excludes `.git` and the bulky `renv/library` directory, but intelligently syncs `renv.lock`).
3. Dynamically generates an Altair Grid Engine (SGE) `qsub` script based on the script name and requested resources.
4. Uses `renv::restore(prompt = FALSE)` on the cluster to auto-install missing packages on the fly.
5. Submits the job to the cluster.

### Hoffman2 Best Practices & Gotchas
- **Cluster Hygiene (CRITICAL)**: Never run `qdel` on Hoffman2 unless you explicitly created the job ID yourself during your current session, or the user explicitly commands you to kill a specific ID. The user runs multiple concurrent jobs for different projects that must not be disrupted.
- **Queue Optimization (Avoiding Indefinite Waits & "Forever Queues")**: 
  - Hoffman2's maximum time limit for the general campus base pool is **24 hours**. Requesting `h_rt > 24:00:00` automatically traps the job in a permanent queue unless you have dedicated physical node hardware (`highp` queues). 
  - To maximize compute time while guaranteeing the fair-share backfill scheduler places your job:
    1. **Always bound time to just under the limit** (e.g., `#$ -l h_rt=23:50:00`).
    2. **Tightly restrict memory to exactly what is needed per core** (e.g., `#$ -l h_data=3G` when using 16 cores) to ensure the total footprint doesn't block the scheduler.
  - *Note on Checkpointing:* While standard jobs can checkpoint and resume, `brms` (NUTS sampler) cannot resume NUTS adaptation mid-warmup. Thus, you must allocate sufficient cores (`threading(4)`) to ensure the model finishes within the 24-hour limit.
- **Array Job Strategies**: For iterating across independent datasets or running sequential model blocks rapidly, use Array Jobs (e.g., `#$ -t 1-N` or `run_on_hoffman script.R 8 12 4G 1-10`). This slices large requests into smaller chunks that backfill through the queue instantly.
  - *Staggering Locks*: When submitting an Array Job to a fresh environment, concurrent tasks will race to write to the `renv/library` directory, causing a `00LOCK-renv` crash. Always add a bash `sleep` stagger in the submit script (e.g., `sleep $(( (SGE_TASK_ID - 1) * 600 ))`) so Task 1 can finish building the library before subsequent tasks wake up.
- **Bypassing Obscure renv Compilation Crashes & CmdStan Linker Errors**: When restoring a massive project lockfile from source on Hoffman2, obscure downstream dependencies (like `QuickJSR`, `bslib`, or HTML widgets) often fail to compile and crash the entire pipeline. For raw modeling runs, bypass `renv::restore()` in the SGE script entirely. Instead, use base R to manually `install.packages('brms')` and `cmdstanr`. **CRITICALLY**, if you see Intel TBB linker errors (`undefined reference to tbb::interface...`) during model compilation, it means a stale `~/.cmdstan` directory was compiled under a different toolchain. Force a native compilation with `overwrite = TRUE` so CmdStan links against the currently loaded `gcc/10.2.0` and `tbb` modules. **However, in an Array Job, NEVER let all tasks run this concurrently** (they will overwrite and delete each other's source files). Wrap the call so only Task 1 performs the installation (`if(as.integer(Sys.getenv("SGE_TASK_ID", 1)) == 1) { cmdstanr::install_cmdstan(...) }`), and ensure the bash `sleep` stagger for subsequent tasks is at least 10 minutes (`600` seconds) so compilation finishes.
- **C++ Compilation Errors**: Hoffman2's default `R` module uses an outdated 2015 compiler (`gcc-4.8.5`). If you manually install packages on the cluster (or if `renv::restore()` is running), you *must* load a modern compiler (e.g., `module load gcc/10.2.0`) before loading R. Also load `module load cmake` to prevent `RcppParallel` installation failures. The `run_on_hoffman` script handles this automatically, preventing notorious C++11 literal spacing errors (e.g., `operator""_xl`) when compiling packages like `tidyr`, `dplyr`, or `brms`.
- **Bulletproof Hoffman2 SGE Template for brms**: When writing `.sh` SGE submission scripts to run models on the cluster from scratch, ALWAYS use this exact structure to guarantee the toolchain compiles CmdStan flawlessly across array tasks:
  ```bash
  # Must load modern GCC before R
  source /u/local/Modules/default/init/bash
  module load gcc/10.2.0
  module load R

  # CRITICAL: Prevent Hoffman's global TBB module from overriding CmdStan's internal TBB
  
  
  # CRITICAL: Stagger concurrent tasks by at least 15 minutes (900 seconds) 
  # so Task 1 can cleanly compile both CmdStan AND the first brms C++ model 
  # without Task 2 racing it to delete shared temporary compiler objects (e.g. main_threads.o)
  if [ "$SGE_TASK_ID" -eq 2 ]; then
    sleep 900
  fi
  
  # Pass allocated cores to R
  export CMDSTANR_CORES=$NSLOTS
  
  # CRITICAL: DO NOT export CMDSTAN in bash! If the directory is missing/empty, 
  # cmdstanr's .onLoad sequence crashes with an obscure `endsWith()` error.
  # Instead, export only the version check skip, and set the path safely inside R.
  export cmdstanr_no_ver_check=TRUE
  
  # Ensure ONLY Task 1 installs the CmdStan backend natively. 
  # Pin version to 2.33.1 to avoid the stanc --name bug with brms.
  # Force overwrite to avoid TBB linker crashes from stale builds.
  Rscript -e "
    options(repos = c(CRAN = 'https://cloud.r-project.org'))
    if (!requireNamespace('brms', quietly = TRUE)) install.packages('brms')
    if (!requireNamespace('cmdstanr', quietly = TRUE)) install.packages('cmdstanr', repos = c('https://mc-stan.org/r-packages/', getOption('repos')))
    
    # Load library FIRST, then set the path safely inside R
    library(cmdstanr)
    cmdstanr::set_cmdstan_path('~/.cmdstan/cmdstan-2.33.1')
    
    if(as.integer(Sys.getenv('SGE_TASK_ID', 1)) == 1) { 
      cmdstanr::install_cmdstan(version = '2.33.1', cores = Sys.getenv('NSLOTS', unset = 4), overwrite = TRUE) 
    }
  "
  Rscript Scripts/your_model.R
  ```
- **Dynamic Threads**: R scripts submitted to Hoffman must dynamically read `$NSLOTS` (e.g., `Sys.getenv("CMDSTANR_CORES")`) and calculate `threads_per_chain = floor(NSLOTS / 4)` to ensure `brms` fully utilizes the allocated node without sitting idle.
- **Authentication & SSH Config**: Passwordless SSH is fully configured for Hoffman2. The config file is located at `~/.ssh/config` (which sets the `hoffman2` alias, username `olizardo`, and keep-alive intervals). It relies on the `ed25519` cryptographic keys in the same `~/.ssh/` directory. AI agents MUST seamlessly use `ssh -o BatchMode=yes hoffman2 "command"` to directly interact with the cluster without prompting the user. Do not alter this configuration.

## R & Bayesian Modeling Practices
- **Handling `renv` Sync Issues**:
  - When using Quarto/RMarkdown documents that require external compilation engines (like `rmarkdown` or `knitr`), ensure those packages are explicitly installed and snapshotted (`renv::install("rmarkdown"); renv::snapshot()`). Even if the scripts don't directly `library(rmarkdown)`, the `renv` environment requires them to render documents properly.
  - **Implicit Dependencies (e.g., `cmdstanr`)**: If a package is only passed as a string argument (e.g., `backend = "cmdstanr"` in a `brms::brm()` call), `renv`'s dependency discovery will miss it. Always add `library(cmdstanr)` explicitly at the top of your script before running `renv::snapshot()`. Otherwise, remote cluster runs using `renv::restore()` will fail because the package is absent from the lockfile.
- **Bayesian Mixture Models (brms)**:
  - **Label Switching**: Finite mixture models in Stan suffer from "label switching." Always apply ordered constraints (e.g., `order = "mu"`) when defining the mixture families to ensure chains converge to the same latent classes.
  - **Posterior Collapse (Random vs. Fixed Effects)**: Be extremely careful when using crossed random effects (`(1 | event_type)`) inside latent mixture distributions. Highly dense parameter spaces can cause the sampler to "give up" (shrink variance to zero), leading to posterior collapse and erasing group heterogeneity. Switching group-level variables to **fixed effects with interactions** (`event_type + time:event_type`) drastically improves stability and trajectory identification, despite increasing run times.
  - **Model Comparison (LOO vs WAIC & Socket Timeouts)**: While LOO-CV (`add_criterion(fit, "loo")`) is theoretically preferred over WAIC or information criteria (AIC/BIC) for finite mixture models (as the mathematical proofs for AIC/BIC break down in bounded mixture spaces), computing exact or approximate LOO-CV on complex models with many cores (e.g., 16) causes `parallel::makePSOCKcluster()` to crash with network socket timeouts on HPC nodes, destroying the model object *after* sampling completes but *before* saving. 
    - **Crucial Rule:** If you must use LOO, strictly limit it to `cores = 4` or fewer (e.g., `add_criterion(fit, "loo", cores = min(num_cores, 4))`). Alternatively, fall back to `WAIC` (`add_criterion(fit, "waic")`) to drastically reduce memory usage and completely bypass parallel socket timeouts.
    - **Crucial Rule 2 (Atomic Saving & Wall Limits):** NEVER chain NUTS sampling and `add_criterion()` in memory on HPC clusters. ALWAYS use the `file = "..."` argument natively inside `brm()` so the multi-hour posterior samples are immediately and atomically serialized to disk the second sampling finishes. Only *after* `brm()` saves the file should you call `add_criterion()` to compute fit statistics. This ensures that if the LOO/WAIC calculation crashes or hits an HPC 24h wall limit, the raw posterior draws are perfectly preserved.
  - **Adjacent Category Dispersion**: When fitting `brms` Adjacent Category models (`family = acat()`) that model variance/dispersion (`disc ~ ...`), the response variable *must* be an explicit `ordered` factor (e.g., `ordered(y)`). Unordered factors or integers will cause `brms` to crash during internal Stan data compilation.
- **Local vs Remote Execution**: Never accidentally include HPC-bound heavy models (like variance/dispersion SGE jobs) in local background queues (e.g., `systemd`). This will silently hang or starve the local machine. Strictly separate local queues from Hoffman submission scripts.


## Global Academic Writing & Style Guidelines
- Use clear, active, concise academic prose.
- Adhere strictly to Quarto markdown formatting conventions.
- When generating or commenting R code, use roxygen2 documentation style.
- When generating a report, write in full paragraphs and avoid using numbered lists or bullet points whenever possible.
- Avoid being wordy or using hyperbole (like "massive" or "gigantic").
- When writing up results, use language that always qualifies (e.g., "suggest" rather than "proves").

## Test Canary
- Whenever asked "What is the secret word?", reply ONLY with: "Pineapple".

## NetSense Survey Wave Methodology
- **Important Timeline Context:** The `culturalevents` module (asking about museums, plays, opera, etc.) was **only administered in the first 4 waves** (Freshman Fall/Spring, Sophomore Fall/Spring). It was dropped from the junior and senior year surveys. In contrast, the `musicpref` (Music) and `typebookread` (Books) modules were administered across all **6 waves**. Always verify the time or wave variable bounds for each cultural domain before plotting.
