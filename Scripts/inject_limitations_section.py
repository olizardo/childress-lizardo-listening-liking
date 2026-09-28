#!/usr/bin/env python3
"""Insert a new '# Limitations' section (Heading1 + 5 body paragraphs) into
word/document.xml immediately before the existing 'References' Heading1
paragraph. Idempotent: does nothing if a 'Limitations' Heading1 paragraph
already exists. Usage:
    python3 inject_limitations_section.py <in_docx> <out_docx>
"""
import sys
import re
import zipfile
import xml.etree.ElementTree as ET

def esc(s):
    return (s.replace("&", "&amp;")
             .replace("<", "&lt;")
             .replace(">", "&gt;")
             .replace('"', "&quot;"))

def body_paragraph(bold_lead, rest_text):
    """A plain body paragraph: bold lead-in phrase followed by regular text."""
    return (
        '<w:p><w:pPr><w:rPr/></w:pPr>'
        f'<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve">{esc(bold_lead)} </w:t></w:r>'
        f'<w:r><w:rPr/><w:t xml:space="preserve">{esc(rest_text)}</w:t></w:r>'
        '</w:p>'
    )

def heading1_paragraph(text):
    return (
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/><w:rPr/></w:pPr>'
        f'<w:r><w:rPr/><w:t xml:space="preserve">{esc(text)}</w:t></w:r>'
        '</w:p>'
    )

PARAGRAPHS = [
    ("Genre-level random-slope identifiability.",
     "The genre-specific intercept-slope correlation reported in Step 4 "
     "(r = -0.83 between baseline overclaiming propensity and responsiveness to "
     "childhood arts exposure) is estimated from only J = 20 genre clusters, a "
     "small basis for jointly identifying a random intercept, a random slope, "
     "and their correlation. To assess how much this estimate depends on the "
     "LKJ prior's concentration parameter, we refit the crossed random-slopes "
     "specification under LKJ(1) (uniform over correlation matrices) and LKJ(4) "
     "(stronger shrinkage toward zero correlation), holding all other priors "
     "and the model structure fixed. The posterior median correlation moved "
     "from -0.65 (95% CrI: [-0.85, -0.31]) under LKJ(4) to -0.73 (95% CrI: "
     "[-0.90, -0.43]) under the originally specified LKJ(2) to -0.77 (95% CrI: "
     "[-0.92, -0.51]) under LKJ(1). All three priors yield a credible interval "
     "excluding zero, so the qualitative conclusion (genres with lower baseline "
     "popularity show steeper arts-exposure responsiveness) is not an artifact "
     "of the prior choice, but the magnitude of the correlation is not fully "
     "pinned down by only 20 clusters and should be read as falling in the "
     "-0.65 to -0.77 range rather than as a single precise value. This "
     "sensitivity check was conducted on Model 5 (Full Crossed Random Slopes), "
     "whose LikeOnly random-slope structure is identical to Model 4's; we do "
     "not expect the range to differ materially had the check instead been "
     "run on Model 4 directly."),
    ("Small-cell platform reporting.",
     "The platform predictor's Winamp category comprises only 10 respondents, "
     "yet receives its own fixed-effect indicator in every model, and platform "
     "retrieval method ranked second among predictor blocks in the joint "
     "importance tests of Step 2. To check whether this small cell distorts "
     "the substantively central childhood-arts-exposure estimates, we refit "
     "the baseline model (a) excluding Winamp respondents entirely and (b) "
     "collapsing Winamp into the \u201cOther\u201d category. The child_arts "
     "coefficients were essentially unchanged across all three specifications "
     "(e.g., the LikeOnly coefficient was 0.231 with Winamp included, 0.231 "
     "with Winamp dropped, and 0.232 with Winamp collapsed), indicating the "
     "headline overclaiming findings are not being driven by this small cell. "
     "The platform predictor's own joint importance ranking should nonetheless "
     "be treated with some caution given how few observations anchor the "
     "Winamp estimate specifically."),
    ("Single-item measurement of childhood arts exposure.",
     "The child_arts variable \u2014 the predictor underlying nearly every "
     "finding in this report \u2014 is measured with a single 7-point survey "
     "item asking how frequently parents or guardians engaged the respondent "
     "with the arts during childhood. No split-half or test-retest reliability "
     "estimate is available for this item, and single-item measures of a "
     "construct as broad as \u201cchildhood arts socialization\u201d are "
     "inherently susceptible to measurement error that could attenuate or "
     "(less commonly) inflate the estimated associations reported here. We "
     "separately checked whether the child_arts estimates were sensitive to "
     "the fixed-effect prior's width (comparing the originally specified "
     "Normal(0, 1.5) against a wider Normal(0, 3) prior on Model 1); the "
     "coefficients were essentially identical (e.g., LikeOnly: 0.231 vs. "
     "0.230), so the reported effects are not artifacts of prior "
     "regularization. This does not, however, address the underlying "
     "single-item measurement concern, which would require independent "
     "validation data to resolve."),
    ("WAIC approximation quality.",
     "As noted in Step 3, three of the five fitted specifications (Models 1, "
     "2, and 3) had between 2.8% and 3.0% of observations with a "
     "WAIC-specific diagnostic (p_waic) exceeding 0.4, the conventional "
     "threshold at which the WAIC approximation is flagged as potentially "
     "unreliable and PSIS-LOO is recommended instead. We retained WAIC "
     "throughout, consistent with this project's prior finding that full "
     "leave-one-out cross-validation with many parallel cores produces "
     "socket timeouts on our computing cluster. Because the affected models "
     "(1\u20133) are not close contenders for the preferred specification \u2014 "
     "they are decisively outperformed by Models 4 and 5 by a wide margin "
     "relative to their paired standard errors \u2014 this approximation "
     "concern is unlikely to change which model is preferred, but the exact "
     "WAIC point estimates for Models 1\u20133 should be read as approximate "
     "rather than exact."),
    ("Asymptotic approximation in the joint importance tests.",
     "The Table 1 test statistics (Step 2) are computed by treating each "
     "predictor block's posterior mean and covariance as characterizing an "
     "asymptotically normal distribution and referring the resulting "
     "quadratic form to a chi-square reference distribution. We checked the "
     "univariate skewness and excess kurtosis of every constituent "
     "coefficient's marginal posterior (Table 1b) and found all 39 within "
     "conventional bounds, which is consistent with, but does not prove, the "
     "multivariate normality this approximation assumes."),
]

def build_section_xml():
    parts = [heading1_paragraph("Limitations")]
    for lead, rest in PARAGRAPHS:
        parts.append(body_paragraph(lead, rest))
    return "".join(parts)

def inject(in_path, out_path):
    with zipfile.ZipFile(in_path, "r") as zin:
        names = zin.namelist()
        data = {n: zin.read(n) for n in names}

    text = data["word/document.xml"].decode("utf-8")

    # Idempotency check: does a Limitations Heading1 paragraph already exist?
    already = re.search(
        r'<w:p[^>]*>(?:(?!</w:p>).)*?<w:pStyle w:val="Heading1"/>(?:(?!</w:p>).)*?<w:t[^>]*>\s*Limitations\s*</w:t>',
        text, re.DOTALL
    )
    if already:
        print("[skip] A 'Limitations' Heading1 section already exists; no changes made.")
        with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zout:
            for n in names:
                zout.writestr(n, data[n])
        return

    # Find the References Heading1 paragraph and insert the new section
    # immediately before it.
    pattern = re.compile(
        r'(<w:p[^>]*>(?:(?!</w:p>).)*?<w:pStyle w:val="Heading1"/>(?:(?!</w:p>).)*?<w:t[^>]*>\s*References\s*</w:t>(?:(?!</w:p>).)*?</w:p>)',
        re.DOTALL
    )
    match = pattern.search(text)
    if not match:
        raise RuntimeError("Could not find the 'References' Heading1 paragraph to anchor insertion.")

    section_xml = build_section_xml()
    new_text = text[:match.start()] + section_xml + text[match.start():]

    # Validate XML well-formedness before writing
    ET.fromstring(new_text.encode("utf-8"))

    data["word/document.xml"] = new_text.encode("utf-8")

    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            zout.writestr(n, data[n])
    print("[ok] Inserted 'Limitations' section before 'References'.")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: inject_limitations_section.py <in_docx> <out_docx>")
        sys.exit(1)
    inject(sys.argv[1], sys.argv[2])
