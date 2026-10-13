"""Summarise a tools/Grid.ps1 run across folds and score parameter plateaus.

Usage: python tools/analyze_grid.py <label> [--top N]

For every configuration it reports per-fold PF, the worst fold, and the
share of its one-step neighbours (design plan 13.3) that keep PF >= 1.20
and positive profit on every fold. Picks should come from high plateau
scores, never from the single best pass.
"""
import csv
import os
import sys
from itertools import product

ORDER = ['InpSupertrendMultiplier', 'InpAtrPeriod', 'InpStopBufferAtr',
         'InpRequiredProgressR', 'InpBreakoutLookback', 'InpEntryBufferAtr',
         'InpProgressCheckpointBars', 'InpMaximumHoldingBars']


def load(label):
    base = os.path.join(os.environ['APPDATA'], 'MetaQuotes', 'Terminal', 'Common',
                        'Files', 'KingEA', 'results', label)
    folds = sorted(f[5:-4] for f in os.listdir(base) if f.startswith('grid_') and f.endswith('.csv'))
    data, params = {}, None
    for fold in folds:
        with open(os.path.join(base, f'grid_{fold}.csv'), encoding='utf-8-sig') as handle:
            for row in csv.DictReader(handle):
                if params is None:
                    params = [p for p in ORDER if p in row]
                key = tuple(float(row[p]) for p in params)
                data.setdefault(key, {})[fold] = (float(row['Profit Factor']), int(row['Trades']),
                                                  float(row['Profit']), float(row['Equity DD %']))
    return folds, params, data


def main():
    label = sys.argv[1]
    top = int(sys.argv[sys.argv.index('--top') + 1]) if '--top' in sys.argv else 15
    folds, params, data = load(label)
    values = [sorted({k[i] for k in data}) for i in range(len(params))]

    def good(key):
        cell = data.get(key, {})
        return len(cell) == len(folds) and all(pf >= 1.2 and pnl > 0 for pf, _, pnl, _ in cell.values())

    def neighbours(key):
        for i, v in enumerate(key):
            idx = values[i].index(v)
            for j in (idx - 1, idx + 1):
                if 0 <= j < len(values[i]):
                    yield key[:i] + (values[i][j],) + key[i + 1:]

    rows = []
    for key, cell in data.items():
        if len(cell) != len(folds):
            continue
        pfs = [cell[f][0] for f in folds]
        near = list(neighbours(key))
        plateau = sum(good(n) for n in near) / len(near) if near else 0.0
        rows.append((key, pfs, min(pfs), sum(c[2] for c in cell.values()),
                     sum(c[1] for c in cell.values()), max(c[3] for c in cell.values()), plateau, good(key)))

    print(f'{len(rows)} configurations x {len(folds)} folds ({", ".join(folds)})')
    print(f'all folds PF>=1.2 and profitable: {sum(r[7] for r in rows)}')
    print(f'all folds PF>1.0: {sum(r[2] > 1.0 for r in rows)}')
    short = [p.replace('Inp', '')[:10] for p in params]
    print('\nTop by worst-fold PF:')
    print('  '.join(f'{s:>10}' for s in short) + ' | ' + ' '.join(f'{f:>6}' for f in folds) +
          ' | minPF  net$  trades maxDD% plateau')
    for key, pfs, mn, net, n, dd, plateau, _ in sorted(rows, key=lambda r: -r[2])[:top]:
        print('  '.join(f'{v:>10g}' for v in key) + ' | ' + ' '.join(f'{p:6.2f}' for p in pfs) +
              f' | {mn:5.2f} {net:6.0f} {n:6d} {dd:6.1f} {plateau:6.2f}')


if __name__ == '__main__':
    main()
