"""
Імпортер Єдиного державного реєстру (ЄДР) юросіб та ФОП у локальний
SQLite для пошуку за ПІБ / найменуванням / ЄДРПОУ.

Особливість набору: архіви стиснуті Deflate64 (метод 9), який стандартний
Python (zlib/zipfile) НЕ вміє розпакувати. Тому розпаковуємо потоково
через зовнішній 7z (`7z e -so`) і парсимо XML на льоту
(ElementTree.iterparse з очищенням елементів) — памʼять обмежена навіть
для UO.xml (~3 ГБ) чи FOP.xml (~5 ГБ).

Потрібен p7zip:  sudo apt install -y p7zip-full

Запуск (backend/):
    python3 import_edr.py                    # лише ФОП (типово)
    python3 import_edr.py --parts fop,uo     # ФОП + юрособи
    python3 import_edr.py --fop-url <url>     # явне посилання (обхід package_show)
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

from app import edr_db

# Держ-XML часто містить символи/посилання, недійсні в XML 1.0 (керуючі
# коди на кшталт &#4; або сирий байт 0x0B). ElementTree на них падає, тож
# чистимо потік на льоту. Числові посилання — ASCII, а cp1251 однобайтне,
# тож безпечно фільтрувати на рівні байтів.
_BAD_REF = re.compile(rb"&#(x[0-9a-fA-F]+|[0-9]+);")
# Недійсні керуючі байти (усе 0x00–0x1F, окрім TAB/LF/CR):
_DROP_BYTES = bytes(b for b in range(0x20) if b not in (0x09, 0x0A, 0x0D))


def _valid_cp(cp: int) -> bool:
    return (cp in (0x9, 0xA, 0xD) or 0x20 <= cp <= 0xD7FF
            or 0xE000 <= cp <= 0xFFFD or 0x10000 <= cp <= 0x10FFFF)


def _fix_ref(m: "re.Match") -> bytes:
    body = m.group(1)
    cp = int(body[1:], 16) if body[:1] in (b"x", b"X") else int(body)
    return m.group(0) if _valid_cp(cp) else b""


class _XmlSanitizer:
    """Файл-обгортка: видаляє недійсні керуючі байти й числові посилання,
    зберігаючи «хвіст» на межі чанків, щоб не розрізати &#...; навпіл."""

    def __init__(self, raw):
        self.raw = raw
        self.tail = b""

    def _clean(self, data: bytes) -> bytes:
        if not data:
            return data
        data = data.translate(None, _DROP_BYTES)
        return _BAD_REF.sub(_fix_ref, data)

    def read(self, size=65536) -> bytes:
        while True:
            chunk = self.raw.read(size)
            if not chunk:
                data, self.tail = self.tail, b""
                return self._clean(data)  # порожньо → справжній кінець
            data = self.tail + chunk
            amp = data.rfind(b"&")
            # притримуємо незавершене &#... (без ;) до наступного читання
            if amp != -1 and b";" not in data[amp:] and len(data) - amp < 16:
                self.tail, data = data[amp:], data[:amp]
            else:
                self.tail = b""
            cleaned = self._clean(data)
            if cleaned:
                return cleaned
            # інакше читаємо далі, щоб не віддати передчасний EOF

DATASET_ID = os.getenv("EDR_DATASET_ID", "a1799820-195b-4982-8141-6e84f58103e7")
UA = "Mozilla/5.0 (court-app; +personal use)"


def _sevenzip() -> str:
    exe = next((e for e in ("7z", "7za", "7zr") if shutil.which(e)), None)
    if not exe:
        sys.exit("Потрібен 7z для Deflate64. Встанови: sudo apt install -y p7zip-full")
    return exe


def _resolve_url(resource_name: str) -> str:
    """URL ресурсу набору за назвою файлу (напр. 'FOP.zip'), через package_show."""
    api = f"https://data.gov.ua/api/3/action/package_show?id={DATASET_ID}"
    req = urllib.request.Request(api, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        pkg = json.loads(r.read().decode("utf-8"))["result"]
    want = resource_name.lower()
    for res in pkg.get("resources", []):
        if (res.get("name") or "").lower() == want:
            return res["path"] if res.get("path") else res["url"]
    raise RuntimeError(f"Ресурс {resource_name} не знайдено в наборі {DATASET_ID}")


def _download(url: str, data_dir: str) -> str:
    print(f"[edr] Завантажую zip: {url}")
    fd, tmp = tempfile.mkstemp(suffix=".zip", dir=data_dir)
    os.close(fd)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=3600) as resp, open(tmp, "wb") as f:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    print(f"[edr] Завантажено {os.path.getsize(tmp)/1024/1024:.0f} МБ")
    return tmp


def _biggest_xml(zip_path: str) -> str:
    """Назва найбільшого .xml усередині архіву (не розпаковуючи)."""
    with zipfile.ZipFile(zip_path) as zf:
        xmls = [zi for zi in zf.infolist() if zi.filename.lower().endswith(".xml")]
        if not xmls:
            raise RuntimeError(f"У {zip_path} немає XML")
        return max(xmls, key=lambda zi: zi.file_size).filename


def _xml_stream(zip_path: str, member: str):
    """Потік розпакованого XML через 7z (Deflate64). Повертає (proc, stdout)."""
    exe = _sevenzip()
    print(f"[edr] Розпаковую {member} через {exe} (Deflate64)...")
    proc = subprocess.Popen(
        [exe, "e", "-so", zip_path, member],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    )
    return proc


def _iter_subjects(proc):
    """Потоковий парсинг <SUBJECT>…</SUBJECT> з очищенням памʼяті."""
    context = ET.iterparse(_XmlSanitizer(proc.stdout), events=("start", "end"))
    _, root = next(context)  # кореневий <DATA>
    for event, elem in context:
        if event == "end" and elem.tag == "SUBJECT":
            yield elem
            elem.clear()
            root.clear()  # прибираємо оброблені записи з кореня — памʼять стабільна


def _termination(elem) -> str:
    """Дата й причина припинення. Спершу TERMINATED_INFO
    («дата; номер; причина»), інакше структуроване «в стані припинення»
    (TERMINATION_STARTED_INFO → OP_DATE/REASON)."""
    ti = next((t.text.strip() for t in elem.findall("TERMINATED_INFO")
               if (t.text or "").strip()), "")
    if ti:
        parts = [p.strip() for p in ti.split(";")]
        date = parts[0] if parts else ""
        reason = parts[-1] if len(parts) >= 3 else ""
        return f"{date} — {reason}" if reason else date
    st = elem.find("TERMINATION_STARTED_INFO")
    if st is not None and len(st):
        date = (st.findtext("OP_DATE") or "").strip()
        reason = (st.findtext("REASON") or "").strip()
        res = f"{date} — {reason}".strip(" —")
        return res
    return ""


def _fop_rows(zip_path: str):
    """ФОП: <SUBJECT><NAME/><STAN/><REGISTRATION/><ESTATE_MANAGER/><FARMER/>…"""
    member = _biggest_xml(zip_path)
    proc = _xml_stream(zip_path, member)
    try:
        n = 0
        for elem in _iter_subjects(proc):
            name = (elem.findtext("NAME") or "").strip()
            if not name:
                continue
            stan = (elem.findtext("STAN") or "").strip()
            reg = (elem.findtext("REGISTRATION") or "").strip()
            reg_date = reg.split(";")[0].strip() if reg else ""
            manager = (elem.findtext("ESTATE_MANAGER") or "").strip()
            farmer = (elem.findtext("FARMER") or "").strip()
            extra = []
            if manager:
                extra.append(f"Управитель майна: {manager}")
            if farmer:
                extra.append("Сімейне фермерське господарство")
            yield ("ФОП", name, "", stan, reg_date, "", "",
                   "; ".join(extra), _termination(elem))
            n += 1
            if n % 500000 == 0:
                print(f"[edr] ФОП прочитано: {n:,}")
    finally:
        proc.stdout.close()
        proc.wait()


def _founder_person(text: str) -> str:
    """«НУР АХМАД; розмір частки - 1000,00 грн.» → «НУР АХМАД» (або назва орг.)."""
    return (text or "").split(";")[0].strip()


def _signer_person_role(text: str):
    """«БОРОДАЙ ЮРІЙ - керівник» → ('БОРОДАЙ ЮРІЙ', 'керівник');
    «ЯКОВЕЦЬ ГАЛИНА; - представник» → ('ЯКОВЕЦЬ ГАЛИНА', 'представник')."""
    t = (text or "").strip()
    role = ""
    if " - " in t:
        left, role = t.rsplit(" - ", 1)
    else:
        left = t
    return left.split(";")[0].strip(), role.strip()


def _uo_rows(zip_path: str):
    """Юрособи: сама компанія (NAME/EDRPOU) + засновники/підписанти за ПІБ.
    <SUBJECT><NAME/><SHORT_NAME/><OPF/><EDRPOU/><STAN/>
             <FOUNDERS><FOUNDER/></FOUNDERS><SIGNERS><SIGNER/></SIGNERS>
             <REGISTRATION/>…"""
    member = _biggest_xml(zip_path)
    proc = _xml_stream(zip_path, member)
    try:
        n = 0
        for elem in _iter_subjects(proc):
            name = (elem.findtext("NAME") or "").strip()
            if not name:
                continue
            edrpou = (elem.findtext("EDRPOU") or "").strip()
            stan = (elem.findtext("STAN") or "").strip()
            opf = (elem.findtext("OPF") or "").strip()
            reg = (elem.findtext("REGISTRATION") or "").strip()
            reg_date = reg.split(";")[0].strip() if reg else ""
            term = _termination(elem)

            # 1) сама юрособа
            yield ("ЮО", name, edrpou, stan, reg_date, "", "", opf, term)

            # 2) повʼязані особи — дедуплікуємо ролі в межах одного запису
            #    (та сама людина часто і засновник, і керівник/представник)
            roles: dict = {}
            for f in elem.findall("FOUNDERS/FOUNDER"):
                p = _founder_person(f.text or "")
                if p:
                    roles.setdefault(p, set()).add("засновник")
            for s in elem.findall("SIGNERS/SIGNER"):
                p, r = _signer_person_role(s.text or "")
                if p:
                    roles.setdefault(p, set()).add(r or "підписант")
            for person, rset in roles.items():
                role = ", ".join(sorted(rset))
                yield ("ЮО", person, edrpou, stan, reg_date, role, name, "", term)
            n += 1
            if n % 500000 == 0:
                print(f"[edr] ЮО прочитано: {n:,}")
    finally:
        proc.stdout.close()
        proc.wait()


# Реєстр частин набору: назва → (ресурс у наборі, генератор рядків)
_PARTS = {
    "fop": ("FOP.zip", _fop_rows),
    "uo": ("UO.zip", _uo_rows),
}


def _all_rows(parts, urls, data_dir):
    for part in parts:
        resource, reader = _PARTS[part]
        url = urls.get(part) or _resolve_url(resource)
        print(f"\n=== {part.upper()} ({resource}) ===")
        tmp = _download(url, data_dir)
        try:
            yield from reader(tmp)
        finally:
            os.remove(tmp)


def _arg(flag: str):
    if flag in sys.argv:
        i = sys.argv.index(flag)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


def main():
    t0 = time.time()
    parts_arg = _arg("--parts") or "fop"
    parts = [p.strip() for p in parts_arg.split(",") if p.strip() in _PARTS]
    if not parts:
        sys.exit(f"Немає відомих частин у '{parts_arg}'. Доступні: {', '.join(_PARTS)}")

    urls = {}
    for p in _PARTS:
        u = _arg(f"--{p}-url")
        if u:
            urls[p] = u

    data_dir = os.path.dirname(edr_db.DB_PATH) or "."
    os.makedirs(data_dir, exist_ok=True)

    count = edr_db.build(_all_rows(parts, urls, data_dir))
    print(f"\n[edr] Готово: {count:,} записів ({', '.join(parts)}) за {time.time()-t0:.0f}с")
    print(f"[edr] База: {edr_db.DB_PATH}")


if __name__ == "__main__":
    main()
