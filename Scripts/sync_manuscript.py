"""
sync_manuscript.py - In-Place Google Drive / Word Manuscript Sync Script
Childress-Lizardo Listening vs Liking Project

Places placeholders in the main text ([Table X about here], [Figure X about here])
and places all Tables (1-5) and Figures (1-6) at the end of the document,
each on its own separate page with zero paragraph indentation and clean font typography.
"""

import os
import re
import sys
import zipfile
import struct
import xml.etree.ElementTree as ET

DOC_ID = "1vXW0PsCeXUghrCbfIylU-RjzpjQOK1uqrZ03NNMnb7k"

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
WP_NS = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"

def xml_escape(s):
    if s is None:
        return ""
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")

def get_image_dimensions(image_path):
    with open(image_path, "rb") as f:
        data = f.read(24)
        if len(data) >= 24 and data.startswith(b'\x89PNG\r\n\x1a\n'):
            w, h = struct.unpack('>II', data[16:24])
            return w, h
    return 1950, 1200

def cell_text_to_runs_xml(cell_text, is_header=False):
    lines = re.split(r'<br\s*/?>|\n', str(cell_text))
    runs = []
    
    for line_idx, line in enumerate(lines):
        if line_idx > 0:
            runs.append('<w:r><w:br/></w:r>')
            
        # Parse bold tags (<b>...</b>, <strong>...</strong>, or **...**)
        tokens = re.split(r'(<b>.*?</b>|<strong>.*?</strong>|\*\*.*?\*\*)', line)
        for token in tokens:
            if not token:
                continue
            is_bold = is_header
            text_content = token
            if (token.startswith("<b>") and token.endswith("</b>")) or (token.startswith("<strong>") and token.endswith("</strong>")):
                is_bold = True
                text_content = re.sub(r'^<[^>]+>|<[^>]+>$', '', token)
            elif token.startswith("**") and token.endswith("**") and len(token) >= 4:
                is_bold = True
                text_content = token[2:-2]
                
            r_pr = '<w:rPr><w:b/></w:rPr>' if is_bold else ''
            runs.append(f'<w:r>{r_pr}<w:t xml:space="preserve">{xml_escape(text_content)}</w:t></w:r>')
            
    return "".join(runs)

def create_apa_table_xml(headers, rows_data, col_widths=None):
    total_w = 9360  # 6.5 in portrait printable width in dxa
    num_cols = len(headers)
    if col_widths is None:
        col1_w = int(total_w * 0.38)
        rem_w = total_w - col1_w
        sub_w = int(rem_w / (num_cols - 1))
        col_widths = [col1_w] + [sub_w] * (num_cols - 2)
        col_widths.append(total_w - sum(col_widths))
        
    xml = [f'<w:tbl xmlns:w="{W_NS}"><w:tblPr><w:tblW w:w="{total_w}" w:type="dxa"/><w:tblBorders><w:top w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:left w:val="none"/><w:bottom w:val="single" w:sz="8" w:space="0" w:color="000000"/><w:right w:val="none"/><w:insideH w:val="none"/><w:insideV w:val="none"/></w:tblBorders><w:tblCellMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="160" w:type="dxa"/><w:right w:w="160" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>']
    for w in col_widths:
        xml.append(f'<w:gridCol w:w="{w}"/>')
    xml.append('</w:tblGrid>')
    
    # Header Row
    xml.append('<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>')
    for i, h in enumerate(headers):
        align = "left" if i == 0 else "center"
        runs_xml = cell_text_to_runs_xml(h, is_header=True)
        xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:tcBorders><w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000"/></w:tcBorders><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr>{runs_xml}</w:p></w:tc>')
    xml.append('</w:tr>')
    
    # Data Rows
    for row in rows_data:
        xml.append('<w:tr><w:trPr><w:cantSplit/></w:trPr>')
        for i, val in enumerate(row):
            align = "left" if i == 0 else "center"
            runs_xml = cell_text_to_runs_xml(val, is_header=False)
            xml.append(f'<w:tc><w:tcPr><w:tcW w:w="{col_widths[i]}" w:type="dxa"/><w:noWrap/></w:tcPr><w:p><w:pPr><w:suppressAutoHyphens/><w:spacing w:before="0" w:after="0"/><w:ind w:left="0" w:right="0" w:firstLine="0" w:hanging="0"/><w:jc w:val="{align}"/></w:pPr>{runs_xml}</w:p></w:tc>')
        xml.append('</w:tr>')
    xml.append('</w:tbl>')
    return "".join(xml)

def parse_markdown_table(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        lines = [line.strip() for line in f if line.strip()]
    table_lines = [line for line in lines if line.startswith("|") and line.endswith("|")]
    if len(table_lines) < 3:
        return [], []
    
    headers = [c.strip() for c in table_lines[0].strip("|").split("|")]
    rows = []
    for line in table_lines[2:]:
        row = [c.strip() for c in line.strip("|").split("|")]
        rows.append(row)
    return headers, rows

TABLES_CONFIG = {
    "Table 1": {
        "num": "Table 1",
        "title": "Joint Variable Importance (Bayesian Wald χ²)",
        "note": "Multivariate Distance from Null Origin across All Engagement Logits (Baseline Random Intercepts Model).",
        "file": "cache/table1_wald.md",
        "headers": ["Predictor", "Bayesian Wald χ²", "df", "p"],
        "widths": [4212, 1872, 1404, 1872]
    },
    "Table 2": {
        "num": "Table 2",
        "title": "Predictors of Overclaiming (Like Only)",
        "note": "Posterior Estimates from Baseline Crossed Random Intercepts Model (Ref: Neither). * pd ≥ 0.975 (95% CrI excludes 0), ** pd ≥ 0.99, *** pd ≥ 0.999.",
        "file": "cache/table2_overclaim.md",
        "headers": ["Predictor", "Mean", "Median", "SD", "95% CrI Low", "95% CrI High", "pd"],
        "widths": [2760, 1160, 1060, 1040, 1120, 1120, 1100]
    },
    "Table 3": {
        "num": "Table 3",
        "title": "Predictors of Underclaiming (Listen Only)",
        "note": "Posterior Estimates from Baseline Crossed Random Intercepts Model (Ref: Neither). * pd ≥ 0.975 (95% CrI excludes 0), ** pd ≥ 0.99, *** pd ≥ 0.999.",
        "file": "cache/table3_underclaim.md",
        "headers": ["Predictor", "Mean", "Median", "SD", "95% CrI Low", "95% CrI High", "pd"],
        "widths": [2760, 1160, 1060, 1040, 1120, 1120, 1100]
    },
    "Table 4": {
        "num": "Table 4",
        "title": "Predictors of Consistent (Both)",
        "note": "Posterior Estimates from Baseline Crossed Random Intercepts Model (Ref: Neither). * pd ≥ 0.975 (95% CrI excludes 0), ** pd ≥ 0.99, *** pd ≥ 0.999.",
        "file": "cache/table4_consistent.md",
        "headers": ["Predictor", "Mean", "Median", "SD", "95% CrI Low", "95% CrI High", "pd"],
        "widths": [2760, 1160, 1060, 1040, 1120, 1120, 1100]
    },
    "Table 5": {
        "num": "Table 5",
        "title": "Bayesian Mixed-Effects Model Fit Comparison",
        "note": "Out-of-Sample Predictive Accuracy across Crossed Hierarchical Specifications (N = 24,457 person-genre dyads).",
        "file": "cache/table5_fit.md",
        "headers": ["Model", "Under", "Over", "Both", "Par", "WAIC<br>(SE)", "ΔWAIC"],
        "widths": [1700, 1150, 1150, 1150, 950, 1750, 1510]
    }
}

FIGURES_CONFIG = {
    "Figure 1.": {
        "num": "Figure 1.",
        "caption": " Relative Genre Engagement Profiles Purged of Baseline Popularity. Within-genre centered random intercepts showing log-odds deviations across complex taste configurations relative to genre mean engagement.",
        "img": "Plots/Purged_Genre_Engagement_Profiles.png"
    },
    "Figure 2.": {
        "num": "Figure 2.",
        "caption": " Posterior Expected Probabilities of Genre Complex Tastes across Childhood Arts Exposure Levels. Expected probabilities for each complex taste state computed across the childhood arts exposure scale using the Bayesian crossed random slopes model.",
        "img": "Plots/ChildArts_Effects_Bayesian_CrI.png"
    },
    "Figure 3.": {
        "num": "Figure 3.",
        "caption": " Divergence Between Stated Preferences and Concrete Listening Repertoires Across Levels of Cultural Socialization.",
        "img": "Plots/ChildArts_Omnivorousness_Capacity.png"
    },
    "Figure 4.": {
        "num": "Figure 4.",
        "caption": " Genre-Specific Marginal Effects of Childhood Arts Exposure on Symbolic Overclaiming. Bayesian posterior odds ratios evaluating the shift in overclaiming odds for extensive versus absent childhood arts exposure across twenty musical genres.",
        "img": "Plots/ChildArts_Odds_Overclaiming_HalfEye.png"
    },
    "Figure 5.": {
        "num": "Figure 5.",
        "caption": " Structural Bivariate Association between Baseline Overclaiming Propensity and Cultural Capital Sensitivity. Scatterplot of posterior genre random intercepts against childhood arts exposure random slopes for the overclaiming equation.",
        "img": "Plots/Overclaim_Random_Intercept_Slope_Correlation.png"
    },
    "Figure 6.": {
        "num": "Figure 6.",
        "caption": " Class Legitimation and Bayesian Overclaiming Odds Ratios across Educational Prestige. Relationship between educational class prestige and genre-specific Bayesian odds ratios of overclaiming.",
        "img": "Plots/Bayesian_Odds_Prestige_Correlation.png"
    }
}

def make_placeholder_elem(text):
    p = ET.Element(f'{{{W_NS}}}p')
    pPr = ET.SubElement(p, f'{{{W_NS}}}pPr')
    ET.SubElement(pPr, f'{{{W_NS}}}suppressAutoHyphens')
    sp = ET.SubElement(pPr, f'{{{W_NS}}}spacing')
    sp.set(f'{{{W_NS}}}before', '240')
    sp.set(f'{{{W_NS}}}after', '240')
    ind = ET.SubElement(pPr, f'{{{W_NS}}}ind')
    ind.set(f'{{{W_NS}}}left', '0')
    ind.set(f'{{{W_NS}}}right', '0')
    ind.set(f'{{{W_NS}}}firstLine', '0')
    ind.set(f'{{{W_NS}}}hanging', '0')
    jc = ET.SubElement(pPr, f'{{{W_NS}}}jc')
    jc.set(f'{{{W_NS}}}val', 'center')
    
    r = ET.SubElement(p, f'{{{W_NS}}}r')
    rPr = ET.SubElement(r, f'{{{W_NS}}}rPr')
    ET.SubElement(rPr, f'{{{W_NS}}}i')
    t = ET.SubElement(r, f'{{{W_NS}}}t')
    t.text = text
    return p

def make_table_title_elems(table_num, table_title):
    p1 = ET.Element(f'{{{W_NS}}}p')
    pPr1 = ET.SubElement(p1, f'{{{W_NS}}}pPr')
    ET.SubElement(pPr1, f'{{{W_NS}}}pageBreakBefore')
    ET.SubElement(pPr1, f'{{{W_NS}}}suppressAutoHyphens')
    sp1 = ET.SubElement(pPr1, f'{{{W_NS}}}spacing')
    sp1.set(f'{{{W_NS}}}before', '240')
    sp1.set(f'{{{W_NS}}}after', '60')
    ind1 = ET.SubElement(pPr1, f'{{{W_NS}}}ind')
    ind1.set(f'{{{W_NS}}}left', '0')
    ind1.set(f'{{{W_NS}}}right', '0')
    ind1.set(f'{{{W_NS}}}firstLine', '0')
    ind1.set(f'{{{W_NS}}}hanging', '0')
    jc1 = ET.SubElement(pPr1, f'{{{W_NS}}}jc')
    jc1.set(f'{{{W_NS}}}val', 'left')
    r1 = ET.SubElement(p1, f'{{{W_NS}}}r')
    rPr1 = ET.SubElement(r1, f'{{{W_NS}}}rPr')
    ET.SubElement(rPr1, f'{{{W_NS}}}b')
    t1 = ET.SubElement(r1, f'{{{W_NS}}}t')
    t1.text = table_num
    
    p2 = ET.Element(f'{{{W_NS}}}p')
    pPr2 = ET.SubElement(p2, f'{{{W_NS}}}pPr')
    ET.SubElement(pPr2, f'{{{W_NS}}}suppressAutoHyphens')
    sp2 = ET.SubElement(pPr2, f'{{{W_NS}}}spacing')
    sp2.set(f'{{{W_NS}}}before', '0')
    sp2.set(f'{{{W_NS}}}after', '120')
    ind2 = ET.SubElement(pPr2, f'{{{W_NS}}}ind')
    ind2.set(f'{{{W_NS}}}left', '0')
    ind2.set(f'{{{W_NS}}}right', '0')
    ind2.set(f'{{{W_NS}}}firstLine', '0')
    ind2.set(f'{{{W_NS}}}hanging', '0')
    jc2 = ET.SubElement(pPr2, f'{{{W_NS}}}jc')
    jc2.set(f'{{{W_NS}}}val', 'left')
    r2 = ET.SubElement(p2, f'{{{W_NS}}}r')
    rPr2 = ET.SubElement(r2, f'{{{W_NS}}}rPr')
    ET.SubElement(rPr2, f'{{{W_NS}}}i')
    t2 = ET.SubElement(r2, f'{{{W_NS}}}t')
    t2.text = table_title
    
    return p1, p2

def make_table_note_elem(note_text):
    p = ET.Element(f'{{{W_NS}}}p')
    pPr = ET.SubElement(p, f'{{{W_NS}}}pPr')
    ET.SubElement(pPr, f'{{{W_NS}}}suppressAutoHyphens')
    sp = ET.SubElement(pPr, f'{{{W_NS}}}spacing')
    sp.set(f'{{{W_NS}}}before', '120')
    sp.set(f'{{{W_NS}}}after', '240')
    ind = ET.SubElement(pPr, f'{{{W_NS}}}ind')
    ind.set(f'{{{W_NS}}}left', '0')
    ind.set(f'{{{W_NS}}}right', '0')
    ind.set(f'{{{W_NS}}}firstLine', '0')
    ind.set(f'{{{W_NS}}}hanging', '0')
    jc = ET.SubElement(pPr, f'{{{W_NS}}}jc')
    jc.set(f'{{{W_NS}}}val', 'left')
    
    r1 = ET.SubElement(p, f'{{{W_NS}}}r')
    rPr1 = ET.SubElement(r1, f'{{{W_NS}}}rPr')
    ET.SubElement(rPr1, f'{{{W_NS}}}i')
    t1 = ET.SubElement(r1, f'{{{W_NS}}}t')
    t1.text = "Note. "
    
    r2 = ET.SubElement(p, f'{{{W_NS}}}r')
    t2 = ET.SubElement(r2, f'{{{W_NS}}}t')
    t2.text = note_text
    return p

def make_figure_drawing_elem(drawing_elem):
    p = ET.Element(f'{{{W_NS}}}p')
    pPr = ET.SubElement(p, f'{{{W_NS}}}pPr')
    ET.SubElement(pPr, f'{{{W_NS}}}pageBreakBefore')
    ET.SubElement(pPr, f'{{{W_NS}}}suppressAutoHyphens')
    sp = ET.SubElement(pPr, f'{{{W_NS}}}spacing')
    sp.set(f'{{{W_NS}}}before', '240')
    sp.set(f'{{{W_NS}}}after', '120')
    ind = ET.SubElement(pPr, f'{{{W_NS}}}ind')
    ind.set(f'{{{W_NS}}}left', '0')
    ind.set(f'{{{W_NS}}}right', '0')
    ind.set(f'{{{W_NS}}}firstLine', '0')
    ind.set(f'{{{W_NS}}}hanging', '0')
    jc = ET.SubElement(pPr, f'{{{W_NS}}}jc')
    jc.set(f'{{{W_NS}}}val', 'center')
    
    r = ET.SubElement(p, f'{{{W_NS}}}r')
    r.append(drawing_elem)
    return p

def make_figure_caption_elem(fig_num, caption_text):
    p = ET.Element(f'{{{W_NS}}}p')
    pPr = ET.SubElement(p, f'{{{W_NS}}}pPr')
    ET.SubElement(pPr, f'{{{W_NS}}}suppressAutoHyphens')
    sp = ET.SubElement(pPr, f'{{{W_NS}}}spacing')
    sp.set(f'{{{W_NS}}}before', '120')
    sp.set(f'{{{W_NS}}}after', '240')
    ind = ET.SubElement(pPr, f'{{{W_NS}}}ind')
    ind.set(f'{{{W_NS}}}left', '0')
    ind.set(f'{{{W_NS}}}right', '0')
    ind.set(f'{{{W_NS}}}firstLine', '0')
    ind.set(f'{{{W_NS}}}hanging', '0')
    jc = ET.SubElement(pPr, f'{{{W_NS}}}jc')
    jc.set(f'{{{W_NS}}}val', 'left')
    
    r1 = ET.SubElement(p, f'{{{W_NS}}}r')
    rPr1 = ET.SubElement(r1, f'{{{W_NS}}}rPr')
    ET.SubElement(rPr1, f'{{{W_NS}}}i')
    t1 = ET.SubElement(r1, f'{{{W_NS}}}t')
    t1.text = fig_num
    
    r2 = ET.SubElement(p, f'{{{W_NS}}}r')
    t2 = ET.SubElement(r2, f'{{{W_NS}}}t')
    t2.text = caption_text
    return p

def sync_docx(in_docx, out_docx):
    with zipfile.ZipFile(in_docx, "r") as zin:
        xml_content = zin.read("word/document.xml")
        rels_content = zin.read("word/_rels/document.xml.rels").decode("utf-8")
        all_files = {item.filename: zin.read(item.filename) for item in zin.infolist()}
    
    root_rels = ET.fromstring(rels_content)
    rid_to_target = {e.get('Id'): e.get('Target') for e in root_rels if e.get('Id')}
    
    ET.register_namespace('w', W_NS)
    ET.register_namespace('a', A_NS)
    ET.register_namespace('r', R_NS)
    ET.register_namespace('wp', WP_NS)
    
    doc_tree = ET.fromstring(xml_content)
    ns = {'w': W_NS, 'a': A_NS, 'r': R_NS, 'wp': WP_NS}
    body = doc_tree.find('w:body', ns)
    
    # 1. Update and capture Drawing elements
    captured_drawings = {}
    
    for fig_key, fig_cfg in FIGURES_CONFIG.items():
        img_path = fig_cfg["img"]
        if not os.path.exists(img_path):
            continue
            
        pw, ph = get_image_dimensions(img_path)
        cx = 5943600  # 6.5 inches
        cy = int(round(5943600 * (ph / pw)))
        
        # Find drawing element associated with this figure
        for elem in body:
            text = ''.join(elem.itertext()).strip()
            if text.startswith(fig_key) or text.startswith(fig_cfg["num"]):
                idx = list(body).index(elem)
                # Check adjacent elements for drawing (closest first)
                for offset in [0, -1, 1, -2, 2, -3, 3]:
                    chk_idx = idx + offset
                    if 0 <= chk_idx < len(list(body)):
                        candidate = list(body)[chk_idx]
                        blips = candidate.findall('.//a:blip', ns)
                        if blips:
                            for blip in blips:
                                rid = blip.attrib.get(f'{{{R_NS}}}embed')
                                if rid and rid in rid_to_target:
                                    target_media = "word/" + rid_to_target[rid]
                                    with open(img_path, "rb") as f:
                                        all_files[target_media] = f.read()
                                    
                                    # Update extent
                                    drawing_node = candidate.find('.//w:drawing', ns)
                                    if drawing_node is not None:
                                        for wp_ext in drawing_node.findall('.//wp:extent', ns):
                                            wp_ext.set('cx', str(cx))
                                            wp_ext.set('cy', str(cy))
                                        for a_ext in drawing_node.findall('.//a:ext', ns):
                                            a_ext.set('cx', str(cx))
                                            a_ext.set('cy', str(cy))
                                        
                                        captured_drawings[fig_key] = drawing_node
                                        print(f"[✓] Captured and updated {fig_key} -> {target_media}")
                                        break
                            if fig_key in captured_drawings:
                                break
                if fig_key in captured_drawings:
                    break

    # Fallback if any drawing wasn't captured from search
    if len(captured_drawings) < 6:
        all_drawings = body.findall('.//w:drawing', ns)
        fig_keys_order = list(FIGURES_CONFIG.keys())
        for i, d in enumerate(all_drawings):
            if i < len(fig_keys_order):
                k = fig_keys_order[i]
                if k not in captured_drawings:
                    captured_drawings[k] = d

    # 2. Build new body list up to References section
    new_elements = []
    body_list = list(body)
    
    # Identify sectPr (must be preserved at very end)
    sectPr = body.find('w:sectPr', ns)
    
    # Find references heading
    ref_start_idx = None
    for idx, elem in enumerate(body_list):
        text = ''.join(elem.itertext()).strip()
        if text == "References":
            ref_start_idx = idx
            break

    # Process body before references
    limit_idx = ref_start_idx if ref_start_idx is not None else len(body_list)
    i = 0
    while i < limit_idx:
        elem = body_list[i]
        tag = elem.tag.split('}')[-1]
        text = ''.join(elem.itertext()).strip()
        
        if tag == 'sectPr':
            i += 1
            continue
            
        if text in ["Tables", "Figures"]:
            i += 1
            continue
            
        # Check for placeholder already existing
        if re.match(r"^\[(Table|Figure)\s+\d+\s+about here\]$", text, re.IGNORECASE):
            if not (new_elements and ''.join(new_elements[-1].itertext()).strip() == text):
                new_elements.append(elem)
            i += 1
            continue
            
        # Check for Figure caption
        m_fig = re.match(r"^Figure\s+(\d+)[\.:]", text)
        if m_fig:
            fig_num = m_fig.group(1)
            while new_elements and not ''.join(new_elements[-1].itertext()).strip():
                new_elements.pop()
            if new_elements and new_elements[-1].findall('.//w:drawing', ns):
                new_elements.pop()
            new_elements.append(make_placeholder_elem(f"[Figure {fig_num} about here]"))
            i += 1
            while i < limit_idx and not ''.join(body_list[i].itertext()).strip():
                i += 1
            continue
            
        # Check standalone drawing paragraph
        if elem.findall('.//w:drawing', ns):
            # Lookahead: is next non-empty element a Figure caption?
            next_is_fig = False
            for k in range(i+1, min(i+4, limit_idx)):
                next_text = ''.join(body_list[k].itertext()).strip()
                if next_text:
                    if re.match(r"^Figure\s+(\d+)[\.:]", next_text):
                        next_is_fig = True
                    break
            if next_is_fig:
                i += 1
                continue
            if m_fig:
                fig_num = m_fig.group(1)
                new_elements.append(make_placeholder_elem(f"[Figure {fig_num} about here]"))
                i += 1
                continue
                
        # Check for Table title
        m_tbl = re.match(r"^Table\s+(\d+)[\.:]?", text)
        if m_tbl:
            tbl_num = m_tbl.group(1)
            while new_elements and not ''.join(new_elements[-1].itertext()).strip():
                new_elements.pop()
            new_elements.append(make_placeholder_elem(f"[Table {tbl_num} about here]"))
            i += 1
            # Skip until tbl is consumed
            while i < limit_idx:
                curr_elem = body_list[i]
                curr_tag = curr_elem.tag.split('}')[-1]
                curr_text = ''.join(curr_elem.itertext()).strip()
                if curr_tag == 'tbl':
                    i += 1
                    break
                elif re.match(r"^Table\s+(\d+)[\.:]?", curr_text) or re.match(r"^Figure\s+(\d+)[\.:]", curr_text):
                    break
                i += 1
            while i < limit_idx and not ''.join(body_list[i].itertext()).strip():
                i += 1
            continue
            
        if tag == 'tbl':
            i += 1
            continue
            
        new_elements.append(elem)
        i += 1

    # 3. Append References (heading + citations) and stop before old end-matter
    if ref_start_idx is not None:
        while new_elements and not ''.join(new_elements[-1].itertext()).strip():
            new_elements.pop()
        new_elements.append(body_list[ref_start_idx])  # References heading
        
        for k in range(ref_start_idx + 1, len(body_list)):
            elem = body_list[k]
            tag = elem.tag.split('}')[-1]
            text = ''.join(elem.itertext()).strip()
            if tag == 'sectPr':
                break
            if text.startswith("[Table") or text.startswith("[Figure") or text.startswith("Table ") or text.startswith("Figure ") or tag == 'tbl' or "Note." in text:
                break
            if text:
                new_elements.append(elem)

    # Clean up trailing empty paragraphs before end-matter tables/figures
    while new_elements and not ''.join(new_elements[-1].itertext()).strip():
        new_elements.pop()

    # 4. Append all Tables at the end of document (each starting with pageBreakBefore)
    for tbl_k, tbl_cfg in TABLES_CONFIG.items():
        headers, rows = parse_markdown_table(tbl_cfg["file"])
        tbl_xml = create_apa_table_xml(tbl_cfg["headers"], rows, tbl_cfg["widths"])
        tbl_elem = ET.fromstring(tbl_xml)
        
        p_title1, p_title2 = make_table_title_elems(tbl_cfg["num"], tbl_cfg["title"])
        p_note = make_table_note_elem(tbl_cfg["note"])
        
        new_elements.append(p_title1)
        new_elements.append(p_title2)
        new_elements.append(tbl_elem)
        new_elements.append(p_note)
        print(f"[✓] Appended {tbl_k} to end of document")

    # 5. Append all Figures at the end of document (each starting with pageBreakBefore)
    for fig_k, fig_cfg in FIGURES_CONFIG.items():
        if fig_k in captured_drawings:
            p_draw = make_figure_drawing_elem(captured_drawings[fig_k])
            p_cap = make_figure_caption_elem(fig_cfg["num"], fig_cfg["caption"])
            new_elements.append(p_draw)
            new_elements.append(p_cap)
            print(f"[✓] Appended {fig_k} to end of document")

    # 6. Re-attach sectPr
    if sectPr is not None:
        new_elements.append(sectPr)

    # 7. Reconstruct body
    body.clear()
    for el in new_elements:
        body.append(el)

    # 8. Normalize fonts: explicitly set Cardo (document serif font) on any rogue monospace / font overrides (Nova Mono, Arial Unicode MS)
    for parent in doc_tree.iter():
        for child in list(parent):
            if child.tag.endswith('rFonts'):
                for k, v in list(child.attrib.items()):
                    if any(bad in v for bad in ['Nova Mono', 'Arial Unicode MS']):
                        child.set(f'{{{W_NS}}}ascii', 'Cardo')
                        child.set(f'{{{W_NS}}}hAnsi', 'Cardo')
                        child.set(f'{{{W_NS}}}cs', 'Cardo')
                        child.set(f'{{{W_NS}}}eastAsia', 'Cardo')
                        break

    # Serialize back to docx
    updated_xml_bytes = ET.tostring(doc_tree, encoding="utf-8", xml_declaration=True)
    all_files["word/document.xml"] = updated_xml_bytes
    
    with zipfile.ZipFile(out_docx, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for fname, data in all_files.items():
            zout.writestr(fname, data)
            
    print(f"[✓] Successfully generated synchronized document: {out_docx}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 sync_manuscript.py <input_docx> <output_docx>")
        sys.exit(1)
    sync_docx(sys.argv[1], sys.argv[2])
