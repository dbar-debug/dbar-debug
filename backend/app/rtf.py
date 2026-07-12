"""
Мінімальний конвертер RTF → текст/HTML (без зовнішніх залежностей).
Судові рішення ЄДРСР віддаються у .rtf; браузер їх інлайн не показує,
тож перетворюємо на читабельний HTML на бекенді.

Базується на класичному алгоритмі striprtf (обробка \\uN, \\'xx у cp1251,
службових слів і «призначень», які треба ігнорувати).
"""

import html as _html
import re

_DESTINATIONS = frozenset((
    "aftncn", "aftnsep", "aftnsepc", "annotation", "atnauthor", "atndate", "atnicn",
    "atnid", "atnparent", "atnref", "atntime", "atrfend", "atrfstart", "author",
    "background", "bkmkend", "bkmkstart", "blipuid", "buptim", "category", "colorschememapping",
    "colortbl", "comment", "company", "creatim", "datafield", "datastore", "defchp", "defpap",
    "do", "doccomm", "docvar", "dptxbxtext", "ebcend", "ebcstart", "factoidname", "falt",
    "fchars", "ffdeftext", "ffentrymcr", "ffexitmcr", "ffformat", "ffhelptext", "ffl",
    "ffname", "ffstattext", "field", "file", "filetbl", "fldinst", "fldrslt", "fldtype",
    "fname", "fontemb", "fontfile", "fonttbl", "footer", "footerf", "footerl", "footerr",
    "footnote", "formfield", "ftncn", "ftnsep", "ftnsepc", "g", "generator", "gridtbl",
    "header", "headerf", "headerl", "headerr", "hl", "hlfr", "hlinkbase", "hlloc", "hlsrc",
    "hsv", "htmltag", "info", "keycode", "keywords", "latentstyles", "lchars", "levelnumbers",
    "leveltext", "lfolevel", "linkval", "list", "listlevel", "listname", "listoverride",
    "listoverridetable", "listpicture", "liststylename", "listtable", "listtext",
    "lsdlockedexcept", "macc", "maccPr", "mailmerge", "maln", "malnScr", "manager", "margPr",
    "mbar", "mbarPr", "mbaseJc", "mbegChr", "mborderBox", "mborderBoxPr", "mbox", "mboxPr",
    "mchr", "mcount", "mctrlPr", "md", "mdeg", "mdegHide", "mden", "mdiff", "mdPr", "me",
    "mendChr", "meqArr", "meqArrPr", "mf", "mfName", "mfPr", "mfunc", "mfuncPr", "mgroupChr",
    "mgroupChrPr", "mgrow", "mhideBot", "mhideLeft", "mhideRight", "mhideTop", "mhtmltag",
    "mlim", "mlimloc", "mlimlow", "mlimlowPr", "mlimupp", "mlimuppPr", "mm", "mmaddfieldname",
    "mmath", "mmathPict", "mmathPr", "mmaxdist", "mmc", "mmcJc", "mmconnectstr",
    "mmconnectstrdata", "mmcPr", "mmcs", "mmdatasource", "mmheadersource", "mmmailsubject",
    "mmodso", "mmodsofilter", "mmodsofldmpdata", "mmodsomappedname", "mmodsoname",
    "mmodsorecipdata", "mmodsosort", "mmodsosrc", "mmodsotable", "mmodsoudl", "mmodsoudldata",
    "mmodsouniquetag", "mmPr", "mmquery", "mmr", "mnary", "mnaryPr", "mnoBreak", "mnum",
    "mobjDist", "moMath", "moMathPara", "moMathParaPr", "mopEmu", "mphant", "mphantPr", "mplcHide",
    "mpos", "mr", "mrad", "mradPr", "mrPr", "msepChr", "mshow", "mshp", "msPre", "msPrePr",
    "msSub", "msSubPr", "msSubSup", "msSubSupPr", "msSup", "msSupPr", "mstrikeBLTR",
    "mstrikeH", "mstrikeTLBR", "mstrikeV", "msub", "msubHide", "msup", "msupHide", "mtransp",
    "mtype", "mvertJc", "mvfmf", "mvfml", "mvtof", "mvtol", "mzeroAsc", "mzeroDesc", "mzeroWid",
    "nesttableprops", "nextfile", "nonesttables", "objalias", "objclass", "objdata", "object",
    "objname", "objsect", "objtime", "oldcprops", "oldpprops", "oldsprops", "oldtprops",
    "oleclsid", "operator", "panose", "password", "passwordhash", "pgp", "pgptbl", "picprop",
    "pict", "pn", "pnseclvl", "pntext", "pntxta", "pntxtb", "printim", "private", "propname",
    "protend", "protstart", "protusertbl", "pxe", "result", "revtbl", "revtim", "rsidtbl",
    "rxe", "shp", "shpgrp", "shpinst", "shppict", "shprslt", "shptxt", "sn", "sp", "staticval",
    "stylesheet", "subject", "sv", "svb", "tc", "template", "themedata", "title", "txe", "ud",
    "upr", "userprops", "wgrffmtfilter", "windowcaption", "writereservation", "writereservhash",
    "xe", "xform", "xmlattrname", "xmlattrvalue", "xmlclose", "xmlname", "xmlnstbl", "xmlopen",
))

_SPECIAL = {
    "par": "\n", "sect": "\n\n", "page": "\n\n", "line": "\n", "tab": "\t",
    "emdash": "—", "endash": "–", "emspace": " ", "enspace": " ",
    "qmspace": " ", "bullet": "•", "lquote": "‘", "rquote": "’",
    "ldblquote": "“", "rdblquote": "”",
}

_PATTERN = re.compile(
    r"\\([a-z]{1,32})(-?\d{1,10})?[ ]?|\\'([0-9a-f]{2})|\\([^a-z])|([{}])|[\r\n]+|(.)",
    re.IGNORECASE,
)


def rtf_to_text(data: bytes, encoding: str = "cp1251") -> str:
    text = data.decode("latin-1", errors="replace")
    stack = []
    ignorable = False
    ucskip = 1
    curskip = 0
    out = []
    for m in _PATTERN.finditer(text):
        word, arg, hexc, char, brace, tchar = m.groups()
        if brace:
            curskip = 0
            if brace == "{":
                stack.append((ucskip, ignorable))
            elif brace == "}" and stack:
                ucskip, ignorable = stack.pop()
        elif char:
            curskip = 0
            if char == "~":
                out.append(" ")
            elif char in "{}\\":
                out.append(char)
            elif char == "*":
                ignorable = True
        elif word:
            curskip = 0
            if word in _DESTINATIONS:
                ignorable = True
            elif ignorable:
                pass
            elif word in _SPECIAL:
                out.append(_SPECIAL[word])
            elif word == "uc":
                ucskip = int(arg) if arg else 1
            elif word == "u":
                c = int(arg)
                if c < 0:
                    c += 0x10000
                out.append(chr(c))
                curskip = ucskip
        elif hexc:
            if curskip > 0:
                curskip -= 1
            elif not ignorable:
                try:
                    out.append(bytes([int(hexc, 16)]).decode(encoding, "replace"))
                except Exception:
                    pass
        elif tchar:
            if curskip > 0:
                curskip -= 1
            elif not ignorable:
                out.append(tchar)
    return "".join(out)


def rtf_to_html(data: bytes, title: str = "Судове рішення") -> str:
    text = rtf_to_text(data)
    # Абзаци з непорожніх рядків
    paras = [p.strip() for p in text.split("\n")]
    body = "\n".join(
        f"<p>{_html.escape(p)}</p>" if p else "<br>" for p in paras
    )
    return (
        "<!doctype html><html lang=\"uk\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        f"<title>{_html.escape(title)}</title>"
        "<style>body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;"
        "line-height:1.5;max-width:800px;margin:0 auto;padding:16px;color:#111;"
        "background:#fff}p{margin:0 0 8px}@media(prefers-color-scheme:dark)"
        "{body{background:#111;color:#eee}}</style></head><body>"
        f"{body}</body></html>"
    )
