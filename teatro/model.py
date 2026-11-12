"""Dati dello spettacolo (dizionari salvati in JSON) e funzioni di calcolo che non dipendono dalla grafica."""
import copy
import json
import math
import os
import re
from datetime import datetime

import numpy as np

SLOTS = ['Sopra', 'Gilet', 'Giacca', 'Mantello', 'Sotto', 'Abito', 'Scarpe', 'Cappello', 'Accessorio', 'Accessorio']
SLOTLBL = ['Maglia / camicia', 'Gilet', 'Giacca', 'Mantello', 'Pantaloni / gonna', 'Abito intero', 'Scarpe', 'Cappello',
           'Accessorio 1', 'Accessorio 2']
NSLOT = len(SLOTS)
ZONES = ['Tutto il palco', 'Avanti', 'Centro', 'Fondo', 'Sinistra', 'Destra', 'Fondale (ciclorama)', 'Puntiforme (centro)',
         'Segue un personaggio']
FOLLOW = 'Segue un personaggio'
BACKS = ['Nero', 'Ciclorama bianco', 'Grigio', 'Immagine (foto o disegno)', 'Modello 3D']
COLN = ['Bianco', 'Bianco caldo', 'Ambra', 'Rosso', 'Rosa', 'Viola', 'Blu', 'Azzurro', 'Verde', 'Personalizzato']
COLV = [[1, 1, 0.95], [1, 0.86, 0.62], [1, 0.68, 0.25], [1, 0.15, 0.12], [1, 0.45, 0.7], [0.62, 0.3, 1], [0.25, 0.4, 1],
        [0.45, 0.75, 1], [0.3, 0.9, 0.4], [1, 1, 1]]
SKINS = [('Molto chiara', [0.96, 0.84, 0.74]), ('Chiara', [0.93, 0.76, 0.62]), ('Media', [0.82, 0.62, 0.46]),
         ('Olivastra', [0.74, 0.55, 0.38]), ('Scura', [0.55, 0.37, 0.25]), ('Molto scura', [0.36, 0.24, 0.17])]
EYES = [('Castani', [0.29, 0.2, 0.14]), ('Nocciola', [0.45, 0.32, 0.18]), ('Verdi', [0.24, 0.42, 0.23]),
        ('Azzurri', [0.29, 0.48, 0.66]), ('Grigi', [0.45, 0.48, 0.5]), ('Neri', [0.1, 0.08, 0.07])]
BROWS = ['sottili', 'normali', 'folte']
MAKEUP = [('lips', 'Rossetto'), ('lashes', 'Rimmel / eyeliner'), ('shadow', 'Ombretto'), ('blush', 'Fard')]
PAWN_PAL = [[0.85, 0.15, 0.15], [0.2, 0.45, 0.9], [0.2, 0.7, 0.3], [0.95, 0.8, 0.2], [0.55, 0.35, 0.18], [0.6, 0.3, 0.8],
            [0.1, 0.1, 0.1], [0.95, 0.5, 0.15], [0.62, 0.62, 0.65], [0.1, 0.65, 0.7]]

LIGHT_LIBRARY = [
    ('Piazzato PC', 'luce generale morbida', 'Tutto il palco', 'Bianco caldo', 6),
    ('Fresnel', 'luce generale, bordi morbidi', 'Avanti', 'Bianco caldo', 4),
    ('PAR LED RGB', 'colore a scelta', 'Tutto il palco', 'Blu', 8),
    ('Controluce', 'da dietro, stacca le figure', 'Fondo', 'Azzurro', 4),
    ('Testa mobile wash', 'luce colorata su una zona', 'Centro', 'Viola', 2),
    ('Sagomatore', 'luce precisa su un punto', 'Puntiforme (centro)', 'Bianco', 2),
    ('Gobo', 'disegni proiettati a terra', 'Centro', 'Verde', 2),
    ('Seguipersona (occhio di bue)', 'segue un personaggio', FOLLOW, 'Bianco', 1),
    ('Testa mobile spot', 'segue un personaggio', FOLLOW, 'Bianco', 2),
    ('Strip LED ciclorama', 'colora il fondale', 'Fondale (ciclorama)', 'Blu', 4),
    ('Ribalta', 'dal basso, sul proscenio', 'Avanti', 'Ambra', 4),
    ('Luce da sinistra', 'taglio laterale', 'Sinistra', 'Bianco', 2),
    ('Luce da destra', 'taglio laterale', 'Destra', 'Bianco', 2),
    ('Strobo', 'lampi', 'Tutto il palco', 'Bianco', 1),
]


def colour_of(name):
    return list(COLV[COLN.index(name)]) if name in COLN else [1, 1, 1]


def now():
    return datetime.now().strftime('%Y-%m-%d %H:%M')


# ---------------------------------------------------------------- costruttori
def new_light(name, typ, qty, cname, rgb, zone):
    return dict(name=name, type=typ, qty=qty, cname=cname, rgb=list(rgb), zone=zone)


def new_element(name, src, file, size, rgb, tint):
    return dict(name=name, src=src, file=file, size=[float(x) for x in size], rgb=list(rgb), tint=bool(tint), fixed=False,
                x=0.0, y=0.0, rot=0.0, occ='', how='')


def set_item(items, slot, iid):
    items[SLOTS.index(slot)] = iid
    return items


def new_costume(code, sex):
    mk = dict(lips=0, lipsRGB=[0.7, 0.15, 0.2], lashes=0, lashesRGB=[0.06, 0.05, 0.05], shadow=0, shadowRGB=[0.45, 0.35, 0.55],
              blush=0, blushRGB=[0.85, 0.45, 0.45], brows='normali', browsRGB=[0.2, 0.13, 0.08])
    co = dict(code=code, desc='costume ' + code, mode='lib', file='', items=[''] * NSLOT, irgb=[[0.5, 0.5, 0.5] for _ in range(NSLOT)],
              hair='corti', hairRGB=[0.23, 0.14, 0.09], facial='', facialRGB=[0.2, 0.13, 0.08], mk=mk)
    set_item(co['items'], 'Sopra', 'tshirt'); co['irgb'][0] = [0.95, 0.95, 0.95]
    set_item(co['items'], 'Sotto', 'jeans'); co['irgb'][4] = [0.23, 0.36, 0.55]
    set_item(co['items'], 'Scarpe', 'scarpe'); co['irgb'][6] = [0.16, 0.11, 0.07]
    if sex == 'F':
        co['hair'] = 'lisci'; co['hairRGB'] = [0.35, 0.2, 0.1]; mk['brows'] = 'sottili'
    return co


def new_char(name, sex, idx):
    return dict(name=name, pawn=list(PAWN_PAL[(idx - 1) % len(PAWN_PAL)]), sex=sex, height=1.66 if sex == 'F' else 1.78,
                skin=[0.93, 0.76, 0.62], eyes=[0.29, 0.2, 0.14], costumes=[new_costume('A', sex)], rev=1)


def new_obj(oid, kind, ref, label, x, y, rgb, zone='', w=0.0, d=0.0, rot=0.0, start=False):
    return dict(id=int(oid), kind=kind, ref=ref, label=label, x=float(x), y=float(y), rgb=[float(c) for c in rgb], zone=zone,
                w=float(w), d=float(d), rot=float(rot), start=bool(start))


def new_scene(uid, act, num, title, start=''):
    return dict(uid=int(uid), act=int(act), num=int(num), title=title or 'Scena %d' % num, start=start, cast=[], objects=[],
                steps=[], cues=[], ens=[])


def mk_eff(cls, spid, pts, dur, delay):
    return dict(cls=cls, spid=int(spid), pts=[[float(a), float(b)] for a, b in (pts if pts is not None else [])],
                dur=float(dur), delay=float(delay))


def fix_theater(T):
    T['W'] = max(2.0, float(T['W'])); T['Dtot'] = float(T['Dtot']); T['P'] = max(0.0, min(float(T['P']), T['Dtot'] - 2))
    T['Dtot'] = max(T['Dtot'], T['P'] + 2); T['D'] = T['Dtot'] - T['P']; T['nq'] = max(0, int(round(float(T['nq']))))
    T['H'] = max(2.0, float(T['H'])); T['wing'] = quinte_width(T) + 0.6
    return T


def default_show(title):
    t = now()
    sh = dict(title=title, created=t, modified=t, nextId=0,
              theater=fix_theater(dict(W=10.0, Dtot=9.2, D=8.0, H=7.0, nq=3, wing=2.0, P=1.2, back='Nero', backImg='', backModel='')),
              lights=[new_light('Piazzato caldo', 'Piazzato PC', 6, 'Bianco caldo', colour_of('Bianco caldo'), 'Tutto il palco'),
                      new_light('Controluce blu', 'Controluce', 4, 'Blu', colour_of('Blu'), 'Fondo'),
                      new_light('Ciclorama', 'Strip LED ciclorama', 4, 'Azzurro', colour_of('Azzurro'), 'Fondale (ciclorama)'),
                      new_light('Occhio di bue', 'Seguipersona (occhio di bue)', 1, 'Bianco', colour_of('Bianco'), FOLLOW)],
              elements=[], chars=[], scenes=[])
    return sh


def norm_show(sh):
    d = default_show(sh.get('title', 'Spettacolo'))
    for k, v in d.items():
        sh.setdefault(k, v)
    T = sh['theater']
    if 'Dtot' not in T and 'D' in T:
        T['Dtot'] = T['D'] + T.get('P', 1.2)
    for k, v in d['theater'].items():
        T.setdefault(k, v)
    fix_theater(T)
    mx = sh.get('nextId', 0)
    for sc in sh['scenes']:
        for k, v in new_scene(0, 1, 1, '').items():
            sc.setdefault(k, copy.deepcopy(v))
        n = len(sc['steps'])
        sc['cues'] = (sc['cues'] + [''] * n)[:n]; sc['ens'] = (sc['ens'] + [''] * n)[:n]
        mx = max([mx, sc['uid']] + [o['id'] for o in sc['objects']])
    sh['nextId'] = mx
    for e in sh['elements']:
        for k, v in new_element('', 'lib', '', [1, 1, 1], [1, 1, 1], False).items():
            e.setdefault(k, v)
    for c in sh['chars']:
        c.setdefault('rev', 1)
        for co in c['costumes']:
            base = new_costume(co.get('code', 'A'), c.get('sex', 'M'))
            for k, v in base.items():
                co.setdefault(k, v)
            for k, v in base['mk'].items():
                co['mk'].setdefault(k, v)
    return sh


def new_uid(sh):
    sh['nextId'] += 1
    return sh['nextId']


def save_show(sh, folder):
    sh['modified'] = now()
    tmp = os.path.join(folder, 'spettacolo.json.tmp')
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(sh, f, ensure_ascii=False, indent=1)
    os.replace(tmp, os.path.join(folder, 'spettacolo.json'))


def load_show(folder):
    with open(os.path.join(folder, 'spettacolo.json'), encoding='utf-8') as f:
        return norm_show(json.load(f))


def make_show_folder(base, title):
    name = safe_name(title) or 'Spettacolo'
    f = name; n = 2
    while os.path.exists(os.path.join(base, f)):
        f = '%s (%d)' % (name, n); n += 1
    d = os.path.join(base, f)
    for sub in ('', 'audio', 'modelli', 'cue', 'fondale'):
        os.makedirs(os.path.join(d, sub), exist_ok=True)
    return d


# ---------------------------------------------------------------- scene e passi
def cast_code(sh, sc, name):
    for c in sc['cast']:
        if c['name'] == name:
            return c['code']
    ch = find_char(sh, name)
    return ch['costumes'][0]['code'] if ch and ch['costumes'] else 'A'


def set_cast(sc, name, code):
    for c in sc['cast']:
        if c['name'] == name:
            c['code'] = code; return
    sc['cast'].append(dict(name=name, code=code))


def find_char(sh, name):
    for c in sh['chars']:
        if c['name'] == name:
            return c
    return None


def find_element(sh, name):
    for e in sh['elements']:
        if e['name'] == name:
            return e
    return None


def prune_objs(sc):
    used = {e['spid'] for st in sc['steps'] for e in st}
    sc['objects'] = [o for o in sc['objects'] if o['start'] or o['id'] in used]
    return sc


def state_at(sc, m):
    """[dx, dy, visibile] di ogni oggetto dopo i primi m passi"""
    objs = sc['objects']
    st = np.zeros((len(objs), 3))
    idx = {o['id']: i for i, o in enumerate(objs)}
    for i, o in enumerate(objs):
        st[i, 2] = 1.0 if o['start'] else 0.0
    for k in range(min(m, len(sc['steps']))):
        for e in sc['steps'][k]:
            i = idx.get(e['spid'])
            if i is None:
                continue
            if e['cls'] == 'path' and e['pts']:
                st[i, :2] = e['pts'][-1]
            elif e['cls'] == 'entr':
                st[i, 2] = 1
            elif e['cls'] == 'exit':
                st[i, 2] = 0
    return st


def first_appearance(sc):
    stv = state_at(sc, 0)
    for m in range(1, len(sc['steps']) + 1):
        sm = state_at(sc, m)
        for i in range(len(stv)):
            if stv[i, 2] < 0.5 and sm[i, 2] > 0.5:
                stv[i] = sm[i]
    return stv


def simplify_path(p):
    p = [list(map(float, q)) for q in p]
    if len(p) <= 2:
        return p
    q = [p[0]]
    for a in p[1:-1]:
        if math.dist(a, q[-1]) >= 0.12:
            q.append(a)
    q.append(p[-1])
    if len(q) > 40:
        q = [q[int(round(i))] for i in np.linspace(0, len(q) - 1, 40)]
    return q


def path_point(P, u):
    P = np.asarray(P, float)
    if len(P) == 1:
        return P[0]
    seg = np.sqrt((np.diff(P, axis=0) ** 2).sum(1)); L = np.concatenate([[0], np.cumsum(seg)])
    if L[-1] == 0:
        return P[-1]
    t = u * L[-1]; k = min(int(np.searchsorted(L, t, side='right')) - 1, len(P) - 2); k = max(k, 0)
    f = (t - L[k]) / max(seg[k], 1e-12)
    return P[k] + f * (P[k + 1] - P[k])


def cue_text(sc, k):
    """k parte da 0"""
    if k < len(sc['cues']) and sc['cues'][k]:
        return sc['cues'][k]
    return 'passo %d' % (k + 1)


def parse_time(s):
    if isinstance(s, (int, float)):
        return float(s)
    s = str(s).strip().replace(',', '.')
    if not s:
        return float('nan')
    try:
        p = s.split(':')
        return float(p[0]) if len(p) == 1 else float(p[-2]) * 60 + float(p[-1])
    except ValueError:
        return float('nan')


def fmt_time(t):
    if t is None or (isinstance(t, float) and math.isnan(t)):
        return ''
    m = int(t // 60); return '%02d:%04.1f' % (m, t - 60 * m)


def fill_cues(T, dur):
    T = np.array(T, float); n = len(T)
    if n == 0:
        return T
    known = np.where(~np.isnan(T))[0]
    if len(known) == 0:
        lead = min(2, 0.05 * dur)
        return lead + np.arange(n) * max(dur * 0.92 - lead, 1) / n
    x = np.concatenate([[-1], known, [n]])
    y = np.concatenate([[min(0.5, T[known[0]] * 0.5)], T[known], [max(dur * 0.95, T[known[-1]] + 1)]])
    miss = np.isnan(T)
    T[miss] = np.interp(np.where(miss)[0], x, y)
    return T


def detect_onsets(y, fs):
    """attacchi musicali (aumenti improvvisi di energia), per 'aggancia alla battuta'"""
    try:
        x = np.asarray(y, float)
        if x.ndim > 1:
            x = x.mean(1)
        hop = max(1, int(round(fs * 0.01))); win = 4 * hop
        c = np.concatenate([[0], np.cumsum(x ** 2)])
        st = np.arange(0, len(x) - win, hop)
        if len(st) < 20:
            return []
        E = c[st + win] - c[st]
        fl = np.concatenate([[0], np.maximum(0, np.diff(np.log(E + 1e-9)))])
        thr = np.convolve(fl, np.ones(50) / 50, 'same') * 1.6 + 0.05
        pk = np.where((fl > thr) & (fl >= np.r_[fl[1:], 0]) & (fl >= np.r_[0, fl[:-1]]))[0]
        t = (st[pk] + win / 2) / fs
        out = []; last = -1e9
        for v in t:
            if v - last >= 0.12:
                out.append(float(v)); last = v
        return out
    except Exception:
        return []


def read_cues(path, n):
    T = [float('nan')] * n; E = [float('nan')] * n
    if not os.path.exists(path):
        return None, None
    with open(path, encoding='utf-8') as f:
        next(f, None)
        for line in f:
            c = line.rstrip('\n').split(';')
            if len(c) < 2:
                continue
            try:
                k = int(c[0]) - 1
            except ValueError:
                continue
            if 0 <= k < n:
                T[k] = parse_time(c[1])
                if len(c) >= 3:
                    E[k] = parse_time(c[2])
    if all(math.isnan(t) for t in T):
        return None, None
    return T, E


def write_cues(path, sc, T, E):
    with open(path, 'w', encoding='utf-8') as f:
        f.write('passo;inizio;fine;descrizione\n')
        for k in range(len(T)):
            f.write('%d;%s;%s;%s\n' % (k + 1, fmt_time(T[k]), fmt_time(E[k]), cue_text(sc, k).replace(';', ',')))


# ---------------------------------------------------------------- palco
def quinte_step(T):
    return T['D'] if T['nq'] <= 0 else T['D'] / T['nq']


def quinte_width(T):
    if T['nq'] <= 0:
        return 1.5
    return min(3.0, max(1.2, 1.25 * quinte_step(T)))


def quinte_y(T):
    if T['nq'] <= 0:
        return []
    s = quinte_step(T)
    return [k * s + 0.25 * s for k in range(T['nq'])]


def zone_geom(zone, T, p=(0, 0)):
    W, D, P = T['W'], T['D'], T['P']
    g = dict(shape='rect', cx=0.0, cy=D / 2, w=W, h=D, r=1.0)
    if zone == 'Tutto il palco':
        g.update(cy=(D - P) / 2, h=D + P)
    elif zone == 'Avanti':
        g.update(cy=(-P + 0.4 * D) / 2, h=0.4 * D + P)
    elif zone == 'Centro':
        g.update(w=0.55 * W, h=0.5 * D, cy=0.5 * D)
    elif zone == 'Fondo':
        g.update(cy=0.8 * D, h=0.4 * D)
    elif zone == 'Sinistra':
        g.update(cx=-W / 3, w=W / 3, cy=(D - P) / 2, h=D + P)
    elif zone == 'Destra':
        g.update(cx=W / 3, w=W / 3, cy=(D - P) / 2, h=D + P)
    elif zone == 'Fondale (ciclorama)':
        g.update(shape='cyc', cy=D - 0.15, w=W + 2 * T['wing'], h=0.3)
    elif zone == 'Puntiforme (centro)':
        g.update(shape='circle', r=1.1, cy=D / 2)
    elif zone == FOLLOW:
        g.update(shape='circle', r=0.6, cx=p[0], cy=p[1])
    return g


def zone_name(p, T):
    x, y = p; W, D = T['W'], T['D']
    if x < -W / 2:
        return 'la quinta SX'
    if x > W / 2:
        return 'la quinta DX'
    if y > D - 0.4:
        return 'il fondale'
    side = 'SX' if x < -W / 6 else ('DX' if x > W / 6 else 'centro')
    c = side == 'centro'
    if y < 0:
        return 'il centro del proscenio' if c else 'il proscenio ' + side
    if y > 2 * D / 3:
        return 'il fondo, al centro' if c else 'il fondo ' + side
    if y > D / 3:
        return 'il centro del palco' if c else 'il lato ' + side
    return 'il centro, avanti' if c else 'avanti ' + side


def move_verb(p0, p1, T):
    inw = lambda p: abs(p[0]) > T['W'] / 2
    z1 = zone_name(p1, T); z0 = zone_name(p0, T)
    if math.dist(p0, p1) < 0.35:
        return 'fa un piccolo movimento sul posto'
    if inw(p1) and not inw(p0):
        return 'esce verso ' + z1
    if inw(p0) and not inw(p1):
        return ('entra dal' + z0[2:] + ' e va verso ' + z1).replace('dal quinta', 'dalla quinta')
    return 'si sposta verso ' + z1


def action_lines(sc, k, T):
    objs = {o['id']: o for o in sc['objects']}; L = []
    for e in sc['steps'][k]:
        o = objs.get(e['spid'])
        if o is None:
            continue
        nm = o['label']
        if o['kind'] == 'light':
            if e['cls'] == 'path' and e['dur'] < 0.05:
                continue
            v = {'entr': 'si accende', 'exit': 'si spegne'}.get(e['cls'], 'segue il percorso')
            s = 'Luce %s: %s' % (nm, v)
        else:
            if e['cls'] == 'entr':
                v = 'entra in scena'
            elif e['cls'] == 'exit':
                v = 'esce di scena'
            else:
                if e['dur'] < 0.05:
                    continue
                p1 = (o['x'] + e['pts'][-1][0], o['y'] + e['pts'][-1][1])
                v = 'va verso ' + zone_name(p1, T) + (' (percorso libero)' if len(e['pts']) > 2 else '')
            s = '%s: %s' % (nm, v)
        s += '  (%.1f s' % e['dur'] + (', dopo %.1f s' % e['delay'] if e['delay'] > 0 else '') + ')'
        L.append(s.replace('.', ','))
    return L or ['(nessuna azione)']


def act_summary(sc, k):
    objs = {o['id']: o for o in sc['objects']}; out = []
    for e in sc['steps'][k]:
        o = objs.get(e['spid'])
        if o is None:
            continue
        if o['kind'] == 'light':
            s = 'luce %s %s' % (o['label'], {'entr': 'si accende', 'exit': 'si spegne'}.get(e['cls'], 'si sposta'))
        else:
            s = '%s %s' % (o['label'], {'entr': 'entra', 'exit': 'esce'}.get(e['cls'], 'si muove'))
        if s not in out:
            out.append(s)
    return ', '.join(out) if out else 'nessuna azione'


def describe_step(sc, k, T):
    objs = {o['id']: o for o in sc['objects']}; L = []
    for e in sc['steps'][k]:
        o = objs.get(e['spid'])
        if o is None:
            continue
        nm = o['label']
        if e['cls'] == 'path':
            if e['dur'] < 0.05:
                continue
            p0 = (o['x'] + e['pts'][0][0], o['y'] + e['pts'][0][1]); p1 = (o['x'] + e['pts'][-1][0], o['y'] + e['pts'][-1][1])
            if o['kind'] == 'char':
                L.append('• %s: %s' % (nm, move_verb(p0, p1, T)))
            elif o['kind'] == 'light':
                L.append('• Luce "%s": segue verso %s' % (nm, zone_name(p1, T)))
            else:
                L.append('• %s: viene spostato verso %s' % (nm, zone_name(p1, T)))
        elif e['cls'] == 'entr':
            L.append('• Luce "%s": si accende' % nm if o['kind'] == 'light' else '• %s: entra in scena' % nm)
        else:
            L.append('• Luce "%s": si spegne' % nm if o['kind'] == 'light' else '• %s: esce di scena' % nm)
    return L


def start_text(sc):
    if sc['start']:
        return sc['start']
    nm = [o['label'] for o in sc['objects'] if o['start'] and o['kind'] == 'char']
    return 'Inizio della scena: palco vuoto.' if not nm else 'Inizio della scena: in scena ' + ', '.join(nm) + '.'


def find_music(folder, num):
    d = os.path.join(folder, 'audio')
    if not os.path.isdir(d):
        return ''
    for f in sorted(os.listdir(d)):
        nm, ex = os.path.splitext(f)
        if ex.lower() not in ('.mp3', '.wav', '.m4a', '.ogg', '.flac', '.aac'):
            continue
        m = re.match(r'\s*(\d+)', nm)
        if m and int(m.group(1)) == num:
            return os.path.join(d, f)
    return ''


def cue_path(folder, sc):
    return os.path.join(folder, 'cue', 'scena_%d.cue.csv' % sc['uid'])


def roman(n):
    R = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X']
    return R[n] if isinstance(n, int) and 0 <= n <= 10 else str(n)


def safe_name(t):
    return re.sub(r'[\\/:*?"<>|]', '-', str(t)).strip()


def initials(nm):
    w = [x for x in nm.strip().split() if x]
    stop = {'il', 'lo', 'la', 'i', 'gli', 'le', "l'", 'un', 'una', 'di', 'de', 'del', 'della'}
    w2 = [x for x in w if x.lower() not in stop] or w
    if not w2:
        return '?'
    return w2[0][:2].upper() if len(w2) == 1 else (w2[0][0] + w2[1][0]).upper()


def remove_from_scenes(sh, kind, nm):
    for sc in sh['scenes']:
        rm = [o for o in sc['objects'] if o['kind'] == kind and o['ref'] == nm]
        if kind == 'char':
            rm += [o for o in sc['objects'] if o['kind'] == 'light' and o['label'].endswith(' su ' + nm)]
        ids = {o['id'] for o in rm}
        if not ids:
            continue
        sc['objects'] = [o for o in sc['objects'] if o['id'] not in ids]
        sc['steps'] = [[e for e in st if e['spid'] not in ids] for st in sc['steps']]
        if kind == 'char':
            sc['cast'] = [c for c in sc['cast'] if c['name'] != nm]


def rename_in_scenes(sh, kind, old, new):
    for sc in sh['scenes']:
        for o in sc['objects']:
            if o['kind'] == kind and o['ref'] == old:
                o['ref'] = new; o['label'] = new
            if kind == 'char' and o['kind'] == 'light' and o['label'].endswith(' su ' + old):
                o['label'] = o['label'][:-len(old)] + new
        if kind == 'char':
            for c in sc['cast']:
                if c['name'] == old:
                    c['name'] = new


def sort_scenes(sh):
    sh['scenes'].sort(key=lambda s: (s['act'], s['num']))


def plan_color(e):
    return e['rgb'] if e['tint'] else [0.6, 0.5, 0.38]
