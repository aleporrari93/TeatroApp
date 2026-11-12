"""PDF della scena (testo + vista dalla platea) e dell'intero copione (solo testo)."""
import math

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (BaseDocTemplate, Frame, Image, NextPageTemplate, PageBreak, PageTemplate, Paragraph,
                                Spacer)

from . import model as M

GOLD = colors.HexColor('#73501a')
ST = dict(
    title=ParagraphStyle('t', fontName='Helvetica-Bold', fontSize=22, leading=26, alignment=TA_CENTER, textColor=GOLD),
    sub=ParagraphStyle('s', fontName='Helvetica', fontSize=12, leading=15, alignment=TA_CENTER, textColor=colors.HexColor('#333333')),
    h=ParagraphStyle('h', fontName='Helvetica-Bold', fontSize=11, leading=14, spaceBefore=6, textColor=colors.HexColor('#111111')),
    d=ParagraphStyle('d', fontName='Helvetica', fontSize=9.5, leading=12, leftIndent=18, textColor=colors.HexColor('#383838')),
    b=ParagraphStyle('b', fontName='Helvetica-Oblique', fontSize=9.5, leading=12, leftIndent=18, textColor=colors.HexColor('#5a3873')),
    i=ParagraphStyle('i', fontName='Helvetica', fontSize=10, leading=13, textColor=colors.HexColor('#4d4026')),
    toc=ParagraphStyle('c', fontName='Helvetica', fontSize=11, leading=17, leftIndent=12),
)


def _esc(s):
    return str(s).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


class _Doc(BaseDocTemplate):
    def __init__(self, path, footer):
        super().__init__(path, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=1.8 * cm, bottomMargin=1.8 * cm)
        self.footer = footer
        fp = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id='p')
        lw, lh = landscape(A4)
        fl = Frame(1 * cm, 1 * cm, lw - 2 * cm, lh - 2 * cm, id='l')
        self.addPageTemplates([PageTemplate('port', [fp], pagesize=A4, onPage=self._foot),
                               PageTemplate('land', [fl], pagesize=landscape(A4), onPage=self._foot)])

    def _foot(self, c, d):
        c.saveState(); c.setFont('Helvetica', 8); c.setFillColor(colors.grey)
        w = c._pagesize[0]
        c.drawRightString(w - 2 * cm, 1 * cm, '%s  -  pag. %d' % (self.footer, d.page)); c.restoreState()


def scene_story(sh, sc, cue_times=None):
    T = sh['theater']; S = []
    S += [Paragraph(_esc(sc['title']), ST['title']), Spacer(1, 4),
          Paragraph('Atto %s  ·  Scena %d  ·  %s' % (M.roman(sc['act']), sc['num'], _esc(sh['title'])), ST['sub']), Spacer(1, 14)]
    if sc['start']:
        S.append(Paragraph('<b>Situazione iniziale:</b> ' + _esc(sc['start']), ST['i']))
    names = []
    for o in sc['objects']:
        if o['kind'] == 'char' and o['ref'] not in names:
            names.append(o['ref'])
    if names:
        parts = []
        for nm in names:
            code = M.cast_code(sh, sc, nm); ch = M.find_char(sh, nm); d = ''
            if ch:
                co = next((c for c in ch['costumes'] if c['code'] == code), None)
                d = ': ' + co['desc'] if co and co['desc'] else ''
            parts.append('%s (costume %s%s)' % (nm, code, d))
        S.append(Paragraph('<b>Personaggi:</b> ' + _esc(', '.join(parts)), ST['i']))
    S.append(Spacer(1, 8))
    if not sc['steps']:
        S.append(Paragraph('Nessun passo in questa scena.', ST['d']))
    for k in range(len(sc['steps'])):
        t = 'Passo %d  —  %s' % (k + 1, M.cue_text(sc, k))
        if cue_times and k < len(cue_times) and not math.isnan(cue_times[k]):
            t += '   [%s]' % M.fmt_time(cue_times[k])
        S.append(Paragraph(_esc(t), ST['h']))
        for a in M.action_lines(sc, k, T):
            S.append(Paragraph(_esc(a), ST['d']))
        if k < len(sc['ens']) and sc['ens'][k]:
            S.append(Paragraph(_esc('Corpo di ballo / note: ' + sc['ens'][k]), ST['b']))
    return S


def scene_pdf(path, sh, sc, cue_times=None, image_png=None):
    doc = _Doc(path, sc['title'])
    S = scene_story(sh, sc, cue_times)
    if image_png:
        lw, lh = landscape(A4)
        from PIL import Image as PI
        iw, ih = PI.open(image_png).size
        w = lw - 2 * cm; h = w * ih / iw
        if h > lh - 4 * cm:
            h = lh - 4 * cm; w = h * iw / ih
        S += [NextPageTemplate('land'), PageBreak(),
              Paragraph('Atto %s  -  Scena %d  -  %s  -  vista dalla platea' % (M.roman(sc['act']), sc['num'], _esc(sc['title'])), ST['sub']),
              Spacer(1, 6), Image(image_png, width=w, height=h),
              Paragraph('Personaggi ed elementi nel punto in cui compaiono per la prima volta', ST['sub'])]
    doc.build(S)


def script_pdf(path, sh, folder):
    M.sort_scenes(sh)
    doc = _Doc(path, sh['title'])
    S = [Paragraph(_esc(sh['title']), ST['title']), Spacer(1, 4), Paragraph('Copione di regia  -  elenco delle scene', ST['sub']), Spacer(1, 18)]
    for sc in sh['scenes']:
        S.append(Paragraph(_esc('Atto %s    Scena %d    %s' % (M.roman(sc['act']), sc['num'], sc['title'])), ST['toc']))
    for sc in sh['scenes']:
        T, _ = M.read_cues(M.cue_path(folder, sc), len(sc['steps']))
        S += [PageBreak()] + scene_story(sh, sc, T)
    doc.build(S)
