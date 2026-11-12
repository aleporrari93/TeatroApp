"""Libreria: catalogo, corpi con trucco, capi, capelli, elementi scenici. Costruisce i modelli 3D pronti da disegnare.
Ogni parte e' un dizionario: V (N x 3, metri, Z in alto, fronte verso -Y), F (M x 3, indici da 0), C (N x 3, 0..1), alpha, name."""
import csv
import os

import numpy as np

from . import model as M
from .paths import lib_dir

_cache_body = {}
_cache_parts = {}


def read_catalog():
    out = []
    with open(os.path.join(lib_dir(), 'catalogo.csv'), encoding='utf-8') as f:
        r = csv.reader(f, delimiter=';')
        next(r, None)
        for c in r:
            if not c or not c[0].strip():
                continue
            c = (c + [''] * 8)[:8]
            hx = c[4].strip()
            rgb = [int(hx[i:i + 2], 16) / 255 for i in (0, 2, 4)] if len(hx) == 6 else [0.6, 0.6, 0.6]
            size = []
            for v in c[5:8]:
                try:
                    size.append(float(v))
                except ValueError:
                    size.append(1.0)
            out.append(dict(cat=c[0].strip(), id=c[1].strip(), name=c[2].strip(), hex=hx, rgb=rgb, size=size))
    return out


def load_npz_parts(path):
    """parti grezze di un file della libreria o di un modello importato"""
    if path in _cache_parts:
        return _cache_parts[path]
    if not os.path.exists(path):
        return []
    z = np.load(path, allow_pickle=False)
    P = []
    for i in range(int(z['n'])):
        P.append(dict(V=z['V%d' % i].astype(float), F=z['F%d' % i].astype(np.int64), C=z['C%d' % i].astype(float),
                      alpha=float(z['a%d' % i]), tint=float(z['t%d' % i]), mix=z['m%d' % i].astype(float), name=str(z['n%d' % i])))
    _cache_parts[path] = P
    return P


def save_npz_parts(path, P):
    out = {'n': np.array(len(P))}
    for i, p in enumerate(P):
        out['V%d' % i] = np.asarray(p['V'], np.float32); out['F%d' % i] = np.asarray(p['F'], np.int32)
        C = np.asarray(p['C'], float)
        if C.max() <= 1.0:
            C = C * 255
        out['C%d' % i] = np.clip(C, 0, 255).astype(np.uint8)
        out['a%d' % i] = np.array(float(p.get('alpha', 1.0))); out['t%d' % i] = np.array(float(p.get('tint', 0.0)))
        out['m%d' % i] = np.asarray(p.get('mix', np.zeros(0)), np.float32).ravel(); out['n%d' % i] = np.array(str(p.get('name', '')))
    np.savez_compressed(path, **out)
    _cache_parts.pop(path, None)


def clear_cache():
    _cache_parts.clear()


def load_body(sex):
    if sex in _cache_body:
        return _cache_body[sex]
    z = np.load(os.path.join(lib_dir(), 'corpi', 'corpo_%s.npz' % sex), allow_pickle=False)
    B = dict(V=z['V'].astype(float), F=z['F'].astype(np.int64), masks=z['masks'].astype(float), names=[str(x) for x in z['maskNames']],
             eyesV=z['eyesV'].astype(float), eyesF=z['eyesF'].astype(np.int64), iris=z['iris'].astype(float),
             pupil=z['pupil'].astype(float), H0=float(z['H0']))
    _cache_body[sex] = B
    return B


def _blend(C, w, rgb):
    w = np.asarray(w, float)[:, None]
    return C * (1 - w) + np.asarray(rgb, float)[None, :] * w


def _coloured(raw, rgb, skin=None):
    out = []
    for p in raw:
        V = p['V']; C = p['C']
        if len(p['mix']) == len(V) and skin is not None:
            w = p['mix'][:, None]; C = np.asarray(skin)[None, :] * (1 - w) + np.asarray(rgb)[None, :] * w
        elif p['tint'] > 0 and rgb is not None:
            C = np.minimum(1.15, C / p['tint']) * np.asarray(rgb)[None, :]
        else:
            C = C / 255.0
        out.append(dict(V=V.copy(), F=p['F'], C=np.clip(C, 0, 1), alpha=p['alpha'], name=p['name']))
    return out


def char_parts(sh, folder, ch, code):
    """personaggio completo: corpo, trucco, capi, capelli (gia' scalato all'altezza)"""
    co = next((c for c in ch['costumes'] if c['code'] == code), ch['costumes'][0])
    if co['mode'] == 'import':
        raw = load_npz_parts(os.path.join(folder, 'modelli', co['file']))
        P = _coloured(raw, None)
        if not P:
            return []
        zmax = max(p['V'][:, 2].max() for p in P)
        for p in P:
            p['V'] *= ch['height'] / max(zmax, 1e-6)
        return P
    B = load_body(ch['sex'])
    sk = np.asarray(ch['skin'], float)
    mk = lambda nm: B['masks'][:, B['names'].index(nm)]
    C = np.tile(sk, (len(B['V']), 1))
    m = co['mk']
    C = _blend(C, mk('labbra') * 0.55, sk * [0.86, 0.6, 0.58])
    C = _blend(C, mk('fard') * 0.12, [0.82, 0.43, 0.39])
    if m['blush']:
        C = _blend(C, mk('fard') * 0.35, m['blushRGB'])
    if m['shadow']:
        C = _blend(C, mk('ombretto') * 0.7, m['shadowRGB'])
    if m['lashes']:
        C = _blend(C, mk('rimmel') * 0.95, m['lashesRGB'])
    if m['lips']:
        C = _blend(C, mk('labbra') * 0.9, m['lipsRGB'])
    C = _blend(C, mk('sopr_' + m['brows']) * 0.9, m['browsRGB'])
    P = [dict(V=B['V'].copy(), F=B['F'], C=np.clip(C, 0, 1), alpha=1.0, name='Corpo')]
    Ce = np.tile([0.87, 0.84, 0.8], (len(B['eyesV']), 1))
    Ce = _blend(Ce, B['iris'], ch['eyes']); Ce = _blend(Ce, B['pupil'], [0.07, 0.055, 0.05])
    P.append(dict(V=B['eyesV'].copy(), F=B['eyesF'], C=Ce, alpha=1.0, name='Occhi'))
    base = lib_dir(); s = ch['sex']
    for q, iid in enumerate(co['items']):
        if not iid:
            continue
        sub = 'cappelli' if M.SLOTS[q] == 'Cappello' else 'capi'
        P += _coloured(load_npz_parts(os.path.join(base, sub, '%s_%s.npz' % (s, iid))), co['irgb'][q])
    if co['hair']:
        P += _coloured(load_npz_parts(os.path.join(base, 'capelli', '%s_%s.npz' % (s, co['hair']))), co['hairRGB'])
    if co['facial']:
        P += _coloured(load_npz_parts(os.path.join(base, 'barba', '%s_%s.npz' % (s, co['facial']))), co['facialRGB'], skin=sk)
    k = ch['height'] / B['H0']
    for p in P:
        p['V'] = p['V'] * k
    return P


def element_parts(folder, e):
    """elemento scenico centrato in pianta, appoggiato a terra, nelle misure scelte"""
    if e['src'] == 'lib':
        path = os.path.join(lib_dir(), 'scenografia', e['file'] + '.npz')
    else:
        path = os.path.join(folder, 'modelli', e['file'])
    raw = load_npz_parts(path)
    P = _coloured(raw, e['rgb'] if e['tint'] else None)
    if not P:
        return []
    V = np.vstack([p['V'] for p in P]); mn = V.min(0); mx = V.max(0); sz = np.maximum(mx - mn, 1e-3)
    k = np.asarray(e['size'], float) / sz; c = np.array([(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]])
    for p in P:
        p['V'] = (p['V'] - c) * k
    return P


def backdrop_parts(folder, T):
    raw = load_npz_parts(os.path.join(folder, 'modelli', T['backModel']))
    P = _coloured(raw, None)
    if not P:
        return []
    V = np.vstack([p['V'] for p in P]); mn = V.min(0); mx = V.max(0)
    k = (T['W'] + 2 * T['wing']) / max(mx[0] - mn[0], 1e-3)
    for p in P:
        v = p['V'].copy()
        v[:, 0] = (v[:, 0] - (mn[0] + mx[0]) / 2) * k; v[:, 1] = (v[:, 1] - mx[1]) * k + T['D']; v[:, 2] = (v[:, 2] - mn[2]) * k
        p['V'] = v
    return P


def parts_top(P):
    return max((p['V'][:, 2].max() for p in P if len(p['V'])), default=1.8)
