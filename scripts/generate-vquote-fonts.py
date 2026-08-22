# -*- coding: utf-8 -*-
"""生成竖排直角引号补充字体(claudedocs/font-weight-quotes-plan.md T2)。

web 书级子集字体(public/data/book_fonts/)只含各书出现过的字符,不含
竖排直角引号 ﹁﹂﹃﹄(U+FE41-FE44;竖排管线把 ‘’ 映射为 ﹁﹂,见
src/lib/vertical/tokenStream.ts mapVerticalQuotes)。本脚本从 Flutter 端
同族全量 TTF(flutter-app/assets/fonts/,实测 8 款全部含这 4 个字形)
子集出每族一个微型 woff,由 BookDetailPage 以同名 @font-face +
unicode-range U+FE41-FE44 叠加在书级字体之后兜底。

用法(仓库根目录):python scripts/generate-vquote-fonts.py
依赖:fontTools(pip install fonttools)。产物提交入库,数据变更时无需重跑;
仅当替换 flutter-app/assets/fonts/ 下的字体文件时需要重新生成。
"""
import io
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont

FAMILIES = [
    "aaKaiTi",
    "aaKaiSong",
    "hyFangSong",
    "lxgw",
    "qnBianLi",
    "rzyKaiTi",
    "twZhengKai",
    "wqwMiHei",
]

QUOTE_CODEPOINTS = [0xFE41, 0xFE42, 0xFE43, 0xFE44]  # ﹁﹂﹃﹄

SRC_DIR = os.path.join("flutter-app", "assets", "fonts")
OUT_DIR = os.path.join("public", "data", "quote_fonts")


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    failed = False
    for family in FAMILIES:
        src = os.path.join(SRC_DIR, f"{family}.ttf")
        out = os.path.join(OUT_DIR, f"{family}_vquotes.woff")
        font = TTFont(src, fontNumber=0)
        options = subset.Options()
        options.flavor = "woff"
        options.desubroutinize = True
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=QUOTE_CODEPOINTS)
        subsetter.subset(font)
        # 覆盖校验:4 个码点必须全部保留,缺一即视为字体源不合格。
        cmap = font.getBestCmap()
        missing = [hex(cp) for cp in QUOTE_CODEPOINTS if cp not in cmap]
        if missing:
            print(f"[FAIL] {family}: missing {missing}")
            failed = True
            continue
        buf = io.BytesIO()
        font.save(buf)
        with open(out, "wb") as f:
            f.write(buf.getvalue())
        print(f"[ok] {out} ({len(buf.getvalue())} bytes)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
