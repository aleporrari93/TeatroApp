"""Importazione di modelli 3D (.glb, .obj, .npz) e conversione nel formato leggero del programma."""
import io
import json
import os
import struct

import numpy as np

from . import library as L
from .model import safe_name


def _part(V, F, C, alpha, name):
    return dict(V=np.asarray(V, float), F=np.asarray(F, np.int64), C=np.asarray(C, float), alpha=float(alpha), name=name)


# ---------------------------------------------------------------- OBJ
def _read_mtl(path, mats):
    cur = None
    for line in open(path, encoding='utf-8', errors='ignore'):
        s = line.strip()
        if s.startswith('newmtl'):
            cur = s[6:].strip(); mats[cur] = dict(kd=[0.75, 0.75, 0.75], d=1.0)
        elif cur and s.startswith('Kd'):
            v = [float(x) for x in s[2:].split()[:3]]
            if len(v) == 3:
                mats[cur]['kd'] = v
        elif cur and s.startswith('d '):
            try:
                mats[cur]['d'] = float(s[2:].split()[0])
            except (ValueError, IndexError):
                pass
        elif cur and s.startswith('map_Kd'):
            try:
                from PIL import Image
                im = np.asarray(Image.open(os.path.join(os.path.dirname(path), s[6:].strip())).convert('RGB'), float) / 255
                mats[cur]['kd'] = list(np.asarray(mats[cur]['kd']) * im.reshape(-1, 3).mean(0))
            except Exception:
                pass
    return mats


def read_obj(path):
    V = []; VC = []; faces = {}; cur = ''; mats = {}
    for line in open(path, encoding='utf-8', errors='ignore'):
        if line.startswith('v '):
            v = line.split()[1:]
            V.append([float(x) for x in v[:3]])
            if len(v) >= 6:
                VC.append([float(x) for x in v[3:6]])
        elif line.startswith('f '):
            ids = []
            for tok in line.split()[1:]:
                i = int(tok.split('/')[0]); ids.append(i - 1 if i > 0 else len(V) + i)
            fl = faces.setdefault(cur, [])
            for t in range(1, len(ids) - 1):
                fl.append((ids[0], ids[t], ids[t + 1]))
        elif line.startswith('usemtl'):
            cur = line[6:].strip()
        elif line.startswith('mtllib'):
            mf = os.path.join(os.path.dirname(path), line[6:].strip())
            if os.path.exists(mf):
                _read_mtl(mf, mats)
    if not V:
        raise ValueError('nessun vertice nel file .obj')
    V = np.asarray(V, float); VC = np.asarray(VC, float) if len(VC) == len(V) else None
    P = []
    for name, fl in faces.items():
        F = np.asarray(fl, np.int64); u, inv = np.unique(F.ravel(), return_inverse=True)
        m = mats.get(name, dict(kd=[0.75, 0.75, 0.75], d=1.0))
        C = VC[u] if VC is not None else np.tile(m['kd'], (len(u), 1))
        P.append(_part(V[u], inv.reshape(F.shape), C, m['d'], name or 'modello'))
    return P


# ---------------------------------------------------------------- GLB
_CT = {5126: ('<f4', 4), 5125: ('<u4', 4), 5123: ('<u2', 2), 5122: ('<i2', 2), 5121: ('u1', 1), 5120: ('i1', 1)}
_NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def read_glb(path):
    data = open(path, 'rb').read()
    if len(data) < 20 or data[:4] != b'glTF':
        raise ValueError('il file non e\' un .glb valido')
    L0 = struct.unpack('<I', data[12:16])[0]
    G = json.loads(data[20:20 + L0].decode('utf-8'))
    o = 20 + L0; binc = b''
    if len(data) >= o + 8:
        L1 = struct.unpack('<I', data[o:o + 4])[0]; binc = data[o + 8:o + 8 + L1]

    def acc(i):
        a = G['accessors'][i]; dt, nb = _CT[a['componentType']]; nc = _NC[a['type']]
        bv = G['bufferViews'][a['bufferView']]
        off = bv.get('byteOffset', 0) + a.get('byteOffset', 0); n = a['count']; es = nb * nc
        stride = bv.get('byteStride') or es
        if stride == es:
            arr = np.frombuffer(binc, dtype=dt, count=n * nc, offset=off).reshape(n, nc)
        else:
            raw = np.frombuffer(binc, dtype=np.uint8)
            idx = off + np.arange(n)[:, None] * stride + np.arange(es)[None, :]
            arr = raw[idx].copy().view(dt).reshape(n, nc)
        arr = arr.astype(float)
        if a.get('normalized') and dt != '<f4':
            arr /= float(np.iinfo(np.dtype(dt)).max)
        return arr

    def tex_mean(ti):
        try:
            from PIL import Image
            im = G['images'][G['textures'][ti]['source']]; bv = G['bufferViews'][im['bufferView']]
            off = bv.get('byteOffset', 0)
            img = Image.open(io.BytesIO(binc[off:off + bv['byteLength']])).convert('RGB')
            return np.asarray(img, float).reshape(-1, 3).mean(0) / 255
        except Exception:
            return np.ones(3)

    def mat_colour(mi):
        m = G.get('materials', [])[mi]; col = np.ones(3); a = 1.0
        pb = m.get('pbrMetallicRoughness', {})
        if 'baseColorFactor' in pb:
            f = pb['baseColorFactor']; col = np.asarray(f[:3], float); a = f[3] if len(f) > 3 else 1.0
        if 'baseColorTexture' in pb:
            col = col * tex_mean(pb['baseColorTexture']['index'])
        if m.get('alphaMode') != 'BLEND':
            a = 1.0
        return col, a

    P = []

    def add_mesh(mi, Mw):
        me = G['meshes'][mi]
        for pr in me['primitives']:
            if pr.get('mode', 4) != 4:
                continue
            if 'KHR_draco_mesh_compression' in pr.get('extensions', {}):
                raise ValueError('il modello e\' compresso (Draco): riesportalo senza compressione')
            V = acc(pr['attributes']['POSITION'])[:, :3]
            I = acc(pr['indices']).astype(np.int64).ravel() if 'indices' in pr else np.arange(len(V))
            F = I.reshape(-1, 3)
            col, a = mat_colour(pr['material']) if 'material' in pr and 'materials' in G else (np.ones(3), 1.0)
            if 'COLOR_0' in pr['attributes']:
                C = acc(pr['attributes']['COLOR_0'])[:, :3] * col
            else:
                C = np.tile(col, (len(V), 1))
            Vh = np.c_[V, np.ones(len(V))] @ Mw.T
            P.append(_part(Vh[:, :3], F, C, a, me.get('name', 'mesh %d' % mi)))

    def node_matrix(nd):
        if 'matrix' in nd:
            return np.asarray(nd['matrix'], float).reshape(4, 4).T
        Tm = np.eye(4); Rm = np.eye(4); Sm = np.eye(4)
        if 'translation' in nd:
            Tm[:3, 3] = nd['translation']
        if 'rotation' in nd:
            x, y, z, w = nd['rotation']
            Rm[:3, :3] = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
        if 'scale' in nd:
            Sm = np.diag(list(nd['scale']) + [1])
        return Tm @ Rm @ Sm

    def walk(ni, Mp, depth=0):
        if depth > 64:
            return
        nd = G['nodes'][ni]; Mw = Mp @ node_matrix(nd)
        if 'mesh' in nd:
            add_mesh(nd['mesh'], Mw)
        for c in nd.get('children', []):
            walk(c, Mw, depth + 1)

    scenes = G.get('scenes', [])
    if scenes and 'nodes' in G:
        for r in scenes[G.get('scene', 0)].get('nodes', []):
            walk(r, np.eye(4))
    else:
        for mi in range(len(G.get('meshes', []))):
            add_mesh(mi, np.eye(4))
    if not P:
        raise ValueError('nessuna mesh trovata nel file .glb')
    return P


# ---------------------------------------------------------------- conversione
def _decimate(V, F, C, target):
    """semplificazione per raggruppamento di vertici su griglia (mantiene la forma generale)"""
    if len(F) <= target:
        return V, F, C
    ext = (V.max(0) - V.min(0)).max()
    cell = ext / max(10, np.sqrt(target) * 1.2)
    for _ in range(12):
        key = np.floor((V - V.min(0)) / cell).astype(np.int64)
        _, idx, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
        inv = inv.ravel()
        F2 = inv[F]
        ok = (F2[:, 0] != F2[:, 1]) & (F2[:, 1] != F2[:, 2]) & (F2[:, 0] != F2[:, 2])
        F2 = F2[ok]
        if len(F2) <= target * 1.1 or cell > ext:
            cnt = np.bincount(inv); V2 = np.zeros((len(idx), 3)); C2 = np.zeros((len(idx), 3))
            np.add.at(V2, inv, V); np.add.at(C2, inv, C)
            return V2 / cnt[:, None], F2, C2 / cnt[:, None]
        cell *= 1.3
    return V, F, C


def normalize(P, yup):
    if yup:
        for p in P:
            v = p['V']; p['V'] = np.c_[v[:, 0], -v[:, 2], v[:, 1]]
    V = np.vstack([p['V'] for p in P])
    big = (V.max(0) - V.min(0)).max()
    s = 0.001 if big > 300 else (0.01 if big > 30 else 1.0)
    V = V * s; mn = V.min(0); mx = V.max(0); c = np.array([(mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]])
    nf = sum(len(p['F']) for p in P); ratio = min(1.0, 80000 / max(nf, 1))
    out = []
    for p in P:
        v = p['V'] * s - c; F = p['F']; C = np.asarray(p['C'], float)
        if C.max() > 1:
            C = C / 255
        if ratio < 1 and len(F) > 500:
            v, F, C = _decimate(v, F, C, int(len(F) * ratio))
        out.append(dict(V=v, F=F, C=C, alpha=p.get('alpha', 1.0), tint=0.0, mix=np.zeros(0), name=p.get('name', 'parte')))
    return out


def import_model(src, folder, yup=None):
    """legge src, lo converte e lo salva in folder/modelli. Ritorna (nome file, misure [l, p, h], numero facce)"""
    ext = os.path.splitext(src)[1].lower()
    if ext == '.glb':
        P = read_glb(src); yup = True if yup is None else yup
    elif ext == '.obj':
        P = read_obj(src); yup = True if yup is None else yup
    elif ext == '.npz':
        P = [dict(p) for p in L.load_npz_parts(src)]; yup = False if yup is None else yup
    else:
        raise ValueError('formato non supportato: ' + ext)
    P = normalize(P, yup)
    V = np.vstack([p['V'] for p in P]); bb = (V.max(0) - V.min(0)).tolist()
    base = safe_name(os.path.splitext(os.path.basename(src))[0]) or 'modello'
    d = os.path.join(folder, 'modelli'); os.makedirs(d, exist_ok=True)
    fn = base + '.npz'; k = 2
    while os.path.exists(os.path.join(d, fn)):
        fn = '%s_%d.npz' % (base, k); k += 1
    L.save_npz_parts(os.path.join(d, fn), P)
    return fn, bb, sum(len(p['F']) for p in P)
