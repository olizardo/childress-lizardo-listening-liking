#!/usr/bin/env python3
"""Strip accidental fallback-font overrides (Cardo, Nova Mono, Arial Unicode MS,
Aptos) from plain prose runs in the live manuscript .docx, restoring the
document's default typography (Alegreya Sans 12pt).

These fonts are NOT legitimate anywhere in this manuscript's body text: Cardo
and Nova Mono crept in from copy-pasting Greek/special characters from a
source with a different default font, and Arial Unicode MS/Aptos are stray
clipboard artifacts. By contrast, Times New Roman (used only inside <m:oMath>
equation runs) and Courier New sz=20 (used only for the inline package names
brms/cmdstanr/CmdStan) ARE legitimate and must be left untouched.

Usage: python3 fix_font_contamination.py <in_docx> <out_docx>
"""
import zipfile
import re
import sys
import xml.etree.ElementTree as ET

BAD_FONTS = ["Cardo", "Nova Mono", "Arial Unicode MS", "Aptos"]


def strip_bad_rfonts(xml_text: str) -> tuple[str, int]:
    total = 0
    for bf in BAD_FONTS:
        pattern = re.compile(r'<w:rFonts[^>]*w:ascii="' + re.escape(bf) + r'"[^>]*/>')
        xml_text, n = pattern.subn("", xml_text)
        total += n
    return xml_text, total


def main():
    in_docx, out_docx = sys.argv[1], sys.argv[2]
    with zipfile.ZipFile(in_docx, "r") as zin, zipfile.ZipFile(
        out_docx, "w", compression=zipfile.ZIP_DEFLATED
    ) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == "word/document.xml":
                text = data.decode("utf-8")
                text, n = strip_bad_rfonts(text)
                print(f"Removed {n} contaminated <w:rFonts/> overrides from {item.filename}")
                # Validate well-formedness before writing back
                ET.fromstring(text.encode("utf-8"))
                data = text.encode("utf-8")
            zout.writestr(item, data)


if __name__ == "__main__":
    main()
