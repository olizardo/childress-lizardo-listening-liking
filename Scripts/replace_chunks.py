import re

def process_qmd(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Remove specific chunks completely
    chunks_to_remove = [
        "load-packages",
        "data-preparation",
        "create-outcomes-clean",
        "load-bayesian-model",
        "bayesian-equation-tables"
    ]
    for chunk in chunks_to_remove:
        pattern = re.compile(r'```\{r\}\n#\| label: ' + chunk + r'.*?```\n', re.DOTALL)
        content = re.sub(pattern, '', content)

    # 2. Replace specific chunks with static markdown
    replacements = {
        "corrected-random-intercepts-plots": "![](Plots/Purged_Genre_Engagement_Profiles.png)\n",
        "bayesian-wald-tests": "{{< include cache/table1_wald.md >}}\n",
        "results-overclaim": "{{< include cache/table2_overclaim.md >}}\n",
        "results-underclaim": "{{< include cache/table3_underclaim.md >}}\n",
        "results-consistent": "{{< include cache/table4_consistent.md >}}\n",
        "marginal-effects-plot": "![](Plots/ChildArts_Effects_Bayesian_CrI.png)\n",
        "omnivorousness-capacity-plot": "![](Plots/ChildArts_Omnivorousness_Capacity.png)\n",
        "model-fit-comparison": "{{< include cache/table5_fit.md >}}\n",
        "bayesian-halfeye-odds": "![](Plots/ChildArts_Odds_Overclaiming_HalfEye.png)\n",
        "random-effects-correlation": "![](Plots/Overclaim_Random_Intercept_Slope_Correlation.png)\n",
        "bayesian-odds-prestige-correlation": "![](Plots/Bayesian_Odds_Prestige_Correlation.png)\n"
    }
    
    for chunk, replacement in replacements.items():
        pattern = re.compile(r'```\{r\}\n#\| label: ' + chunk + r'.*?```\n', re.DOTALL)
        content = re.sub(pattern, replacement, content)
        
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

process_qmd("overclaiming_report.qmd")
