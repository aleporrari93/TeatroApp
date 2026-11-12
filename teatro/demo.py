"""Spettacolo di esempio, per imparare a usare il programma."""
from . import model as M


def make_demo(base):
    t = 'Spettacolo di esempio'
    folder = M.make_show_folder(base, t)
    sh = M.default_show(t); T = sh['theater']; Lw = sh['lights']
    gi = M.new_char('Giulia', 'F', 1); ma = M.new_char('Marco', 'M', 2); na = M.new_char('Il Narratore', 'M', 3)
    c = gi['costumes'][0]; c['desc'] = 'abito rosso da sera'
    M.set_item(c['items'], 'Sopra', ''); M.set_item(c['items'], 'Sotto', '')
    M.set_item(c['items'], 'Abito', 'abito_lungo'); c['irgb'][5] = [0.72, 0.2, 0.29]
    M.set_item(c['items'], 'Scarpe', 'tacchi'); c['irgb'][6] = [0.1, 0.1, 0.1]
    c['hair'] = 'raccolti'; c['hairRGB'] = [0.42, 0.24, 0.12]; c['mk']['lips'] = 1; c['mk']['lipsRGB'] = [0.72, 0.12, 0.18]; c['mk']['lashes'] = 1
    c2 = M.copy.deepcopy(c); c2['code'] = 'B'; c2['desc'] = 'jeans e giubbotto'
    M.set_item(c2['items'], 'Abito', ''); M.set_item(c2['items'], 'Sopra', 'tshirt'); c2['irgb'][0] = [0.95, 0.95, 0.92]
    M.set_item(c2['items'], 'Giacca', 'giubbotto'); c2['irgb'][2] = [0.3, 0.22, 0.16]
    M.set_item(c2['items'], 'Sotto', 'jeans'); c2['irgb'][4] = [0.23, 0.36, 0.55]
    M.set_item(c2['items'], 'Scarpe', 'stivali'); c2['irgb'][6] = [0.16, 0.11, 0.07]; c2['hair'] = 'mossi'
    gi['costumes'].append(c2)
    c = ma['costumes'][0]; c['desc'] = 'camicia e gilet'
    M.set_item(c['items'], 'Sopra', 'camicia'); c['irgb'][0] = [0.96, 0.95, 0.92]
    M.set_item(c['items'], 'Gilet', 'gilet'); c['irgb'][1] = [0.23, 0.23, 0.28]
    M.set_item(c['items'], 'Sotto', 'pantaloni'); c['irgb'][4] = [0.17, 0.17, 0.2]
    c['hair'] = 'pettinati'; c['hairRGB'] = [0.2, 0.13, 0.08]; c['facial'] = 'barba'; c['facialRGB'] = [0.2, 0.13, 0.08]
    ma['skin'] = [0.82, 0.62, 0.46]
    c = na['costumes'][0]; c['desc'] = 'cappotto e cappello'
    M.set_item(c['items'], 'Sopra', 'maglione'); c['irgb'][0] = [0.45, 0.16, 0.16]
    M.set_item(c['items'], 'Giacca', 'cappotto'); c['irgb'][2] = [0.23, 0.23, 0.24]
    M.set_item(c['items'], 'Sotto', 'pantaloni'); c['irgb'][4] = [0.3, 0.3, 0.32]
    M.set_item(c['items'], 'Scarpe', 'stivali'); c['irgb'][6] = [0.1, 0.08, 0.06]
    M.set_item(c['items'], 'Cappello', 'fedora'); c['irgb'][7] = [0.15, 0.15, 0.15]
    c['hair'] = 'corti'; c['hairRGB'] = [0.5, 0.5, 0.5]; c['facial'] = 'baffi'; c['facialRGB'] = [0.55, 0.55, 0.55]
    na['height'] = 1.8
    sh['chars'] = [gi, ma, na]
    sh['elements'] = [M.new_element('Panca', 'lib', 'panca', [1.6, 0.35, 0.47], [0.54, 0.38, 0.22], True),
                      M.new_element('Praticabile 2x1', 'lib', 'praticabile', [2, 1, 0.41], [0.42, 0.35, 0.28], True),
                      M.new_element('Colonna', 'lib', 'colonna', [0.6, 0.6, 3.2], [0.7, 0.65, 0.55], True)]
    col2 = dict(sh['elements'][2]); col2['name'] = 'Colonna 2'
    sh['elements'][2].update(fixed=True, x=-3.0, y=T['D'] - 1.2); col2.update(fixed=True, x=3.0, y=T['D'] - 1.2)
    sh['elements'].append(col2)
    ow = next(l for l in Lw if l['zone'] == M.FOLLOW); lc = next(l for l in Lw if l['zone'] == 'Fondale (ciclorama)')
    lw = next(l for l in Lw if l['zone'] == 'Tutto il palco')
    # scena 0
    sc = M.new_scene(M.new_uid(sh), 1, 0, 'Ouverture', "Buio. Il Narratore e' gia' in scena, in fondo al centro.")
    o1 = M.new_obj(M.new_uid(sh), 'char', 'Il Narratore', 'Il Narratore', 0, 6, na['pawn'], start=True)
    o2 = M.new_obj(M.new_uid(sh), 'light', ow['name'], ow['name'] + ' su Il Narratore', 0, 6, ow['rgb'], M.FOLLOW)
    g = M.zone_geom(lc['zone'], T)
    o3 = M.new_obj(M.new_uid(sh), 'light', lc['name'], lc['name'], g['cx'], g['cy'], lc['rgb'], lc['zone'])
    sc['objects'] = [o1, o2, o3]
    sc['steps'] = [[M.mk_eff('entr', o3['id'], [], 2, 0), M.mk_eff('entr', o2['id'], [], 1, 0.5)],
                   [M.mk_eff('path', o1['id'], [[0, 0], [0, -3.5]], 4, 0), M.mk_eff('path', o2['id'], [[0, 0], [0, -3.5]], 4, 0)],
                   [M.mk_eff('exit', o2['id'], [], 1.5, 0), M.mk_eff('exit', o3['id'], [], 2, 0.5)]]
    sc['cues'] = ['Si accende il fondale; un occhio di bue cerca il Narratore', 'Il Narratore avanza verso il pubblico', 'Buio']
    sc['ens'] = ['', '', '']
    sh['scenes'].append(sc)
    # scena 1
    sc = M.new_scene(M.new_uid(sh), 1, 1, "L'incontro", 'Piazza. Luce calda su tutto il palco. La panca e\' a sinistra.')
    sc['cast'] = [dict(name='Giulia', code='A'), dict(name='Marco', code='A')]
    g = M.zone_geom(lw['zone'], T)
    l1 = M.new_obj(M.new_uid(sh), 'light', lw['name'], lw['name'], g['cx'], g['cy'], lw['rgb'], lw['zone'], start=True)
    pa = M.new_obj(M.new_uid(sh), 'el', 'Panca', 'Panca', -2.2, 3.5, [0.54, 0.38, 0.22], '', 1.6, 0.35, 0, True)
    g1 = M.new_obj(M.new_uid(sh), 'char', 'Giulia', 'Giulia', -T['W'] / 2 - 0.8, 2.5, gi['pawn'])
    m1 = M.new_obj(M.new_uid(sh), 'char', 'Marco', 'Marco', T['W'] / 2 + 0.8, 4, ma['pawn'])
    sc['objects'] = [l1, pa, g1, m1]
    sc['steps'] = [[M.mk_eff('entr', g1['id'], [], 0.5, 0), M.mk_eff('path', g1['id'], [[0, 0], [2.5, 0.5], [5.0, 0.5]], 3, 0.5)],
                   [M.mk_eff('entr', m1['id'], [], 0.5, 0), M.mk_eff('path', m1['id'], [[0, 0], [-3, -0.5], [-5.2, -1.0]], 3.5, 0.5)],
                   [M.mk_eff('path', g1['id'], [[5.0, 0.5], [5.2, -0.5]], 2, 0), M.mk_eff('path', m1['id'], [[-5.2, -1.0], [-5.4, -2.0]], 2, 0)],
                   [M.mk_eff('path', g1['id'], [[5.2, -0.5], [4.5, 0.5], [3.6, 1.0]], 3, 0),
                    M.mk_eff('path', m1['id'], [[-5.4, -2.0], [-3, -1], [1.5, 0]], 3, 0.8), M.mk_eff('exit', m1['id'], [], 0.6, 3.6)]]
    sc['cues'] = ['Giulia entra da sinistra e attraversa la piazza', 'Marco entra da destra', 'Si incontrano al centro, avanti',
                  'Giulia va verso la panca, Marco esce a destra']
    sc['ens'] = ['', 'Il coro entra dal fondo e si dispone a semicerchio', '', '']
    sh['scenes'].append(sc)
    M.save_show(sh, folder)
    return folder
