r"""Merge grid runs that differ only in a fixed (non-optimized) parameter.

MT5 cannot step through uneven values (e.g. 96, 192, 384), so such a
parameter is run as separate Grid.ps1 labels with it fixed. This writes a
combined results\<out>\grid_<fold>.csv with that parameter added as a column.

Usage: python tools/merge_grids.py <out_label> <param> <label>=<value> [...]
Example:
  python tools/merge_grids.py grid_c2_all InpMaxHoldingBars002 \\
      grid_c2_rsb3_h96=96 grid_c2_rsb3=192 grid_c2_rsb3_h384=384
"""
import csv
import os
import sys

base = os.path.join(os.environ['APPDATA'], 'MetaQuotes', 'Terminal', 'Common', 'Files', 'KingEA', 'results')
out_label, param = sys.argv[1], sys.argv[2]
sources = [arg.split('=', 1) for arg in sys.argv[3:]]
out_dir = os.path.join(base, out_label)
os.makedirs(out_dir, exist_ok=True)
folds = sorted({f for label, _ in sources for f in os.listdir(os.path.join(base, label))
                if f.startswith('grid_') and f.endswith('.csv')})
for name in folds:
    rows, header = [], None
    for label, value in sources:
        path = os.path.join(base, label, name)
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8-sig') as handle:
            for row in csv.DictReader(handle):
                row[param] = value
                rows.append(row)
                header = header or list(row.keys())
    with open(os.path.join(out_dir, name), 'w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)
    print(f'{name}: {len(rows)} rows')
