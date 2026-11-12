function TeatroApp()
% TEATROAPP  Regia di spettacoli teatrali: crea uno spettacolo da zero e gestiscine piu' di uno.
%
%   TeatroApp            apre la finestra iniziale con l'elenco degli spettacoli
%
%   Ogni spettacolo e' una cartella dentro "spettacoli":
%       spettacolo.mat   teatro, luci, scenografia, personaggi, scene e passi
%       audio\           le canzoni: "00 ....mp3" (intro), "01 ....mp3", "02 ....mp3" ...
%                        il numero iniziale del file corrisponde al numero della scena
%       modelli\         modelli 3D importati (.glb, .obj convertiti in .mat leggeri)
%       cue\             tempi dei passi registrati con "Registra"
%   La libreria (corpi, capi, capelli, trucco, elementi scenici) e' nella cartella "libreria".
%   Grafica classica (figure/uicontrol): MATLAB R2016b o successivo.

appDir = fileparts(mfilename('fullpath'));
libDir = fullfile(appDir, 'libreria');
showsDir = fullfile(appDir, 'spettacoli');
if ~exist(showsDir, 'dir'), mkdir(showsDir); end
if ~exist(fullfile(libDir, 'catalogo.csv'), 'file')
    errordlg(sprintf('Libreria non trovata:\n%s\nLa cartella "libreria" deve stare accanto a TeatroApp.m.', libDir), 'Teatro'); return
end

BG = [0.08 0.09 0.11]; PANEL = [0.13 0.145 0.17]; GOLD = [0.83 0.69 0.35]; TXT = [0.95 0.93 0.89]; DIM = [0.7 0.67 0.62];
CAT = readCatalog(fullfile(libDir, 'catalogo.csv'));
SLOTS = {'Sopra', 'Gilet', 'Giacca', 'Mantello', 'Sotto', 'Abito', 'Scarpe', 'Cappello', 'Accessorio', 'Accessorio'};
SLOTLBL = {'Maglia / camicia', 'Gilet', 'Giacca', 'Mantello', 'Pantaloni / gonna', 'Abito intero', 'Scarpe', 'Cappello', 'Accessorio 1', 'Accessorio 2'};
NSLOT = numel(SLOTS);
LT = lightLibrary();
[COLN, COLV] = lightColours();
ZONES = {'Tutto il palco', 'Avanti', 'Centro', 'Fondo', 'Sinistra', 'Destra', 'Fondale (ciclorama)', 'Puntiforme (centro)', 'Segue un personaggio'};
SKINS = {'Molto chiara', [0.96 0.84 0.74]; 'Chiara', [0.93 0.76 0.62]; 'Media', [0.82 0.62 0.46]; 'Olivastra', [0.74 0.55 0.38]; ...
         'Scura', [0.55 0.37 0.25]; 'Molto scura', [0.36 0.24 0.17]};
EYES = {'Castani', [0.29 0.2 0.14]; 'Nocciola', [0.45 0.32 0.18]; 'Verdi', [0.24 0.42 0.23]; 'Azzurri', [0.29 0.48 0.66]; ...
        'Grigi', [0.45 0.48 0.5]; 'Neri', [0.1 0.08 0.07]};
BROWS = {'sottili', 'normali', 'folte'};

SH = []; showDir = '';
S = struct();
S.cacheB = containers.Map(); S.cacheP = containers.Map(); S.cacheL = containers.Map();
S.idx = 1; S.objs = []; S.pos = zeros(0, 2); S.A = []; S.g2 = {}; S.h3 = []; S.player = []; S.running = false; S.step = 0;
S.stop = false; S.token = 0; S.fs = 1; S.dur = 0; S.seek = []; S.dragging = false; S.view3 = false; S.syncing = false;
S.rec = false; S.recT = []; S.cueT = []; S.cueEnd = []; S.onsets = []; S.snap = false; S.cueFig = []; S.camDrag = []; S.camCur = []; S.cam0 = [];
S.stepFig = []; S.homeList = [];
figHome = []; figShow = []; figSet = []; figScene = [];
hHome = struct(); hShow = struct();

openHome();

% =====================================================================
%                        FINESTRA INIZIALE
% =====================================================================
    function openHome()
        if ~isempty(figHome) && ishandle(figHome), figure(figHome); refreshHome(); return; end
        figHome = figure('Name', 'Teatro  -  i miei spettacoli', 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', ...
            'ToolBar', 'none', 'Units', 'normalized', 'Position', [0.25 0.15 0.5 0.7], 'CloseRequestFcn', @closeHome);
        uicontrol(figHome, 'Style', 'text', 'String', 'I MIEI SPETTACOLI', 'FontSize', 20, 'FontWeight', 'bold', ...
            'ForegroundColor', GOLD, 'BackgroundColor', BG, 'Units', 'normalized', 'Position', [0.03 0.9 0.94 0.07]);
        uicontrol(figHome, 'Style', 'text', 'String', 'Doppio clic su uno spettacolo per aprirlo. Ogni spettacolo si salva da solo nella sua cartella.', ...
            'FontSize', 10, 'ForegroundColor', DIM, 'BackgroundColor', BG, 'Units', 'normalized', 'Position', [0.03 0.86 0.94 0.035]);
        hHome.lb = uicontrol(figHome, 'Style', 'listbox', 'FontSize', 12, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [0.03 0.2 0.68 0.65], 'Callback', @homeClick);
        b = @(str, y, cb) uicontrol(figHome, 'Style', 'pushbutton', 'String', str, 'FontSize', 11, 'Units', 'normalized', ...
            'Position', [0.73 y 0.24 0.06], 'Callback', cb);
        h = b('+ Nuovo spettacolo', 0.79, @(~,~) newShowDlg()); set(h, 'FontWeight', 'bold');
        b('Apri', 0.72, @(~,~) openSelected());
        b('Duplica', 0.65, @(~,~) dupShow());
        b('Rinomina', 0.58, @(~,~) renameShow());
        b('Elimina', 0.51, @(~,~) delShow());
        b('Esporta in .zip', 0.42, @(~,~) exportShow());
        b('Importa da .zip', 0.35, @(~,~) importShow());
        b('Apri la cartella', 0.28, @(~,~) openFolder(showsDir));
        b('Crea spettacolo di esempio', 0.2, @(~,~) makeDemo());
        hHome.st = uicontrol(figHome, 'Style', 'text', 'String', '', 'FontSize', 10, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.03 0.03 0.94 0.12]);
        refreshHome();
    end

    function closeHome(src, ~)
        if ~isempty(figShow) && ishandle(figShow)
            set(src, 'Visible', 'off');
        else
            delete(src);
        end
    end

    function refreshHome()
        if isempty(figHome) || ~ishandle(figHome), return; end
        d = dir(showsDir); L = struct('folder', {}, 'title', {}, 'date', {}, 'n', {});
        for q = 1:numel(d)
            if ~d(q).isdir || d(q).name(1) == '.', continue; end
            fn = fullfile(showsDir, d(q).name, 'spettacolo.mat');
            if ~exist(fn, 'file'), continue; end
            try
                X = load(fn); t = X.SH.title; dt = ''; if isfield(X.SH, 'modified'), dt = X.SH.modified; end
                n = 0; if isfield(X.SH, 'scenes'), n = numel(X.SH.scenes); end
            catch
                t = d(q).name; dt = ''; n = 0;
            end
            L(end+1) = struct('folder', d(q).name, 'title', t, 'date', dt, 'n', n); %#ok<AGROW>
        end
        if ~isempty(L)
            [~, o] = sort({L.date}); L = L(fliplr(o));
        end
        S.homeList = L;
        items = arrayfun(@(x) sprintf('%s      (%d scene, modificato %s)', x.title, x.n, x.date), L, 'UniformOutput', false);
        if isempty(items), items = {'(nessuno spettacolo: premi "+ Nuovo spettacolo" oppure "Crea spettacolo di esempio")'}; end
        v = get(hHome.lb, 'Value'); if isempty(v) || v > numel(items), v = 1; end
        set(hHome.lb, 'String', items, 'Value', v);
    end

    function homeClick(~, ~)
        if strcmp(get(figHome, 'SelectionType'), 'open'), openSelected(); end
    end

    function i = homeSel()
        i = get(hHome.lb, 'Value'); if isempty(S.homeList) || i > numel(S.homeList), i = 0; end
    end

    function homeMsg(s)
        if ~isempty(figHome) && ishandle(figHome), set(hHome.st, 'String', s); end
    end

    function newShowDlg()
        a = inputdlg({'Titolo dello spettacolo'}, 'Nuovo spettacolo', [1 60], {''});
        if isempty(a) || isempty(strtrim(a{1})), return; end
        t = strtrim(a{1});
        folder = uniqueFolder(safeName(t));
        dd = fullfile(showsDir, folder);
        mkdir(dd); mkdir(fullfile(dd, 'audio')); mkdir(fullfile(dd, 'modelli')); mkdir(fullfile(dd, 'cue'));
        closeShowWindows();
        SH = defaultShow(t); showDir = dd; saveShow();
        refreshHome(); openShowWin(); openSettings(1, true);
    end

    function f = uniqueFolder(base)
        if isempty(base), base = 'Spettacolo'; end
        f = base; n = 2;
        while exist(fullfile(showsDir, f), 'dir'), f = sprintf('%s (%d)', base, n); n = n + 1; end
    end

    function openSelected()
        i = homeSel(); if i == 0, return; end
        openShowFolder(fullfile(showsDir, S.homeList(i).folder));
    end

    function openShowFolder(dd)
        try
            X = load(fullfile(dd, 'spettacolo.mat'));
        catch err
            errordlg(['Impossibile aprire lo spettacolo: ' err.message], 'Teatro'); return
        end
        closeShowWindows();
        SH = normShow(X.SH); showDir = dd;
        for sub = {'audio', 'modelli', 'cue'}
            if ~exist(fullfile(dd, sub{1}), 'dir'), mkdir(fullfile(dd, sub{1})); end
        end
        S.cacheP = containers.Map(); S.cacheL = containers.Map();
        openShowWin();
    end

    function dupShow()
        i = homeSel(); if i == 0, return; end
        src = fullfile(showsDir, S.homeList(i).folder);
        t = [S.homeList(i).title ' (copia)'];
        dst = fullfile(showsDir, uniqueFolder(safeName(t)));
        copyfile(src, dst);
        X = load(fullfile(dst, 'spettacolo.mat')); X.SH.title = t; X.SH.modified = datestr(now, 'yyyy-mm-dd HH:MM'); %#ok<DATST>
        save(fullfile(dst, 'spettacolo.mat'), '-struct', 'X');
        refreshHome(); homeMsg(['Creata la copia: ' t]);
    end

    function renameShow()
        i = homeSel(); if i == 0, return; end
        a = inputdlg({'Nuovo titolo'}, 'Rinomina', [1 60], {S.homeList(i).title});
        if isempty(a) || isempty(strtrim(a{1})), return; end
        fn = fullfile(showsDir, S.homeList(i).folder, 'spettacolo.mat');
        X = load(fn); X.SH.title = strtrim(a{1}); save(fn, '-struct', 'X');
        if strcmp(showDir, fullfile(showsDir, S.homeList(i).folder)), SH.title = X.SH.title; refreshShow(); end
        refreshHome();
    end

    function delShow()
        i = homeSel(); if i == 0, return; end
        a = questdlg(sprintf('Eliminare definitivamente "%s" con tutti i suoi file?', S.homeList(i).title), 'Elimina', 'Elimina', 'Annulla', 'Annulla');
        if ~strcmp(a, 'Elimina'), return; end
        dd = fullfile(showsDir, S.homeList(i).folder);
        if strcmp(showDir, dd), closeShowWindows(); showDir = ''; SH = []; end
        try, rmdir(dd, 's'); catch err, errordlg(err.message, 'Elimina'); end
        refreshHome();
    end

    function exportShow()
        i = homeSel(); if i == 0, return; end
        [f, p] = uiputfile({'*.zip', 'Archivio zip'}, 'Esporta lo spettacolo', [S.homeList(i).folder '.zip']);
        if isequal(f, 0), return; end
        zip(fullfile(p, f), S.homeList(i).folder, showsDir);
        homeMsg(['Esportato in ' fullfile(p, f)]);
    end

    function importShow()
        [f, p] = uigetfile({'*.zip', 'Archivio zip'}, 'Importa uno spettacolo');
        if isequal(f, 0), return; end
        tmp = tempname; mkdir(tmp);
        try
            unzip(fullfile(p, f), tmp);
            m = dirRec(tmp, 'spettacolo.mat');
            if isempty(m), error('nel file .zip non c''e'' nessuno spettacolo.mat'); end
            src = fileparts(m{1}); X = load(m{1});
            dst = fullfile(showsDir, uniqueFolder(safeName(X.SH.title)));
            copyfile(src, dst);
            homeMsg(['Importato: ' X.SH.title]);
        catch err
            errordlg(['Importazione non riuscita: ' err.message], 'Importa');
        end
        try, rmdir(tmp, 's'); catch, end %#ok<NOCOM>
        refreshHome();
    end

    function closeShowWindows()
        if ~isempty(figScene) && ishandle(figScene), S.stop = true; stopMusic(); delete(figScene); end
        if ~isempty(figSet) && ishandle(figSet), delete(figSet); end
        if ~isempty(figShow) && ishandle(figShow), delete(figShow); end
        if ~isempty(S.stepFig) && ishandle(S.stepFig), delete(S.stepFig); end
        figScene = []; figSet = []; figShow = [];
    end

% =====================================================================
%                     SALVATAGGIO / DATI DELLO SPETTACOLO
% =====================================================================
    function saveShow()
        if isempty(showDir) || isempty(SH), return; end
        SH.modified = datestr(now, 'yyyy-mm-dd HH:MM'); %#ok<DATST>
        X = struct('SH', SH);
        try
            save(fullfile(showDir, 'spettacolo.mat'), '-struct', 'X');
        catch err
            errordlg(['Salvataggio non riuscito: ' err.message], 'Teatro');
        end
    end

    function id = newUid()
        SH.nextId = SH.nextId + 1; id = SH.nextId;
    end

% =====================================================================
%                     FINESTRA DELLO SPETTACOLO (elenco scene)
% =====================================================================
    function openShowWin()
        if ~isempty(figHome) && ishandle(figHome), set(figHome, 'Visible', 'off'); end
        figShow = figure('Name', ['Spettacolo  -  ' SH.title], 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', 'ToolBar', 'none', ...
            'Units', 'normalized', 'Position', [0.12 0.1 0.62 0.8], 'CloseRequestFcn', @closeShow);
        hShow.title = uicontrol(figShow, 'Style', 'text', 'String', SH.title, 'FontSize', 20, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'Units', 'normalized', 'Position', [0.02 0.92 0.96 0.06]);
        hShow.info = uicontrol(figShow, 'Style', 'text', 'String', '', 'FontSize', 10, 'ForegroundColor', DIM, 'BackgroundColor', BG, ...
            'Units', 'normalized', 'Position', [0.02 0.885 0.96 0.035]);
        tb = @(str, x, w, cb) uicontrol(figShow, 'Style', 'pushbutton', 'String', str, 'FontSize', 11, 'Units', 'normalized', ...
            'Position', [x 0.82 w 0.055], 'Callback', cb);
        tb('Teatro', 0.02, 0.15, @(~,~) openSettings(1, false));
        tb('Luci', 0.18, 0.15, @(~,~) openSettings(2, false));
        tb('Scenografia', 0.34, 0.15, @(~,~) openSettings(3, false));
        tb('Personaggi e costumi', 0.50, 0.22, @(~,~) openSettings(4, false));
        tb('Cartella canzoni', 0.73, 0.25, @(~,~) openFolder(fullfile(showDir, 'audio')));
        uicontrol(figShow, 'Style', 'text', 'String', 'SCENE  (doppio clic per aprire)', 'FontSize', 11, 'FontWeight', 'bold', ...
            'ForegroundColor', GOLD, 'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.765 0.6 0.035]);
        hShow.lb = uicontrol(figShow, 'Style', 'listbox', 'FontSize', 12, 'FontName', 'Courier New', 'BackgroundColor', PANEL, ...
            'ForegroundColor', TXT, 'Units', 'normalized', 'Position', [0.02 0.13 0.7 0.63], 'Callback', @showClick);
        sb = @(str, y, cb) uicontrol(figShow, 'Style', 'pushbutton', 'String', str, 'FontSize', 11, 'Units', 'normalized', ...
            'Position', [0.74 y 0.24 0.055], 'Callback', cb);
        h = sb('+ Nuova scena', 0.705, @(~,~) newSceneDlg()); set(h, 'FontWeight', 'bold');
        h = sb([char(9654) '  Apri la scena'], 0.64, @(~,~) openSceneSel()); set(h, 'FontWeight', 'bold');
        sb('Titolo, numero, atto', 0.575, @(~,~) editSceneDlg());
        sb('Imposta scena', 0.51, @(~,~) setupSel());
        sb('Duplica scena', 0.445, @(~,~) dupScene());
        sb('Elimina scena', 0.38, @(~,~) delScene());
        h = sb([char(9113) '  Stampa intero copione'], 0.29, @(~,~) printScript()); set(h, 'FontWeight', 'bold', ...
            'TooltipString', 'PDF con una pagina per scena: titolo, atto, numero e passi (senza immagini)');
        sb('Salva', 0.2, @(~,~) doSaveShow());
        sb([char(9664) '  I miei spettacoli'], 0.135, @(~,~) backHome());
        hShow.st = uicontrol(figShow, 'Style', 'text', 'String', '', 'FontSize', 10, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.02 0.96 0.09]);
        refreshShow();
    end

    function closeShow(~, ~)
        backHome();
    end

    function backHome()
        saveShow(); closeShowWindows();
        if isempty(figHome) || ~ishandle(figHome), openHome(); else, set(figHome, 'Visible', 'on'); figure(figHome); refreshHome(); end
    end

    function doSaveShow()
        saveShow(); showMsg(['Salvato  (' SH.modified ')']);
    end

    function showMsg(s)
        if ~isempty(figShow) && ishandle(figShow), set(hShow.st, 'String', s); end
    end

    function refreshShow()
        if isempty(figShow) || ~ishandle(figShow), return; end
        set(figShow, 'Name', ['Spettacolo  -  ' SH.title]); set(hShow.title, 'String', SH.title);
        T = SH.theater;
        set(hShow.info, 'String', sprintf('Palco %g x %g m, altezza %g m, %d quinte per lato   |   %d personaggi   |   %d elementi scenici   |   %d luci', ...
            T.W, T.D, T.H, T.nq, numel(SH.chars), numel(SH.elements), numel(SH.lights)));
        sortScenes();
        n = numel(SH.scenes); items = cell(max(n, 1), 1);
        for q = 1:n
            sc = SH.scenes{q};
            mf = findMusic(sc.num);
            if isempty(mf), mk = sprintf('(manca %02d.mp3)', sc.num); else, mk = char(9834); end
            items{q} = sprintf('Atto %-4s Scena %2d   %-36s %3d passi  %s', roman(sc.act), sc.num, sc.title, numel(sc.steps), mk);
        end
        if n == 0, items = {'(nessuna scena: premi "+ Nuova scena")'}; end
        v = get(hShow.lb, 'Value'); if isempty(v) || v > numel(items), v = numel(items); end
        set(hShow.lb, 'String', items, 'Value', max(1, v));
    end

    function sortScenes()
        n = numel(SH.scenes); if n < 2, return; end
        key = zeros(n, 3);
        for q = 1:n, key(q, :) = [SH.scenes{q}.act, SH.scenes{q}.num, q]; end
        [~, o] = sortrows(key);
        SH.scenes = SH.scenes(o);
    end

    function k = sceneSel()
        k = get(hShow.lb, 'Value'); if isempty(SH.scenes) || k > numel(SH.scenes), k = 0; end
    end

    function showClick(~, ~)
        if strcmp(get(figShow, 'SelectionType'), 'open'), openSceneSel(); end
    end

    function k = selectUid(uid)
        k = 0;
        for q = 1:numel(SH.scenes), if SH.scenes{q}.uid == uid, k = q; end, end
        if k > 0 && ~isempty(figShow) && ishandle(figShow), set(hShow.lb, 'Value', k); end
    end

    function newSceneDlg()
        act = 1; num = 1;
        if ~isempty(SH.scenes), act = SH.scenes{end}.act; num = SH.scenes{end}.num + 1; end
        a = inputdlg({'Atto (numero: 1, 2, ...)', 'Numero della scena (0 = intro/ouverture; corrisponde alla canzone "00", "01", ...)', ...
            'Titolo della scena', 'Situazione iniziale (facoltativa)'}, 'Nuova scena', [1 70; 1 70; 1 70; 2 70], {num2str(act), num2str(num), '', ''});
        if isempty(a), return; end
        sc = newScene(newUid(), str2double(a{1}), str2double(a{2}), strtrim(a{3}), strtrim(a{4}));
        SH.scenes{end+1} = sc; saveShow(); refreshShow(); k = selectUid(sc.uid);
        showMsg(sprintf('Scena creata. Ora scegli chi c''e'' in scena, i costumi e le posizioni iniziali.'));
        sceneSetup(k);
    end

    function editSceneDlg()
        k = sceneSel(); if k == 0, return; end
        sc = SH.scenes{k};
        a = inputdlg({'Atto', 'Numero della scena', 'Titolo', 'Situazione iniziale'}, 'Modifica scena', [1 70; 1 70; 1 70; 2 70], ...
            {num2str(sc.act), num2str(sc.num), sc.title, sc.start});
        if isempty(a), return; end
        sc.act = numOr(a{1}, sc.act); sc.num = numOr(a{2}, sc.num); sc.title = strtrim(a{3}); sc.start = strtrim(a{4});
        SH.scenes{k} = sc; saveShow(); refreshShow(); selectUid(sc.uid);
    end

    function openSceneSel()
        k = sceneSel(); if k == 0, return; end
        openScene(k);
    end

    function setupSel()
        k = sceneSel(); if k == 0, return; end
        sceneSetup(k);
    end

    function dupScene()
        k = sceneSel(); if k == 0, return; end
        sc = SH.scenes{k}; sc.uid = newUid(); sc.title = [sc.title ' (copia)'];
        SH.scenes{end+1} = sc; saveShow(); refreshShow(); selectUid(sc.uid);
    end

    function delScene()
        k = sceneSel(); if k == 0, return; end
        a = questdlg(sprintf('Eliminare la scena "%s" con tutti i suoi passi?', SH.scenes{k}.title), 'Elimina scena', 'Elimina', 'Annulla', 'Annulla');
        if ~strcmp(a, 'Elimina'), return; end
        if ~isempty(figScene) && ishandle(figScene), S.stop = true; stopMusic(); delete(figScene); figScene = []; end
        SH.scenes(k) = []; saveShow(); refreshShow();
    end

% =====================================================================
%            IMPOSTAZIONI: teatro, luci, scenografia, personaggi
% =====================================================================
    function openSettings(tab, wizard)
        if ~isempty(figSet) && ishandle(figSet), delete(figSet); end
        figSet = figure('Name', ['Impostazioni  -  ' SH.title], 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', 'ToolBar', 'figure', ...
            'Units', 'normalized', 'Position', [0.03 0.05 0.94 0.86], 'CloseRequestFcn', @closeSettings);
        tg = uitabgroup('Parent', figSet, 'Units', 'normalized', 'Position', [0 0.07 1 0.93]);
        tabs = {uitab(tg, 'Title', '  1. Teatro  '), uitab(tg, 'Title', '  2. Luci  '), uitab(tg, 'Title', '  3. Scenografia  '), ...
                uitab(tg, 'Title', '  4. Personaggi e costumi  ')};
        for q = 1:4, set(tabs{q}, 'BackgroundColor', BG); end
        buildTheaterTab(tabs{1}); buildLightsTab(tabs{2}); buildElementsTab(tabs{3}); buildCharsTab(tabs{4});
        set(tg, 'SelectedTab', tabs{tab});
        if wizard
            uicontrol(figSet, 'Style', 'text', 'String', 'Nuovo spettacolo: compila le 4 schede in ordine (puoi sempre tornarci dalla finestra dello spettacolo).', ...
                'FontSize', 10, 'ForegroundColor', [1 .85 .45], 'BackgroundColor', BG, 'HorizontalAlignment', 'left', ...
                'Units', 'normalized', 'Position', [0.01 0.015 0.5 0.04]);
            uicontrol(figSet, 'Style', 'pushbutton', 'String', [char(9664) ' Indietro'], 'FontSize', 11, 'Units', 'normalized', ...
                'Position', [0.52 0.012 0.1 0.05], 'Callback', @(~,~) moveTab(-1));
            uicontrol(figSet, 'Style', 'pushbutton', 'String', ['Avanti ' char(9654)], 'FontSize', 11, 'FontWeight', 'bold', 'Units', 'normalized', ...
                'Position', [0.63 0.012 0.1 0.05], 'Callback', @(~,~) moveTab(+1));
        end
        uicontrol(figSet, 'Style', 'pushbutton', 'String', 'Salva e chiudi', 'FontSize', 11, 'FontWeight', 'bold', 'Units', 'normalized', ...
            'Position', [0.85 0.012 0.14 0.05], 'Callback', @(~,~) closeSettings(figSet, []));
        function moveTab(d)
            cur = find(cellfun(@(t) isequal(t, get(tg, 'SelectedTab')), tabs));
            nx = cur + d;
            if nx > 4, closeSettings(figSet, []); return; end
            if nx >= 1, set(tg, 'SelectedTab', tabs{nx}); end
        end
    end

    function closeSettings(src, ~)
        saveShow(); S.cacheP = containers.Map(); S.cacheL = containers.Map();
        if ishandle(src), delete(src); end
        figSet = [];
        refreshShow();
        if ~isempty(figScene) && ishandle(figScene), goScene(S.idx); end
    end

% ------------------------------------------------------------------ teatro
    function buildTheaterTab(t)
        uicontrol(t, 'Style', 'text', 'String', 'Il teatro', 'FontSize', 16, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.92 0.4 0.05]);
        PRE = {'Personalizzato', 'Piccolo (8 x 7 m, h 5 m, 2 quinte)', 'Medio (10 x 9 m, h 7 m, 3 quinte)', 'Grande (14 x 11,5 m, h 9 m, 4 quinte)', ...
               'Molto grande (18 x 16 m, h 12 m, 5 quinte)'};
        PV = [0 0 0 0 0; 8 7 5 2 1; 10 9.2 7 3 1.2; 14 11.5 9 4 1.5; 18 16 12 5 2];
        lab = @(s, y) uicontrol(t, 'Style', 'text', 'String', s, 'FontSize', 11, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 y 0.2 0.04]);
        lab('Modello di partenza', 0.83);
        pp = uicontrol(t, 'Style', 'popupmenu', 'String', PRE, 'FontSize', 11, 'Units', 'normalized', 'Position', [0.22 0.835 0.2 0.04], ...
            'Callback', @preset);
        F = {'W', 'Larghezza del palco (m)'; 'Dtot', 'Profondita'' totale, proscenio compreso (m)'; 'H', 'Altezza (graticcio) (m)'; ...
             'nq', 'Numero di quinte per lato'; 'P', 'Profondita'' del proscenio (m)'};
        ed = gobjects(1, size(F, 1));
        for q = 1:size(F, 1)
            lab(F{q, 2}, 0.76 - (q - 1)*0.065);
            ed(q) = uicontrol(t, 'Style', 'edit', 'String', num2str(SH.theater.(F{q, 1})), 'FontSize', 11, 'Units', 'normalized', ...
                'Position', [0.22 0.765 - (q - 1)*0.065 0.08 0.045], 'Callback', @readT);
        end
        info = uicontrol(t, 'Style', 'text', 'String', '', 'FontSize', 10, 'ForegroundColor', [1 .85 .45], 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.37 0.41 0.06]);
        lab('Fondale', 0.30);
        BK = {'Nero', 'Ciclorama bianco', 'Grigio', 'Immagine (foto o disegno)', 'Modello 3D'};
        pb = uicontrol(t, 'Style', 'popupmenu', 'String', BK, 'Value', max(1, find(strcmp(BK, SH.theater.back), 1)), 'FontSize', 11, ...
            'Units', 'normalized', 'Position', [0.22 0.305 0.2 0.045], 'Callback', @pickBack);
        bF = uicontrol(t, 'Style', 'pushbutton', 'String', 'Scegli il file...', 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [0.22 0.25 0.2 0.045], 'Callback', @(~,~) chooseBack(true));
        tF = uicontrol(t, 'Style', 'text', 'String', '', 'FontSize', 9, 'ForegroundColor', DIM, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.2 0.41 0.04]);
        uicontrol(t, 'Style', 'text', 'String', {'Misure in metri. Le quinte si dividono da sole la profondita'' del palco (proscenio escluso):'; ...
            'scrivi solo quante sono. Immagine: jpg/png, viene stesa su tutta la larghezza. Modello 3D: .glb/.obj, adattato alla larghezza.'}, ...
            'FontSize', 9, 'ForegroundColor', DIM, 'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.06 0.41 0.1]);
        ax = axes('Parent', t, 'Units', 'normalized', 'Position', [0.45 0.05 0.53 0.88]);
        drawT();
        function preset(~, ~)
            v = get(pp, 'Value'); if v == 1, return; end
            for q2 = 1:size(F, 1), set(ed(q2), 'String', num2str(PV(v, q2))); end
            readT();
        end
        function readT(~, ~)
            for q2 = 1:size(F, 1)
                x = str2double(strrep(get(ed(q2), 'String'), ',', '.'));
                if ~isnan(x) && x >= 0, SH.theater.(F{q2, 1}) = x; end
            end
            SH.theater = fixTheater(SH.theater);
            for q2 = 1:size(F, 1), set(ed(q2), 'String', num2str(SH.theater.(F{q2, 1}))); end
            drawT();
        end
        function pickBack(~, ~)
            nb = BK{get(pb, 'Value')};
            if strcmp(nb, 'Immagine (foto o disegno)') && isempty(SH.theater.backImg) || strcmp(nb, 'Modello 3D') && isempty(SH.theater.backModel)
                SH.theater.back = nb;
                if ~chooseBack(false), SH.theater.back = 'Nero'; set(pb, 'Value', 1); end
            else
                SH.theater.back = nb;
            end
            drawT();
        end
        function ok = chooseBack(redraw)
            ok = false;
            switch SH.theater.back
                case 'Immagine (foto o disegno)'
                    [f, p] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif', 'Immagini'}, 'Immagine del fondale');
                    if isequal(f, 0), return; end
                    dd = fullfile(showDir, 'fondale'); if ~exist(dd, 'dir'), mkdir(dd); end
                    copyfile(fullfile(p, f), fullfile(dd, f)); SH.theater.backImg = f; ok = true;
                case 'Modello 3D'
                    fn = importModelDlg('el'); if isempty(fn), return; end
                    SH.theater.backModel = fn; ok = true;
                otherwise
                    msgbox('Scegli prima "Immagine" o "Modello 3D" come fondale.', 'Fondale'); return
            end
            S.cacheL = containers.Map();
            if redraw, drawT(); end
        end
        function drawT()
            T = SH.theater;
            set(info, 'String', sprintf(['Calcolato: palco %.2f m di profondita'' + %.2f m di proscenio.\n' ...
                '%d quinte per lato, una ogni %.2f m, larghe %.2f m; spazio dietro le quinte %.2f m.'], T.D, T.P, T.nq, quinteStep(T), quinteWidth(T), T.wing));
            isF = any(strcmp(T.back, {'Immagine (foto o disegno)', 'Modello 3D'}));
            set(bF, 'Enable', onoff(isF));
            switch T.back
                case 'Immagine (foto o disegno)', set(tF, 'String', ['Immagine: ' T.backImg]);
                case 'Modello 3D', set(tF, 'String', ['Modello: ' T.backModel]);
                otherwise, set(tF, 'String', '');
            end
            cla(ax); stagePlan(ax, true); title(ax, 'Pianta (pubblico in basso)', 'Color', GOLD);
        end
    end

    function stagePlan(ax, labels)
        % pianta del palco + anteprima dell'immagine del fondale
        T = SH.theater;
        drawStagePlan(ax, T, labels);
        if strcmp(T.back, 'Immagine (foto o disegno)') && ~isempty(T.backImg)
            try
                im = backImage();
                hold(ax, 'on');
                xa = -T.W/2 - T.wing; xb = T.W/2 + T.wing;
                image('Parent', ax, 'XData', [xa xb], 'YData', [T.D + 0.55, T.D + 0.06], 'CData', im, 'HitTest', 'off');
                hold(ax, 'off');
                set(ax, 'YLim', [-T.P - 1.0, T.D + 0.7]);
            catch
            end
        end
    end

    function im = backImage()
        key = ['img|' SH.theater.backImg];
        if isKey(S.cacheL, key), im = S.cacheL(key); return; end
        im = imread(fullfile(showDir, 'fondale', SH.theater.backImg));
        if size(im, 3) == 1, im = repmat(im, [1 1 3]); end
        if size(im, 3) > 3, im = im(:, :, 1:3); end
        k = max(1, ceil(max(size(im, 1), size(im, 2)) / 1200)); im = im(1:k:end, 1:k:end, :);
        S.cacheL(key) = im;
    end

    function P = backModelParts()
        % modello del fondale adattato alla larghezza della scena, appoggiato al fondo
        P = []; T = SH.theater;
        key = sprintf('back|%s|%g|%g', T.backModel, T.W, T.D);
        if isKey(S.cacheL, key), P = S.cacheL(key); return; end
        R = loadPartsFile(fullfile(showDir, 'modelli', T.backModel)); if isempty(R), return; end
        P = prepParts(R, []);
        V = vertcat(P.V); mn = min(V, [], 1); mx = max(V, [], 1);
        k = (T.W + 2*T.wing) / max(mx(1) - mn(1), 1e-3);
        for q = 1:numel(P)
            v = P(q).V; v(:, 1) = (v(:, 1) - (mn(1) + mx(1))/2) * k; v(:, 2) = (v(:, 2) - mx(2)) * k + T.D; v(:, 3) = (v(:, 3) - mn(3)) * k;
            P(q).V = v;
        end
        S.cacheL(key) = P;
    end

% ------------------------------------------------------------------ luci
    function buildLightsTab(t)
        uicontrol(t, 'Style', 'text', 'String', 'Luci disponibili', 'FontSize', 16, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.92 0.4 0.05]);
        uicontrol(t, 'Style', 'text', 'String', 'Libreria (doppio clic o "Aggiungi")', 'FontSize', 10, 'ForegroundColor', DIM, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.87 0.3 0.035]);
        items = arrayfun(@(x) sprintf('%s  -  %s', x.type, x.note), LT, 'UniformOutput', false);
        lbL = uicontrol(t, 'Style', 'listbox', 'String', items, 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [0.02 0.12 0.33 0.75], 'Callback', @libClick);
        uicontrol(t, 'Style', 'pushbutton', 'String', ['Aggiungi ' char(9654)], 'FontSize', 11, 'FontWeight', 'bold', 'Units', 'normalized', ...
            'Position', [0.36 0.5 0.08 0.06], 'Callback', @(~,~) addLight());
        uicontrol(t, 'Style', 'text', 'String', 'Luci di questo spettacolo (modifica nome, quantita'', colore e zona nella tabella)', 'FontSize', 10, ...
            'ForegroundColor', DIM, 'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.45 0.87 0.53 0.035]);
        tbl = uitable(t, 'Units', 'normalized', 'Position', [0.45 0.2 0.53 0.67], 'ColumnName', {'Nome', 'Tipo', 'Q.ta''', 'Colore', 'Zona'}, ...
            'ColumnFormat', {'char', 'char', 'numeric', COLN, ZONES}, 'ColumnEditable', [true false true true true], ...
            'ColumnWidth', {170, 170, 50, 110, 150}, 'RowName', [], 'FontSize', 10, 'CellEditCallback', @cellEd, 'CellSelectionCallback', @cellSel);
        sel = 0;
        uicontrol(t, 'Style', 'pushbutton', 'String', 'Rimuovi la luce selezionata', 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [0.45 0.12 0.2 0.055], 'Callback', @(~,~) remLight());
        uicontrol(t, 'Style', 'pushbutton', 'String', 'Colore personalizzato...', 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [0.66 0.12 0.16 0.055], 'Callback', @(~,~) customCol());
        uicontrol(t, 'Style', 'text', 'String', {'"Segue un personaggio" = occhio di bue / testa mobile: nei passi puoi farlo seguire un personaggio.'; ...
            'Le altre zone sono luci generali: nei passi scegli quali restano accese.'}, 'FontSize', 9, 'ForegroundColor', DIM, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.45 0.02 0.53 0.08]);
        fill();
        function fill()
            n = numel(SH.lights); C = cell(n, 5);
            for q = 1:n
                L = SH.lights(q); C(q, :) = {L.name, L.type, L.qty, L.cname, L.zone};
            end
            set(tbl, 'Data', C);
        end
        function libClick(~, ~)
            if strcmp(get(figSet, 'SelectionType'), 'open'), addLight(); end
        end
        function addLight()
            v = get(lbL, 'Value'); L = LT(v);
            ci = find(strcmp(COLN, L.col), 1); if isempty(ci), ci = 1; end
            nm = L.type; k = 2;
            while any(strcmp({SH.lights.name}, nm)), nm = sprintf('%s %d', L.type, k); k = k + 1; end
            SH.lights(end+1) = newLight(nm, L.type, L.qty, COLN{ci}, COLV(ci, :), L.zone);
            fill();
        end
        function cellEd(~, ev)
            r = ev.Indices(1); c = ev.Indices(2); if r > numel(SH.lights), return; end
            switch c
                case 1
                    nm = strtrim(ev.NewData);
                    if isempty(nm) || any(strcmp({SH.lights([1:r-1, r+1:end]).name}, nm)), fill(); return; end
                    SH.lights(r).name = nm;
                case 3, SH.lights(r).qty = max(0, round(double(ev.NewData)));
                case 4
                    ci = find(strcmp(COLN, ev.NewData), 1);
                    if strcmp(ev.NewData, 'Personalizzato')
                        cc = uisetcolor(SH.lights(r).rgb, 'Colore della luce');
                        if numel(cc) == 3, SH.lights(r).rgb = cc; end
                    elseif ~isempty(ci)
                        SH.lights(r).rgb = COLV(ci, :);
                    end
                    SH.lights(r).cname = ev.NewData;
                case 5, SH.lights(r).zone = ev.NewData;
            end
            fill();
        end
        function cellSel(~, ev)
            if ~isempty(ev.Indices), sel = ev.Indices(1, 1); end
        end
        function remLight()
            if sel < 1 || sel > numel(SH.lights), return; end
            SH.lights(sel) = []; sel = 0; fill();
        end
        function customCol()
            if sel < 1 || sel > numel(SH.lights), return; end
            cc = uisetcolor(SH.lights(sel).rgb, 'Colore della luce');
            if numel(cc) == 3, SH.lights(sel).rgb = cc; SH.lights(sel).cname = 'Personalizzato'; end
            fill();
        end
    end

% ------------------------------------------------------------------ scenografia
    function buildElementsTab(t)
        uicontrol(t, 'Style', 'text', 'String', 'Scenografia', 'FontSize', 16, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.92 0.4 0.05]);
        libE = CAT(strcmp({CAT.cat}, 'Scenografia'));
        uicontrol(t, 'Style', 'text', 'String', 'Elementi predefiniti (doppio clic per aggiungere)', 'FontSize', 10, 'ForegroundColor', DIM, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.01 0.87 0.22 0.035]);
        lbC = uicontrol(t, 'Style', 'listbox', 'String', {libE.name}, 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [0.01 0.25 0.2 0.62], 'Callback', @catClick);
        uicontrol(t, 'Style', 'pushbutton', 'String', ['Aggiungi ' char(9654)], 'FontSize', 10, 'FontWeight', 'bold', 'Units', 'normalized', ...
            'Position', [0.01 0.18 0.2 0.055], 'Callback', @(~,~) addLib());
        uicontrol(t, 'Style', 'pushbutton', 'String', 'Importa modello 3D (.glb, .obj)...', 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [0.01 0.11 0.2 0.055], 'Callback', @(~,~) addImport());
        uicontrol(t, 'Style', 'text', 'String', 'Elementi di questo spettacolo', 'FontSize', 10, 'ForegroundColor', DIM, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.23 0.87 0.2 0.035]);
        lbE = uicontrol(t, 'Style', 'listbox', 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [0.23 0.25 0.18 0.62], 'Callback', @(~,~) showEl());
        uicontrol(t, 'Style', 'pushbutton', 'String', 'Duplica', 'FontSize', 10, 'Units', 'normalized', 'Position', [0.23 0.18 0.085 0.055], ...
            'Callback', @(~,~) dupEl());
        uicontrol(t, 'Style', 'pushbutton', 'String', 'Elimina', 'FontSize', 10, 'Units', 'normalized', 'Position', [0.325 0.18 0.085 0.055], ...
            'Callback', @(~,~) delEl());
        x0 = 0.43; lab = @(s, y, w) uicontrol(t, 'Style', 'text', 'String', s, 'FontSize', 10, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 y w 0.035]);
        lab('Nome', 0.86, 0.06);
        eN = uicontrol(t, 'Style', 'edit', 'FontSize', 11, 'Units', 'normalized', 'Position', [x0 + 0.06 0.865 0.18 0.04], 'Callback', @readEl);
        lab('Larghezza, profondita'', altezza (m)', 0.8, 0.2);
        eS = gobjects(1, 3);
        for q = 1:3
            eS(q) = uicontrol(t, 'Style', 'edit', 'FontSize', 11, 'Units', 'normalized', 'Position', [x0 + (q - 1)*0.065 0.76 0.06 0.04], 'Callback', @readEl);
        end
        bC = uicontrol(t, 'Style', 'pushbutton', 'String', 'Colore', 'FontSize', 10, 'Units', 'normalized', 'Position', [x0 + 0.2 0.76 0.04 0.04], ...
            'Callback', @pickCol);
        cF = uicontrol(t, 'Style', 'checkbox', 'String', 'Fisso: presente in tutte le scene, sempre nello stesso punto', 'FontSize', 10, ...
            'ForegroundColor', TXT, 'BackgroundColor', BG, 'Units', 'normalized', 'Position', [x0 0.705 0.24 0.04], 'Callback', @readEl);
        lab('Posizione X, Y (m) e rotazione (gradi)', 0.66, 0.24);
        eP = gobjects(1, 3);
        for q = 1:3
            eP(q) = uicontrol(t, 'Style', 'edit', 'FontSize', 11, 'Units', 'normalized', 'Position', [x0 + (q - 1)*0.065 0.62 0.06 0.04], 'Callback', @readEl);
        end
        uicontrol(t, 'Style', 'text', 'String', 'X = 0 al centro, Y = 0 sul bordo del palco (proscenio escluso), Y cresce verso il fondale.', ...
            'FontSize', 8, 'ForegroundColor', DIM, 'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 0.585 0.24 0.03]);
        lab('Occorrente', 0.54, 0.2);
        eO = uicontrol(t, 'Style', 'edit', 'Max', 10, 'Min', 0, 'FontSize', 10, 'HorizontalAlignment', 'left', 'Units', 'normalized', ...
            'Position', [x0 0.39 0.24 0.15], 'Callback', @readEl);
        lab('Come costruirlo', 0.35, 0.2);
        eH = uicontrol(t, 'Style', 'edit', 'Max', 10, 'Min', 0, 'FontSize', 10, 'HorizontalAlignment', 'left', 'Units', 'normalized', ...
            'Position', [x0 0.12 0.24 0.23], 'Callback', @readEl);
        ax = axes('Parent', t, 'Units', 'normalized', 'Position', [0.69 0.1 0.3 0.8], 'Color', BG);
        fillE(); showEl();
        function fillE()
            n = numel(SH.elements); it = cell(max(n, 1), 1);
            for q2 = 1:n
                e = SH.elements(q2); fx = ''; if e.fixed, fx = '  [fisso]'; end
                it{q2} = [e.name fx];
            end
            if n == 0, it = {'(nessun elemento)'}; end
            v = get(lbE, 'Value'); if isempty(v) || v > numel(it), v = numel(it); end
            set(lbE, 'String', it, 'Value', max(1, v));
        end
        function i = cur()
            i = get(lbE, 'Value'); if isempty(SH.elements) || i > numel(SH.elements), i = 0; end
        end
        function catClick(~, ~)
            if strcmp(get(figSet, 'SelectionType'), 'open'), addLib(); end
        end
        function addLib()
            c = libE(get(lbC, 'Value'));
            e = newElement(uniqueElName(c.name), 'lib', c.id, c.size, c.rgb, ~isempty(c.hex));
            SH.elements(end+1) = e; fillE(); set(lbE, 'Value', numel(SH.elements)); showEl();
        end
        function addImport()
            [fn, bb, nm] = importModelDlg('el'); if isempty(fn), return; end
            e = newElement(uniqueElName(nm), 'import', fn, bb, [0.6 0.5 0.4], false);
            SH.elements(end+1) = e; fillE(); set(lbE, 'Value', numel(SH.elements)); showEl();
        end
        function dupEl()
            i = cur(); if i == 0, return; end
            e = SH.elements(i); e.name = uniqueElName(e.name); SH.elements(end+1) = e; fillE(); set(lbE, 'Value', numel(SH.elements)); showEl();
        end
        function delEl()
            i = cur(); if i == 0, return; end
            nm = SH.elements(i).name;
            if usedInScenes('el', nm)
                a = questdlg(sprintf('"%s" e'' usato in alcune scene: eliminandolo sparisce anche da li''. Continuare?', nm), 'Elimina', 'Elimina', 'Annulla', 'Annulla');
                if ~strcmp(a, 'Elimina'), return; end
                removeFromScenes('el', nm);
            end
            SH.elements(i) = []; fillE(); showEl();
        end
        function showEl()
            i = cur(); on = onoff(i > 0);
            set([eN eS eP bC cF eO eH], 'Enable', on);
            cla(ax); if i == 0, return; end
            e = SH.elements(i);
            set(eN, 'String', e.name); for q2 = 1:3, set(eS(q2), 'String', sprintf('%.2f', e.size(q2))); end
            set(cF, 'Value', e.fixed); set(eP(1), 'String', sprintf('%.2f', e.x)); set(eP(2), 'String', sprintf('%.2f', e.y)); set(eP(3), 'String', num2str(e.rot));
            set(eP, 'Enable', onoff(e.fixed));
            set(bC, 'BackgroundColor', e.rgb, 'Enable', onoff(e.tint));
            set(eO, 'String', e.occ); set(eH, 'String', e.how);
            P = elementParts(e);
            if ~isempty(P)
                drawParts(ax, P, eye(4)); axis(ax, 'equal'); axis(ax, 'off'); view(ax, [-30 18]);
                camlight(ax, 'headlight'); lighting(ax, 'gouraud'); rotate3d(ax, 'on');
            end
        end
        function readEl(~, ~)
            i = cur(); if i == 0, return; end
            e = SH.elements(i); old = e.name;
            nm = strtrim(get(eN, 'String'));
            if ~isempty(nm) && ~strcmp(nm, old) && ~any(strcmp({SH.elements.name}, nm)), e.name = nm; renameInScenes('el', old, nm); end
            for q2 = 1:3
                v = str2double(strrep(get(eS(q2), 'String'), ',', '.')); if ~isnan(v) && v > 0, e.size(q2) = v; end
            end
            e.fixed = get(cF, 'Value') == 1;
            pv = [str2double(strrep(get(eP(1), 'String'), ',', '.')), str2double(strrep(get(eP(2), 'String'), ',', '.')), ...
                  str2double(strrep(get(eP(3), 'String'), ',', '.'))];
            if ~isnan(pv(1)), e.x = pv(1); end; if ~isnan(pv(2)), e.y = pv(2); end; if ~isnan(pv(3)), e.rot = pv(3); end
            if e.fixed && e.y == 0 && e.x == 0, e.y = SH.theater.D - e.size(2)/2 - 0.1; end
            e.occ = joinLines(get(eO, 'String')); e.how = joinLines(get(eH, 'String'));
            SH.elements(i) = e; S.cacheL = containers.Map(); fillE(); showEl();
        end
        function pickCol(~, ~)
            i = cur(); if i == 0, return; end
            cc = uisetcolor(SH.elements(i).rgb, 'Colore'); if numel(cc) ~= 3, return; end
            SH.elements(i).rgb = cc; S.cacheL = containers.Map(); showEl();
        end
    end

    function nm = uniqueElName(base)
        nm = base; k = 2;
        while ~isempty(SH.elements) && any(strcmp({SH.elements.name}, nm)), nm = sprintf('%s %d', base, k); k = k + 1; end
    end

    function u = usedInScenes(kind, nm)
        u = false;
        for q = 1:numel(SH.scenes)
            ob = SH.scenes{q}.objects;
            if ~isempty(ob) && any(strcmp({ob.kind}, kind) & strcmp({ob.ref}, nm)), u = true; return; end
        end
    end

    function removeFromScenes(kind, nm)
        for q = 1:numel(SH.scenes)
            sc = SH.scenes{q}; ob = sc.objects; if isempty(ob), continue; end
            rm = strcmp({ob.kind}, kind) & strcmp({ob.ref}, nm);
            if ~any(rm), continue; end
            ids = [ob(rm).id];
            if strcmp(kind, 'char'), rm = rm | (strcmp({ob.kind}, 'light') & ~cellfun(@isempty, regexp({ob.label}, [' su ' regexptranslate('escape', nm) '$'], 'once'))); ids = [ob(rm).id]; end
            sc.objects = ob(~rm);
            for k = 1:numel(sc.steps)
                e = sc.steps{k}; if isempty(e), continue; end
                sc.steps{k} = e(~ismember([e.spid], ids));
            end
            if strcmp(kind, 'char') && ~isempty(sc.cast), sc.cast = sc.cast(~strcmp({sc.cast.name}, nm)); end
            SH.scenes{q} = sc;
        end
    end

    function renameInScenes(kind, old, nw)
        for q = 1:numel(SH.scenes)
            sc = SH.scenes{q};
            for j = 1:numel(sc.objects)
                if strcmp(sc.objects(j).kind, kind) && strcmp(sc.objects(j).ref, old)
                    sc.objects(j).ref = nw; sc.objects(j).label = nw;
                end
                if strcmp(kind, 'char') && strcmp(sc.objects(j).kind, 'light')
                    sc.objects(j).label = regexprep(sc.objects(j).label, [' su ' regexptranslate('escape', old) '$'], [' su ' nw]);
                end
            end
            if strcmp(kind, 'char')
                for j = 1:numel(sc.cast), if strcmp(sc.cast(j).name, old), sc.cast(j).name = nw; end, end
            end
            SH.scenes{q} = sc;
        end
    end

% ------------------------------------------------------------------ personaggi e costumi
    function buildCharsTab(t)
        uicontrol(t, 'Style', 'text', 'String', 'Personaggi', 'FontSize', 16, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.01 0.93 0.2 0.05]);
        lbP = uicontrol(t, 'Style', 'listbox', 'FontSize', 11, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [0.01 0.2 0.15 0.72], 'Callback', @(~,~) showChar());
        pbtn = @(s, x, y, w, cb) uicontrol(t, 'Style', 'pushbutton', 'String', s, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x y w 0.05], 'Callback', cb);
        h = pbtn('+ Nuovo personaggio', 0.01, 0.14, 0.15, @(~,~) addChar()); set(h, 'FontWeight', 'bold');
        pbtn('Duplica', 0.01, 0.085, 0.073, @(~,~) dupChar());
        pbtn('Elimina', 0.087, 0.085, 0.073, @(~,~) delChar());
        % ---- dati del personaggio
        x0 = 0.18;
        lab = @(s, x, y, w) uicontrol(t, 'Style', 'text', 'String', s, 'FontSize', 10, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x y w 0.032]);
        lab('Nome', x0, 0.935, 0.04);
        eNm = uicontrol(t, 'Style', 'edit', 'FontSize', 11, 'Units', 'normalized', 'Position', [x0 + 0.04 0.94 0.13 0.035], 'Callback', @readChar);
        lab('Pedina', x0 + 0.18, 0.935, 0.04);
        bPw = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x0 + 0.22 0.94 0.03 0.035], 'Callback', @pickPawn);
        lab('Corpo', x0 + 0.27, 0.935, 0.04);
        pSx = uicontrol(t, 'Style', 'popupmenu', 'String', {'Uomo', 'Donna'}, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x0 + 0.31 0.94 0.07 0.035], 'Callback', @readChar);
        lab('Altezza (m)', x0 + 0.39, 0.935, 0.06);
        eHt = uicontrol(t, 'Style', 'edit', 'FontSize', 11, 'Units', 'normalized', 'Position', [x0 + 0.45 0.94 0.04 0.035], 'Callback', @readChar);
        lab('Pelle', x0, 0.89, 0.04);
        pSk = uicontrol(t, 'Style', 'popupmenu', 'String', [SKINS(:, 1); {'Personalizzata...'}], 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x0 + 0.04 0.895 0.1 0.035], 'Callback', @readSkin);
        bSk = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x0 + 0.145 0.895 0.025 0.035], 'Enable', 'inactive');
        lab('Occhi', x0 + 0.18, 0.89, 0.04);
        pEy = uicontrol(t, 'Style', 'popupmenu', 'String', EYES(:, 1), 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x0 + 0.22 0.895 0.08 0.035], 'Callback', @readChar);
        % ---- costumi
        uicontrol(t, 'Style', 'text', 'String', 'COSTUMI', 'FontSize', 11, 'FontWeight', 'bold', 'ForegroundColor', GOLD, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 0.845 0.1 0.032]);
        lbC = uicontrol(t, 'Style', 'listbox', 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [x0 0.7 0.22 0.145], 'Callback', @(~,~) showCostume());
        cb = @(s, y, cbk) uicontrol(t, 'Style', 'pushbutton', 'String', s, 'FontSize', 9, 'Units', 'normalized', ...
            'Position', [x0 + 0.225 y 0.08 0.033], 'Callback', cbk);
        cb('+ Costume', 0.812, @(~,~) addCostume()); cb('Duplica', 0.776, @(~,~) dupCostume());
        cb('Descrizione', 0.74, @(~,~) descCostume()); cb('Elimina', 0.704, @(~,~) delCostume());
        lab('Il costume viene', x0 + 0.315, 0.81, 0.08);
        pMd = uicontrol(t, 'Style', 'popupmenu', 'String', {'dalla libreria', 'da un modello importato'}, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x0 + 0.315 0.775 0.17 0.035], 'Callback', @readMode);
        bIm = uicontrol(t, 'Style', 'pushbutton', 'String', 'Importa modello 3D (.glb, .obj)...', 'FontSize', 9, 'Units', 'normalized', ...
            'Position', [x0 + 0.315 0.735 0.17 0.035], 'Callback', @importCostume);
        tIm = uicontrol(t, 'Style', 'text', 'String', '', 'FontSize', 8, 'ForegroundColor', DIM, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 + 0.315 0.7 0.17 0.032]);
        % ---- capi (colonna sinistra) e trucco/parrucco (colonna destra)
        uicontrol(t, 'Style', 'text', 'String', 'CAPI  (colore con il quadratino)', 'FontSize', 10, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 0.655 0.23 0.03]);
        pIt = gobjects(1, NSLOT); bIt = gobjects(1, NSLOT); itemIds = cell(1, NSLOT);
        for q = 1:NSLOT
            y = 0.615 - (q - 1)*0.055;
            lab(SLOTLBL{q}, x0, y, 0.08);
            cc = CAT(strcmp({CAT.cat}, SLOTS{q}));
            itemIds{q} = [{''}, {cc.id}];
            pIt(q) = uicontrol(t, 'Style', 'popupmenu', 'String', [{['(' char(8212) ' nessuno)']}, {cc.name}], 'FontSize', 10, 'Units', 'normalized', ...
                'Position', [x0 + 0.08 y + 0.004 0.12 0.032], 'Callback', @readCostume, 'UserData', q);
            bIt(q) = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x0 + 0.205 y + 0.004 0.022 0.032], ...
                'Callback', @pickItemCol, 'UserData', q);
        end
        x1 = x0 + 0.25;
        uicontrol(t, 'Style', 'text', 'String', 'TRUCCO E PARRUCCO', 'FontSize', 10, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x1 0.655 0.23 0.03]);
        hc = CAT(strcmp({CAT.cat}, 'Capelli')); hairIds = [{''}, {hc.id}];
        bc = CAT(strcmp({CAT.cat}, 'Barba')); facIds = [{''}, {bc.id}];
        lab('Capelli', x1, 0.615, 0.06);
        pHr = uicontrol(t, 'Style', 'popupmenu', 'String', [{'Calvo / rasato'}, {hc.name}], 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x1 + 0.06 0.619 0.13 0.032], 'Callback', @readCostume);
        bHr = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x1 + 0.195 0.619 0.022 0.032], 'Callback', @(~,~) pickMk('hair'));
        lab('Barba / baffi', x1, 0.56, 0.06);
        pFc = uicontrol(t, 'Style', 'popupmenu', 'String', [{'Nessuna'}, {bc.name}], 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x1 + 0.06 0.564 0.13 0.032], 'Callback', @readCostume);
        bFc = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x1 + 0.195 0.564 0.022 0.032], 'Callback', @(~,~) pickMk('facial'));
        lab('Sopracciglia', x1, 0.505, 0.06);
        pBr = uicontrol(t, 'Style', 'popupmenu', 'String', BROWS, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x1 + 0.06 0.509 0.13 0.032], 'Callback', @readCostume);
        bBr = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x1 + 0.195 0.509 0.022 0.032], 'Callback', @(~,~) pickMk('brows'));
        MK = {'lips', 'Rossetto'; 'lashes', 'Rimmel / eyeliner'; 'shadow', 'Ombretto'; 'blush', 'Fard'};
        cMk = gobjects(1, 4); bMk = gobjects(1, 4);
        for q = 1:4
            y = 0.45 - (q - 1)*0.055;
            cMk(q) = uicontrol(t, 'Style', 'checkbox', 'String', MK{q, 2}, 'FontSize', 10, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
                'Units', 'normalized', 'Position', [x1 y 0.15 0.032], 'Callback', @readCostume);
            bMk(q) = uicontrol(t, 'Style', 'pushbutton', 'String', '', 'Units', 'normalized', 'Position', [x1 + 0.195 y 0.022 0.032], ...
                'Callback', @(src, ~) pickMk(MK{get(src, 'UserData'), 1}), 'UserData', q);
        end
        uicontrol(t, 'Style', 'text', 'String', {'Un "Abito intero" sostituisce maglia e pantaloni.'; 'I colori si scelgono con i quadratini.'; ...
            'Anteprima: trascina per ruotare.'}, 'FontSize', 8, 'ForegroundColor', DIM, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x1 0.06 0.22 0.08]);
        ax = axes('Parent', t, 'Units', 'normalized', 'Position', [0.68 0.03 0.31 0.93], 'Color', BG);
        ctrls = [eNm bPw pSx eHt pSk pEy lbC pMd bIm pIt bIt pHr bHr pFc bFc pBr bBr cMk bMk];
        fillP(); showChar();

        function fillP()
            n = numel(SH.chars); it = cell(max(n, 1), 1);
            for q2 = 1:n, it{q2} = SH.chars(q2).name; end
            if n == 0, it = {'(nessun personaggio)'}; end
            v = get(lbP, 'Value'); if isempty(v) || v > numel(it), v = numel(it); end
            set(lbP, 'String', it, 'Value', max(1, v));
        end
        function i = curP()
            i = get(lbP, 'Value'); if isempty(SH.chars) || i > numel(SH.chars), i = 0; end
        end
        function j = curC()
            j = 0; i = curP(); if i == 0, return; end
            j = get(lbC, 'Value'); if j > numel(SH.chars(i).costumes), j = numel(SH.chars(i).costumes); end
        end
        function addChar()
            a = inputdlg({'Nome del personaggio', 'Corpo (U = uomo, D = donna)'}, 'Nuovo personaggio', [1 40; 1 40], {'', 'U'});
            if isempty(a) || isempty(strtrim(a{1})), return; end
            nm = strtrim(a{1});
            if ~isempty(SH.chars) && any(strcmp({SH.chars.name}, nm)), errordlg('Esiste gia'' un personaggio con questo nome.', 'Personaggi'); return; end
            sx = 'M'; if ~isempty(a{2}) && upper(a{2}(1)) == 'D', sx = 'F'; end
            SH.chars(end+1) = newChar(nm, sx, numel(SH.chars) + 1);
            fillP(); set(lbP, 'Value', numel(SH.chars)); showChar();
        end
        function dupChar()
            i = curP(); if i == 0, return; end
            c = SH.chars(i); c.name = [c.name ' 2']; c.rev = c.rev + 1;
            while any(strcmp({SH.chars.name}, c.name)), c.name = [c.name '+']; end
            SH.chars(end+1) = c; fillP(); set(lbP, 'Value', numel(SH.chars)); showChar();
        end
        function delChar()
            i = curP(); if i == 0, return; end
            nm = SH.chars(i).name;
            a = questdlg(sprintf('Eliminare "%s"? Sparira'' anche da tutte le scene.', nm), 'Elimina', 'Elimina', 'Annulla', 'Annulla');
            if ~strcmp(a, 'Elimina'), return; end
            removeFromScenes('char', nm); SH.chars(i) = []; fillP(); showChar();
        end
        function showChar()
            i = curP();
            set(ctrls, 'Enable', onoff(i > 0)); set(bSk, 'Enable', 'inactive');
            if i == 0, cla(ax); set(lbC, 'String', {''}); return; end
            c = SH.chars(i);
            set(eNm, 'String', c.name); set(bPw, 'BackgroundColor', c.pawn);
            set(pSx, 'Value', 1 + strcmp(c.sex, 'F')); set(eHt, 'String', sprintf('%.2f', c.height));
            k = nearestRow(cell2mat(SKINS(:, 2)), c.skin); if norm(SKINS{k, 2} - c.skin) > 0.02, k = size(SKINS, 1) + 1; end
            set(pSk, 'Value', k); set(bSk, 'BackgroundColor', c.skin);
            set(pEy, 'Value', nearestRow(cell2mat(EYES(:, 2)), c.eyes));
            it = arrayfun(@(x) sprintf('%s  -  %s', x.code, x.desc), c.costumes, 'UniformOutput', false);
            v = get(lbC, 'Value'); if isempty(v) || v > numel(it), v = 1; end
            set(lbC, 'String', it, 'Value', v);
            showCostume();
        end
        function showCostume()
            i = curP(); j = curC(); if i == 0 || j == 0, return; end
            co = SH.chars(i).costumes(j);
            lib = strcmp(co.mode, 'lib');
            set(pMd, 'Value', 1 + ~lib); set(bIm, 'Enable', onoff(~lib));
            if lib, set(tIm, 'String', ''); else, set(tIm, 'String', ['File: ' co.file]); end
            set([pIt bIt pHr bHr pFc bFc pBr bBr cMk bMk], 'Enable', onoff(lib));
            for q2 = 1:NSLOT
                k = find(strcmp(itemIds{q2}, co.items{q2}), 1); if isempty(k), k = 1; end
                set(pIt(q2), 'Value', k); set(bIt(q2), 'BackgroundColor', co.irgb(q2, :));
            end
            k = find(strcmp(hairIds, co.hair), 1); if isempty(k), k = 1; end; set(pHr, 'Value', k); set(bHr, 'BackgroundColor', co.hairRGB);
            k = find(strcmp(facIds, co.facial), 1); if isempty(k), k = 1; end; set(pFc, 'Value', k); set(bFc, 'BackgroundColor', co.facialRGB);
            k = find(strcmp(BROWS, co.mk.brows), 1); if isempty(k), k = 2; end; set(pBr, 'Value', k); set(bBr, 'BackgroundColor', co.mk.browsRGB);
            for q2 = 1:4
                set(cMk(q2), 'Value', co.mk.(MK{q2, 1})); set(bMk(q2), 'BackgroundColor', co.mk.([MK{q2, 1} 'RGB']));
            end
            preview();
        end
        function preview()
            i = curP(); j = curC(); cla(ax); if i == 0 || j == 0, return; end
            P = charParts(i, SH.chars(i).costumes(j).code);
            if isempty(P), return; end
            drawParts(ax, P, eye(4));
            axis(ax, 'equal'); axis(ax, 'off'); set(ax, 'Color', BG);
            view(ax, [-20 6]); camlight(ax, 'headlight'); lighting(ax, 'gouraud'); rotate3d(ax, 'on');
        end
        function readChar(~, ~)
            i = curP(); if i == 0, return; end
            c = SH.chars(i); old = c.name;
            nm = strtrim(get(eNm, 'String'));
            if ~isempty(nm) && ~strcmp(nm, old) && ~any(strcmp({SH.chars.name}, nm)), c.name = nm; renameInScenes('char', old, nm); end
            sx = {'M', 'F'}; c.sex = sx{get(pSx, 'Value')};
            h = str2double(strrep(get(eHt, 'String'), ',', '.')); if ~isnan(h) && h > 0.5 && h < 2.6, c.height = h; end
            c.eyes = EYES{get(pEy, 'Value'), 2};
            c.rev = c.rev + 1; SH.chars(i) = c; fillP(); showChar();
        end
        function readSkin(~, ~)
            i = curP(); if i == 0, return; end
            k = get(pSk, 'Value');
            if k > size(SKINS, 1)
                cc = uisetcolor(SH.chars(i).skin, 'Colore della pelle'); if numel(cc) ~= 3, showChar(); return; end
                SH.chars(i).skin = cc;
            else
                SH.chars(i).skin = SKINS{k, 2};
            end
            SH.chars(i).rev = SH.chars(i).rev + 1; showChar();
        end
        function pickPawn(~, ~)
            i = curP(); if i == 0, return; end
            cc = uisetcolor(SH.chars(i).pawn, 'Colore della pedina'); if numel(cc) ~= 3, return; end
            SH.chars(i).pawn = cc; showChar();
        end
        function addCostume()
            i = curP(); if i == 0, return; end
            c = SH.chars(i); code = char('A' + numel(c.costumes));
            co = c.costumes(end); co.code = code; co.desc = ['costume ' code];
            c.costumes(end+1) = co; c.rev = c.rev + 1; SH.chars(i) = c; showChar(); set(lbC, 'Value', numel(c.costumes)); showCostume();
        end
        function dupCostume()
            i = curP(); j = curC(); if j == 0, return; end
            c = SH.chars(i); co = c.costumes(j); co.code = char('A' + numel(c.costumes)); co.desc = [co.desc ' (copia)'];
            c.costumes(end+1) = co; SH.chars(i) = c; showChar(); set(lbC, 'Value', numel(c.costumes)); showCostume();
        end
        function descCostume()
            i = curP(); j = curC(); if j == 0, return; end
            a = inputdlg({'Descrizione del costume'}, 'Costume', [1 60], {SH.chars(i).costumes(j).desc});
            if isempty(a), return; end
            SH.chars(i).costumes(j).desc = strtrim(a{1}); showChar(); set(lbC, 'Value', j); showCostume();
        end
        function delCostume()
            i = curP(); j = curC(); if j == 0, return; end
            if numel(SH.chars(i).costumes) == 1, errordlg('Ogni personaggio ha almeno un costume.', 'Costumi'); return; end
            SH.chars(i).costumes(j) = [];
            for q2 = 1:numel(SH.chars(i).costumes), SH.chars(i).costumes(q2).code = char('A' + q2 - 1); end
            SH.chars(i).rev = SH.chars(i).rev + 1; set(lbC, 'Value', 1); showChar();
        end
        function readMode(~, ~)
            i = curP(); j = curC(); if j == 0, return; end
            md = {'lib', 'import'}; SH.chars(i).costumes(j).mode = md{get(pMd, 'Value')};
            if strcmp(SH.chars(i).costumes(j).mode, 'import') && isempty(SH.chars(i).costumes(j).file), importCostume(); return; end
            SH.chars(i).rev = SH.chars(i).rev + 1; showCostume();
        end
        function importCostume(~, ~)
            i = curP(); j = curC(); if j == 0, return; end
            fn = importModelDlg('char');
            if isempty(fn)
                if isempty(SH.chars(i).costumes(j).file), SH.chars(i).costumes(j).mode = 'lib'; end
                showCostume(); return
            end
            SH.chars(i).costumes(j).mode = 'import'; SH.chars(i).costumes(j).file = fn;
            SH.chars(i).rev = SH.chars(i).rev + 1; showCostume();
        end
        function readCostume(~, ~)
            i = curP(); j = curC(); if j == 0, return; end
            co = SH.chars(i).costumes(j);
            for q2 = 1:NSLOT
                nid = itemIds{q2}{get(pIt(q2), 'Value')};
                if ~strcmp(nid, co.items{q2}) && ~isempty(nid)
                    k = find(strcmp({CAT.id}, nid), 1); if ~isempty(k) && ~isempty(CAT(k).hex), co.irgb(q2, :) = CAT(k).rgb; end
                end
                co.items{q2} = nid;
            end
            co.hair = hairIds{get(pHr, 'Value')}; co.facial = facIds{get(pFc, 'Value')}; co.mk.brows = BROWS{get(pBr, 'Value')};
            for q2 = 1:4, co.mk.(MK{q2, 1}) = get(cMk(q2), 'Value'); end
            SH.chars(i).costumes(j) = co; SH.chars(i).rev = SH.chars(i).rev + 1; showCostume();
        end
        function pickItemCol(src, ~)
            i = curP(); j = curC(); if j == 0, return; end
            q3 = get(src, 'UserData');
            cc = uisetcolor(SH.chars(i).costumes(j).irgb(q3, :), SLOTLBL{q3}); if numel(cc) ~= 3, return; end
            SH.chars(i).costumes(j).irgb(q3, :) = cc; SH.chars(i).rev = SH.chars(i).rev + 1; showCostume();
        end
        function pickMk(what)
            i = curP(); j = curC(); if j == 0, return; end
            co = SH.chars(i).costumes(j);
            switch what
                case 'hair', cur = co.hairRGB;
                case 'facial', cur = co.facialRGB;
                case 'brows', cur = co.mk.browsRGB;
                otherwise, cur = co.mk.([what 'RGB']);
            end
            cc = uisetcolor(cur, 'Colore'); if numel(cc) ~= 3, return; end
            switch what
                case 'hair', co.hairRGB = cc;
                case 'facial', co.facialRGB = cc;
                case 'brows', co.mk.browsRGB = cc;
                otherwise, co.mk.([what 'RGB']) = cc; co.mk.(what) = 1;
            end
            SH.chars(i).costumes(j) = co; SH.chars(i).rev = SH.chars(i).rev + 1; showCostume();
        end
    end

% =====================================================================
%                  MODELLI 3D: personaggi assemblati, elementi
% =====================================================================
    function B = loadBody(sex)
        if isKey(S.cacheB, sex), B = S.cacheB(sex); return; end
        B = load(fullfile(libDir, 'corpi', ['corpo_' sex '.mat']));
        B.V = double(B.V); B.F = double(B.F); B.masks = double(B.masks); B.eyesV = double(B.eyesV); B.eyesF = double(B.eyesF);
        B.iris = double(B.iris(:)); B.pupil = double(B.pupil(:));
        if ~iscell(B.maskNames), B.maskNames = cellstr(B.maskNames); end
        S.cacheB(sex) = B;
    end

    function P = libParts(sub, sex, id)
        P = [];
        fn = fullfile(libDir, sub, [sex '_' id '.mat']);
        if ~exist(fn, 'file'), return; end
        P = loadPartsFile(fn);
    end

    function P = charParts(ci, code)
        % personaggio completo: corpo + trucco + capi + capelli; parti con V (m) e C (0..1)
        P = [];
        if ci < 1 || ci > numel(SH.chars), return; end
        ch = SH.chars(ci);
        j = find(strcmp({ch.costumes.code}, code), 1); if isempty(j), j = 1; end
        co = ch.costumes(j);
        key = sprintf('%s|%s|%d', ch.name, co.code, ch.rev);
        if isKey(S.cacheP, key), P = S.cacheP(key); return; end
        if strcmp(co.mode, 'import')
            P = loadPartsFile(fullfile(showDir, 'modelli', co.file));
            if isempty(P), return; end
            P = prepParts(P, []);
            zmax = 0; for q = 1:numel(P), zmax = max(zmax, max(P(q).V(:, 3))); end
            if zmax > 0, for q = 1:numel(P), P(q).V = P(q).V * (ch.height / zmax); end, end
            S.cacheP(key) = P; return
        end
        B = loadBody(ch.sex);
        sk = ch.skin; n = size(B.V, 1);
        mk = @(nm) B.masks(:, strcmp(B.maskNames, nm));
        Cs = repmat(sk, n, 1);
        Cs = blendC(Cs, mk('labbra') * 0.55, sk .* [0.86 0.6 0.58]);
        Cs = blendC(Cs, mk('fard') * 0.12, [0.82 0.43 0.39]);
        if co.mk.blush, Cs = blendC(Cs, mk('fard') * 0.35, co.mk.blushRGB); end
        if co.mk.shadow, Cs = blendC(Cs, mk('ombretto') * 0.7, co.mk.shadowRGB); end
        if co.mk.lashes, Cs = blendC(Cs, mk('rimmel') * 0.95, co.mk.lashesRGB); end
        if co.mk.lips, Cs = blendC(Cs, mk('labbra') * 0.9, co.mk.lipsRGB); end
        Cs = blendC(Cs, mk(['sopr_' co.mk.brows]) * 0.9, co.mk.browsRGB);
        P = struct('V', B.V, 'F', B.F, 'C', Cs, 'alpha', 1, 'name', 'Corpo');
        Ce = repmat([0.87 0.84 0.8], size(B.eyesV, 1), 1);
        Ce = blendC(Ce, B.iris, ch.eyes); Ce = blendC(Ce, B.pupil, [0.07 0.055 0.05]);
        P(end+1) = struct('V', B.eyesV, 'F', B.eyesF, 'C', Ce, 'alpha', 1, 'name', 'Occhi');
        for q = 1:NSLOT
            if isempty(co.items{q}), continue; end
            sub = 'capi'; if strcmp(SLOTS{q}, 'Cappello'), sub = 'cappelli'; end
            appendParts(libParts(sub, ch.sex, co.items{q}), co.irgb(q, :));
        end
        if ~isempty(co.hair), appendParts(libParts('capelli', ch.sex, co.hair), co.hairRGB); end
        if ~isempty(co.facial), appendParts(libParts('barba', ch.sex, co.facial), co.facialRGB); end
        sc = ch.height / B.H0;
        for q = 1:numel(P), P(q).V = P(q).V * sc; end
        S.cacheP(key) = P;
        function appendParts(Q, rgb)
            if isempty(Q), return; end
            for q4 = 1:numel(Q)
                p = Q(q4); V = double(p.V); C = double(p.C);
                if ~isempty(p.mix)
                    w = double(p.mix(:)); C = repmat(sk, size(V, 1), 1) .* repmat(1 - w, 1, 3) + repmat(rgb, size(V, 1), 1) .* repmat(w, 1, 3);
                elseif p.tint > 0
                    C = min(1.15, C / double(p.tint)) .* repmat(rgb, size(V, 1), 1);
                else
                    C = C / 255;
                end
                P(end+1) = struct('V', V, 'F', double(p.F), 'C', min(1, max(0, C)), 'alpha', double(p.alpha), 'name', char(p.name)); %#ok<AGROW>
            end
        end
    end

    function P = elementParts(e)
        % elemento scenico pronto da disegnare, centrato in pianta, appoggiato a terra, nelle misure scelte
        P = [];
        key = sprintf('%s|%s|%g|%g|%g|%g|%g|%g', e.src, e.file, e.size, e.rgb);
        if isKey(S.cacheL, key), P = S.cacheL(key); return; end
        if strcmp(e.src, 'lib'), fn = fullfile(libDir, 'scenografia', [e.file '.mat']);
        else, fn = fullfile(showDir, 'modelli', e.file); end
        R = loadPartsFile(fn); if isempty(R), return; end
        rgb = []; if e.tint, rgb = e.rgb; end
        P = prepParts(R, rgb);
        V = vertcat(P.V); mn = min(V, [], 1); mx = max(V, [], 1); sz = max(mx - mn, 1e-3);
        k = e.size ./ sz; c = [(mn(1:2) + mx(1:2)) / 2, mn(3)];
        for q = 1:numel(P)
            P(q).V = (P(q).V - repmat(c, size(P(q).V, 1), 1)) .* repmat(k, size(P(q).V, 1), 1);
        end
        S.cacheL(key) = P;
    end

    function P = prepParts(R, rgb)
        P = struct('V', {}, 'F', {}, 'C', {}, 'alpha', {}, 'name', {});
        for q = 1:numel(R)
            p = R(q); V = double(p.V); C = double(p.C);
            if size(C, 1) ~= size(V, 1), C = repmat(C(1, :), size(V, 1), 1); end
            if ~isempty(rgb) && isfield(p, 'tint') && p.tint > 0
                C = min(1.15, C / double(p.tint)) .* repmat(rgb, size(V, 1), 1);
            elseif max(C(:)) > 1
                C = C / 255;
            end
            P(end+1) = struct('V', V, 'F', double(p.F), 'C', min(1, max(0, C)), 'alpha', double(p.alpha), 'name', char(p.name)); %#ok<AGROW>
        end
    end

    function hg = drawParts(ax, P, M)
        hg = hgtransform('Parent', ax, 'Matrix', M);
        for q = 1:numel(P)
            if isempty(P(q).F), continue; end
            patch('Parent', hg, 'Vertices', P(q).V, 'Faces', P(q).F, 'FaceVertexCData', P(q).C, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'FaceAlpha', P(q).alpha, 'FaceLighting', 'gouraud', 'AmbientStrength', 0.45, ...
                'DiffuseStrength', 0.75, 'SpecularStrength', 0.1, 'BackFaceLighting', 'lit');
        end
    end

    function [fn, bb, nm] = importModelDlg(kind)
        % importa .glb / .obj / .mat, lo alleggerisce e lo salva in "modelli"
        fn = ''; bb = [1 1 1]; nm = '';
        [f, p] = uigetfile({'*.glb;*.obj;*.mat', 'Modelli 3D (*.glb, *.obj, *.mat)'}, 'Scegli il modello 3D');
        if isequal(f, 0), return; end
        [~, base, ex] = fileparts(f); nm = base;
        hw = waitbar(0.2, 'Lettura del modello 3D...');
        try
            switch lower(ex)
                case '.glb', P = readGLB(fullfile(p, f)); yup = true;
                case '.obj'
                    P = readOBJ(fullfile(p, f));
                    a = questdlg('Nel file, quale asse e'' verso l''alto?', 'Importa', 'Y (Blender, la maggior parte)', 'Z', 'Y (Blender, la maggior parte)');
                    yup = ~strcmp(a, 'Z');
                otherwise, P = loadPartsFile(fullfile(p, f)); yup = false;
            end
            if ishandle(hw), waitbar(0.6, hw, 'Conversione...'); end
            P = normalizeImport(P, yup, strcmp(kind, 'char'));
            V = vertcat(P.V); bb = max(V, [], 1) - min(V, [], 1);
            fn = [safeName(base) '.mat']; k = 2;
            while exist(fullfile(showDir, 'modelli', fn), 'file'), fn = sprintf('%s_%d.mat', safeName(base), k); k = k + 1; end
            parts = P; %#ok<NASGU>
            save(fullfile(showDir, 'modelli', fn), 'parts');
            if ishandle(hw), close(hw); end
            nf = 0; for q = 1:numel(P), nf = nf + size(P(q).F, 1); end
            msgbox(sprintf('Modello importato: %d parti, %d facce, %.2f x %.2f x %.2f m.', numel(P), nf, bb), 'Importa');
        catch err
            if ishandle(hw), close(hw); end
            errordlg(['Importazione non riuscita: ' err.message], 'Importa'); fn = '';
        end
    end

% =====================================================================
%          IMPOSTA SCENA: chi c'e', con che costume, dove, quali luci
% =====================================================================
    function sceneSetup(k)
        if k < 1 || k > numel(SH.scenes), return; end
        sc = SH.scenes{k}; uid = sc.uid;
        T = SH.theater;
        movable = find(~[SH.elements.fixed]);
        washes = find(~strcmp({SH.lights.zone}, 'Segue un personaggio'));
        pending = []; drag = [];
        f = figure('Name', sprintf('Imposta scena  -  %s', sc.title), 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', ...
            'ToolBar', 'none', 'Units', 'normalized', 'Position', [0.04 0.06 0.9 0.85]);
        ax = axes('Parent', f, 'Units', 'normalized', 'Position', [0.01 0.08 0.56 0.86]);
        try, disableDefaultInteractivity(ax); catch, end %#ok<NOCOM>
        hint = uicontrol(f, 'Style', 'text', 'String', '', 'FontSize', 11, 'ForegroundColor', [1 .85 .45], 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.01 0.005 0.56 0.06]);
        x0 = 0.59; w0 = 0.39;
        uicontrol(f, 'Style', 'text', 'String', sprintf('Atto %s  -  Scena %d  -  %s', roman(sc.act), sc.num, sc.title), 'FontSize', 14, ...
            'FontWeight', 'bold', 'ForegroundColor', GOLD, 'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', ...
            'Position', [x0 0.94 w0 0.045]);
        lab = @(s, y) uicontrol(f, 'Style', 'text', 'String', s, 'FontSize', 10, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 y w0 0.03]);
        lab('PERSONAGGI  (in scena all''inizio = pallino pieno)', 0.9);
        lbC = uicontrol(f, 'Style', 'listbox', 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, 'Units', 'normalized', ...
            'Position', [x0 0.69 w0 * 0.6 0.21], 'Callback', @(~,~) selChar());
        uicontrol(f, 'Style', 'text', 'String', 'Costume in questa scena', 'FontSize', 9, 'ForegroundColor', TXT, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 + w0 * 0.62 0.865 w0 * 0.38 0.03]);
        pCo = uicontrol(f, 'Style', 'popupmenu', 'String', {' '}, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x0 + w0 * 0.62 0.835 w0 * 0.38 0.03], 'Callback', @(~,~) setCostume());
        bt = @(s, x, y, w, cb) uicontrol(f, 'Style', 'pushbutton', 'String', s, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x y w 0.04], 'Callback', cb);
        bt('Metti in scena / sposta', x0 + w0 * 0.62, 0.78, w0 * 0.38, @(~,~) startPlace('char'));
        bt('Togli dalla scena', x0 + w0 * 0.62, 0.735, w0 * 0.38, @(~,~) removeStart('char'));
        lab('ELEMENTI SCENICI  (quelli "fissi" ci sono sempre)', 0.645);
        lbE = uicontrol(f, 'Style', 'listbox', 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, 'Units', 'normalized', ...
            'Position', [x0 0.44 w0 * 0.6 0.205]);
        bt('Metti in scena / sposta', x0 + w0 * 0.62, 0.6, w0 * 0.38, @(~,~) startPlace('el'));
        bt('Togli dalla scena', x0 + w0 * 0.62, 0.555, w0 * 0.38, @(~,~) removeStart('el'));
        bt(['Ruota di 90' char(176)], x0 + w0 * 0.62, 0.51, w0 * 0.38, @(~,~) rotateEl());
        lab('LUCI ACCESE ALL''INIZIO  (Ctrl + clic per piu'' luci)', 0.395);
        lbL = uicontrol(f, 'Style', 'listbox', 'Max', 2, 'Min', 0, 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [x0 0.2 w0 0.195], 'Callback', @(~,~) readLights());
        uicontrol(f, 'Style', 'text', 'String', {'Chi entra piu'' tardi non va messo qui: lo fai entrare nei passi.'; ...
            'Clic su una pedina e trascina per spostarla.'}, 'FontSize', 9, 'ForegroundColor', DIM, 'BackgroundColor', BG, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 0.1 w0 0.08]);
        h = bt('Salva', x0, 0.02, 0.15, @(~,~) doSave()); set(h, 'FontWeight', 'bold', 'FontSize', 12);
        bt('Annulla', x0 + 0.24, 0.02, 0.15, @(~,~) delete(f));
        set(f, 'WindowButtonDownFcn', @(~,~) mDown(), 'WindowButtonMotionFcn', @(~,~) mMove(), 'WindowButtonUpFcn', @(~,~) mUp());
        fillAll(); redraw(); msg('Scegli un personaggio o un elemento e premi "Metti in scena", poi clicca sulla pianta.');

        function msg(s), if ishandle(hint), set(hint, 'String', s); end, end
        function i = objIdx(kind, ref)
            i = [];
            if isempty(sc.objects), return; end
            i = find(strcmp({sc.objects.kind}, kind) & strcmp({sc.objects.ref}, ref), 1);
        end
        function fillAll()
            it = cell(max(1, numel(SH.chars)), 1);
            for q = 1:numel(SH.chars)
                nm = SH.chars(q).name; i = objIdx('char', nm); on = ~isempty(i) && sc.objects(i).start;
                mk = char(9675); if on, mk = char(9679); end
                it{q} = sprintf('%s  %s   (costume %s)', mk, nm, castCode(sc, nm));
            end
            if isempty(SH.chars), it = {'(nessun personaggio: crealo in "Personaggi e costumi")'}; end
            v = get(lbC, 'Value'); if v > numel(it), v = 1; end
            set(lbC, 'String', it, 'Value', v);
            it = cell(max(1, numel(movable)), 1);
            for q = 1:numel(movable)
                nm = SH.elements(movable(q)).name; i = objIdx('el', nm); on = ~isempty(i) && sc.objects(i).start;
                mk = char(9675); if on, mk = char(9679); end
                it{q} = sprintf('%s  %s', mk, nm);
            end
            if isempty(movable), it = {'(nessun elemento mobile)'}; end
            v = get(lbE, 'Value'); if v > numel(it), v = 1; end
            set(lbE, 'String', it, 'Value', v);
            it = arrayfun(@(x) sprintf('%s   (%s, %s)', x.name, x.cname, x.zone), SH.lights(washes), 'UniformOutput', false);
            sel = [];
            for q = 1:numel(washes)
                i = objIdx('light', SH.lights(washes(q)).name);
                if ~isempty(i) && sc.objects(i).start, sel(end+1) = q; end %#ok<AGROW>
            end
            if isempty(it), it = {'(nessuna luce generale)'}; end
            set(lbL, 'String', it, 'Value', sel);
            selChar();
        end
        function selChar()
            q = get(lbC, 'Value'); if isempty(SH.chars) || q > numel(SH.chars), return; end
            ch = SH.chars(q);
            codes = arrayfun(@(x) sprintf('%s  -  %s', x.code, x.desc), ch.costumes, 'UniformOutput', false);
            j = find(strcmp({ch.costumes.code}, castCode(sc, ch.name)), 1); if isempty(j), j = 1; end
            set(pCo, 'String', codes, 'Value', j);
        end
        function setCostume()
            q = get(lbC, 'Value'); if isempty(SH.chars) || q > numel(SH.chars), return; end
            ch = SH.chars(q); code = ch.costumes(get(pCo, 'Value')).code;
            sc = setCast(sc, ch.name, code); fillAll();
        end
        function startPlace(kind)
            if strcmp(kind, 'char')
                q = get(lbC, 'Value'); if isempty(SH.chars) || q > numel(SH.chars), return; end
                pending = struct('kind', 'char', 'ref', SH.chars(q).name);
            else
                q = get(lbE, 'Value'); if isempty(movable) || q > numel(movable), return; end
                pending = struct('kind', 'el', 'ref', SH.elements(movable(q)).name);
            end
            msg(['Clicca sulla pianta dove si trova all''inizio: ' pending.ref]);
        end
        function removeStart(kind)
            if strcmp(kind, 'char')
                q = get(lbC, 'Value'); if isempty(SH.chars) || q > numel(SH.chars), return; end
                nm = SH.chars(q).name;
            else
                q = get(lbE, 'Value'); if isempty(movable) || q > numel(movable), return; end
                nm = SH.elements(movable(q)).name;
            end
            i = objIdx(kind, nm); if isempty(i), return; end
            sc.objects(i).start = false;
            sc = pruneObjs(sc); fillAll(); redraw();
            msg([nm ' non e'' in scena all''inizio (puo'' entrare durante i passi).']);
        end
        function rotateEl()
            q = get(lbE, 'Value'); if isempty(movable) || q > numel(movable), return; end
            i = objIdx('el', SH.elements(movable(q)).name); if isempty(i), msg('Prima mettilo in scena.'); return; end
            sc.objects(i).rot = mod(sc.objects(i).rot + 90, 360); redraw();
        end
        function readLights()
            sel = get(lbL, 'Value');
            for q = 1:numel(washes)
                L = SH.lights(washes(q)); i = objIdx('light', L.name); on = any(sel == q);
                if on && isempty(i)
                    g = zoneGeom(L.zone, T, [0 0]);
                    sc.objects(end+1) = newObj(newUid(), 'light', L.name, L.name, g.cx, g.cy, L.rgb, L.zone, 0, 0, 0, true);
                elseif ~isempty(i)
                    sc.objects(i).start = on;
                end
            end
            sc = pruneObjs(sc); redraw();
        end
        function redraw()
            cla(ax); stagePlan(ax, false); hold(ax, 'on');
            drawFixed2D(ax);
            for pass = {'light', 'el', 'char'}
                for i = 1:numel(sc.objects)
                    o = sc.objects(i);
                    if ~o.start || ~strcmp(o.kind, pass{1}), continue; end
                    G = make2D(ax, o); set(G.h, 'Matrix', makehgtform('translate', [o.x o.y G.z]));
                end
            end
            hold(ax, 'off'); title(ax, 'Posizioni all''inizio della scena  (pubblico in basso)', 'Color', GOLD);
        end
        function pt = planPoint()
            pt = []; cp = get(ax, 'CurrentPoint'); x = cp(1, 1); y = cp(1, 2);
            xl = get(ax, 'XLim'); yl = get(ax, 'YLim');
            if x >= xl(1) && x <= xl(2) && y >= yl(1) && y <= yl(2), pt = [x y]; end
        end
        function mDown()
            pt = planPoint(); if isempty(pt), return; end
            if ~isempty(pending)
                i = objIdx(pending.kind, pending.ref);
                if isempty(i)
                    if strcmp(pending.kind, 'char')
                        ci = find(strcmp({SH.chars.name}, pending.ref), 1);
                        sc.objects(end+1) = newObj(newUid(), 'char', pending.ref, pending.ref, pt(1), pt(2), SH.chars(ci).pawn, '', 0, 0, 0, true);
                        sc = setCast(sc, pending.ref, castCode(sc, pending.ref));
                    else
                        e = SH.elements(strcmp({SH.elements.name}, pending.ref));
                        sc.objects(end+1) = newObj(newUid(), 'el', e.name, e.name, pt(1), pt(2), planColor(e), '', e.size(1), e.size(2), 0, true);
                    end
                else
                    sc.objects(i).x = pt(1); sc.objects(i).y = pt(2); sc.objects(i).start = true;
                end
                msg([pending.ref ' posizionato. Puoi trascinarlo per correggere.']); pending = [];
                fillAll(); redraw(); return
            end
            best = 0.6; drag = [];
            for i = 1:numel(sc.objects)
                o = sc.objects(i);
                if ~o.start || strcmp(o.kind, 'light'), continue; end
                d = norm([o.x o.y] - pt);
                if d < best, best = d; drag = i; end
            end
        end
        function mMove()
            if isempty(drag), return; end
            pt = planPoint(); if isempty(pt), return; end
            sc.objects(drag).x = pt(1); sc.objects(drag).y = pt(2); redraw(); drawnow limitrate;
        end
        function mUp()
            drag = [];
        end
        function doSave()
            kk = 0; for q = 1:numel(SH.scenes), if SH.scenes{q}.uid == uid, kk = q; end, end
            if kk == 0, delete(f); return; end
            sc2 = SH.scenes{kk}; sc2.objects = sc.objects; sc2.cast = sc.cast;   % titolo e passi restano quelli attuali
            SH.scenes{kk} = pruneObjs(sc2); saveShow(); delete(f); refreshShow();
            if ~isempty(figScene) && ishandle(figScene) && S.idx == kk, goScene(kk); end
        end
    end

    function c = castCode(sc, nm)
        c = 'A';
        if ~isempty(sc.cast)
            j = find(strcmp({sc.cast.name}, nm), 1);
            if ~isempty(j), c = sc.cast(j).code; return; end
        end
        ci = find(strcmp({SH.chars.name}, nm), 1);
        if ~isempty(ci) && ~isempty(SH.chars(ci).costumes), c = SH.chars(ci).costumes(1).code; end
    end

    function col = planColor(e)
        if e.tint, col = e.rgb; else, col = [0.6 0.5 0.38]; end
    end

    function drawFixed2D(ax)
        for q = 1:numel(SH.elements)
            e = SH.elements(q); if ~e.fixed, continue; end
            o = newObj(0, 'el', e.name, e.name, e.x, e.y, planColor(e), '', e.size(1), e.size(2), e.rot, true);
            G = make2D(ax, o); set(G.h, 'Matrix', makehgtform('translate', [e.x e.y 0.05]));
            set(G.pa, 'LineStyle', '--');
        end
    end

    function G = make2D(ax, o)
        % pedina / elemento / luce nella pianta, dentro un hgtransform (si sposta cambiando la matrice)
        G.h = hgtransform('Parent', ax); G.tx = []; G.z = 0.1; G.base = 1;
        switch o.kind
            case 'char'
                t = linspace(0, 2*pi, 32); r = 0.3;
                G.pa = patch('Parent', G.h, 'XData', r*cos(t), 'YData', r*sin(t), 'FaceColor', o.rgb, 'EdgeColor', [1 1 1], 'LineWidth', 1.5, 'HitTest', 'off');
                tc = [1 1 1]; if mean(o.rgb) > 0.6, tc = [0 0 0]; end
                G.tx = [text(0, 0, 0.01, initials(o.label), 'Parent', G.h, 'Color', tc, 'FontSize', 8, 'FontWeight', 'bold', ...
                        'HorizontalAlignment', 'center', 'HitTest', 'off'), ...
                        text(0, -0.5, 0.01, o.label, 'Parent', G.h, 'Color', [1 1 1], 'FontSize', 8, 'HorizontalAlignment', 'center', 'HitTest', 'off')];
                G.z = 0.3;
            case 'el'
                w = max(o.w, 0.1); d = max(o.d, 0.1); a = o.rot * pi/180;
                c = [-w -d; w -d; w d; -w d] / 2; Rm = [cos(a) -sin(a); sin(a) cos(a)]; c = c * Rm';
                G.pa = patch('Parent', G.h, 'XData', c(:, 1), 'YData', c(:, 2), 'FaceColor', 0.5 + 0.5*o.rgb, 'FaceAlpha', 0.85, ...
                    'EdgeColor', o.rgb * 0.6, 'LineWidth', 1.2, 'HitTest', 'off');
                G.base = 0.85;
                G.tx = text(0, 0, 0.01, o.label, 'Parent', G.h, 'Color', [0.1 0.1 0.1], 'FontSize', 7, 'HorizontalAlignment', 'center', ...
                    'Interpreter', 'none', 'HitTest', 'off');
                G.z = 0.2;
            otherwise
                g = zoneGeom(o.zone, SH.theater, [0 0]);
                switch g.shape
                    case 'circle'
                        t = linspace(0, 2*pi, 40); X = g.r*cos(t); Y = g.r*sin(t);
                    case 'cyc'
                        X = [-g.w g.w g.w -g.w]/2; Y = [-0.15 -0.15 0.15 0.15];
                    otherwise
                        X = [-g.w g.w g.w -g.w]/2; Y = [-g.h -g.h g.h g.h]/2;
                end
                G.pa = patch('Parent', G.h, 'XData', X, 'YData', Y, 'FaceColor', o.rgb, 'FaceAlpha', 0.22, 'EdgeColor', 'none', 'HitTest', 'off');
                G.base = 0.22; G.z = 0.01;
                if strcmp(g.shape, 'cyc'), set(G.pa, 'FaceAlpha', 0.7); G.base = 0.7; end
        end
    end

% =====================================================================
%                            FINESTRA SCENA
% =====================================================================
    function openScene(k)
        if isempty(figScene) || ~ishandle(figScene)
            buildSceneWin();
        end
        figure(figScene); goScene(k);
    end

    function buildSceneWin()
        figScene = figure('Name', 'Scena', 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', 'ToolBar', 'none', ...
            'Units', 'normalized', 'Position', [0.04 0.05 0.66 0.86], 'CloseRequestFcn', @closeScene, 'KeyPressFcn', @sceneKey);
        S.hPrev = uicontrol(figScene, 'Style', 'pushbutton', 'String', char(9664), 'FontSize', 16, 'Units', 'normalized', ...
            'Position', [0.01 0.93 0.04 0.06], 'Callback', @(~,~) goScene(S.idx - 1), 'TooltipString', 'Scena precedente');
        S.hNext = uicontrol(figScene, 'Style', 'pushbutton', 'String', char(9654), 'FontSize', 16, 'Units', 'normalized', ...
            'Position', [0.95 0.93 0.04 0.06], 'Callback', @(~,~) goScene(S.idx + 1), 'TooltipString', 'Scena successiva');
        uicontrol(figScene, 'Style', 'pushbutton', 'String', 'Elenco passi', 'FontSize', 11, 'FontWeight', 'bold', 'Units', 'normalized', ...
            'Position', [0.06 0.93 0.1 0.06], 'Callback', @(~,~) openStepList());
        uicontrol(figScene, 'Style', 'pushbutton', 'String', 'Imposta scena', 'FontSize', 11, 'Units', 'normalized', ...
            'Position', [0.17 0.93 0.1 0.06], 'Callback', @(~,~) sceneSetup(S.idx), ...
            'TooltipString', 'Chi c''e'' all''inizio, con che costume, dove, e quali luci sono accese');
        S.hTitle = uicontrol(figScene, 'Style', 'text', 'String', '', 'FontSize', 17, 'FontWeight', 'bold', 'ForegroundColor', GOLD, ...
            'BackgroundColor', BG, 'Units', 'normalized', 'Position', [0.28 0.945 0.66 0.045]);
        S.hSub = uicontrol(figScene, 'Style', 'text', 'String', '', 'FontSize', 10, 'ForegroundColor', DIM, 'BackgroundColor', BG, ...
            'Units', 'normalized', 'Position', [0.28 0.915 0.66 0.03]);
        S.pan2 = uipanel(figScene, 'Units', 'normalized', 'Position', [0.01 0.28 0.78 0.63], 'BorderType', 'none', 'BackgroundColor', BG);
        S.ax = axes('Parent', S.pan2, 'Units', 'normalized', 'Position', [0 0 1 1], 'Color', BG);
        try, disableDefaultInteractivity(S.ax); catch, end %#ok<NOCOM>
        S.pan3 = uipanel(figScene, 'Units', 'normalized', 'Position', [0.01 0.28 0.78 0.63], 'BorderType', 'none', 'BackgroundColor', [0 0 0], 'Visible', 'off');
        S.ax3 = axes('Parent', S.pan3, 'Units', 'normalized', 'Position', [0 0 1 1], 'Color', [0 0 0]);
        try, disableDefaultInteractivity(S.ax3); catch, end %#ok<NOCOM>
        cb3 = @(str, x, w, cb, tip) uicontrol(S.pan3, 'Style', 'pushbutton', 'String', str, 'FontSize', 11, 'Units', 'normalized', ...
            'Position', [x 0.925 w 0.06], 'Callback', cb, 'TooltipString', tip);
        cb3('+', 0.01, 0.04, @(~,~) cam3Zoom(1/1.2), 'Avvicina');
        cb3(char(8722), 0.055, 0.04, @(~,~) cam3Zoom(1.2), 'Allontana');
        cb3([char(8634) ' Vista di default'], 0.10, 0.15, @(~,~) cam3Reset(), 'Torna alla vista dalla platea');
        uicontrol(S.pan3, 'Style', 'text', 'String', 'Trascina: ruota  |  tasto destro o Shift + trascina: sposta  |  rotella: zoom', ...
            'FontSize', 9, 'ForegroundColor', [.75 .75 .75], 'BackgroundColor', [0 0 0], 'Units', 'normalized', ...
            'Position', [0.26 0.93 0.5 0.04], 'HorizontalAlignment', 'left');
        set(figScene, 'WindowButtonDownFcn', @(~,~) cam3Down(), 'WindowButtonUpFcn', @(~,~) cam3Up(), ...
            'WindowButtonMotionFcn', @(~,~) cam3Move(), 'WindowScrollWheelFcn', @(~, ev) cam3Zoom(1.1 ^ ev.VerticalScrollCount));
        bx = 0.80; bw = 0.19; bh = 0.048; hb = bw/2 - 0.003; bx2 = bx + bw/2 + 0.003;
        mk = @(str, y, cb) uicontrol(figScene, 'Style', 'pushbutton', 'String', str, 'FontSize', 11, ...
            'Units', 'normalized', 'Position', [bx y bw bh], 'Callback', cb);
        S.hView = mk('Vista da pubblico', 0.865, @(~,~) toggleView());
        set(S.hView, 'FontWeight', 'bold', 'TooltipString', 'Palco visto dalla platea, con i personaggi in 3D');
        uicontrol(figScene, 'Style', 'pushbutton', 'String', [char(9834) char(9654) ' Sync'], 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [bx 0.809 hb bh], 'Callback', @(~,~) syncMontaggio(1), ...
            'TooltipString', 'Fa partire insieme canzone e montaggio (segue i tempi registrati, se ci sono)');
        S.hRec = uicontrol(figScene, 'Style', 'pushbutton', 'String', [char(9679) ' Registra'], 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [bx2 0.809 hb bh], 'Callback', @(~,~) recordCues(), ...
            'TooltipString', 'Registra a orecchio i tempi: premi la barra spaziatrice quando deve partire ogni passo');
        mk([char([9654 9654]) '  Montaggio'], 0.753, @(~,~) runMontaggio());
        mk('Passo singolo', 0.697, @(~,~) runStep());
        uicontrol(figScene, 'Style', 'pushbutton', 'String', 'Ricomincia', 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [bx 0.641 hb bh], 'Callback', @(~,~) resetScene());
        uicontrol(figScene, 'Style', 'pushbutton', 'String', 'Tempi passi', 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [bx2 0.641 hb bh], 'Callback', @(~,~) openCueTable(), 'TooltipString', 'Tabella dei tempi dei passi: correggi, sposta, ascolta');
        mk([char(9834) '  Play'], 0.578, @(~,~) playMusic());
        mk([char([10074 10074]) '  Pausa'], 0.522, @(~,~) pauseMusic());
        S.hSlider = uicontrol(figScene, 'Style', 'slider', 'Min', 0, 'Max', 1, 'Value', 0, 'SliderStep', [0.01 0.1], ...
            'Units', 'normalized', 'Position', [bx 0.487 bw 0.03], 'Callback', @(src, ~) seekTo(get(src, 'Value')));
        try, addlistener(S.hSlider, 'ContinuousValueChange', @(src, ~) dragSlider(get(src, 'Value'))); catch, end %#ok<NOCOM>
        S.hTime = uicontrol(figScene, 'Style', 'text', 'String', '00:00 / --:--', 'FontSize', 11, 'ForegroundColor', TXT, ...
            'BackgroundColor', BG, 'Units', 'normalized', 'Position', [bx 0.455 bw 0.03]);
        mk('Costumi della scena', 0.395, @(~,~) sceneCostumes());
        mk('Elenco scene', 0.339, @(~,~) toShowWin());
        S.hMusic = uicontrol(figScene, 'Style', 'text', 'String', '', 'FontSize', 8, 'ForegroundColor', DIM, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [bx 0.298 bw 0.036]);
        S.hSnap = uicontrol(figScene, 'Style', 'checkbox', 'String', 'Aggancia alla battuta', 'Value', double(S.snap), 'FontSize', 9, ...
            'ForegroundColor', TXT, 'BackgroundColor', BG, 'Units', 'normalized', 'Position', [bx 0.272 bw 0.026], ...
            'Callback', @(src, ~) setSnap(get(src, 'Value')), 'TooltipString', 'Durante la registrazione sposta il tempo sull''attacco musicale piu'' vicino');
        S.hComment = uicontrol(figScene, 'Style', 'edit', 'Max', 50, 'Min', 0, 'Enable', 'inactive', 'FontSize', 11, ...
            'HorizontalAlignment', 'left', 'BackgroundColor', PANEL, 'ForegroundColor', TXT, ...
            'Units', 'normalized', 'Position', [0.01 0.01 0.98 0.26]);
        S.view3 = false; S.h3 = [];
    end

    function toShowWin()
        if ~isempty(figShow) && ishandle(figShow), figure(figShow); end
    end

    function sceneKey(~, ev)
        switch ev.Key
            case 'rightarrow', if ~S.rec, goScene(S.idx + 1); end
            case 'leftarrow',  if ~S.rec, goScene(S.idx - 1); end
            case 'space',      if S.rec, markCue(); else, runStep(); end
            case 'escape',     if S.rec, stopRecording(true); end
        end
    end

    function closeScene(src, ~)
        S.stop = true; S.token = S.token + 1; stopMusic(); delete(src); figScene = [];
    end

    function sc = curScene()
        sc = SH.scenes{S.idx};
    end

    function goScene(k)
        if isempty(figScene) || ~ishandle(figScene), return; end
        if k < 1 || k > numel(SH.scenes), return; end
        if S.rec, stopRecording(false); end
        S.stop = true; S.token = S.token + 1; drawnow; stopMusic();
        S.idx = k; sc = SH.scenes{k};
        set(figScene, 'Name', sprintf('Scena  -  %s', sc.title));
        set(S.hTitle, 'String', sc.title);
        set(S.hSub, 'String', sprintf('Atto %s   %s   Scena %d   %s   %s', roman(sc.act), char(183), sc.num, char(183), SH.title));
        drawScene2D();
        S.step = 0; S.stop = false;
        set(S.hComment, 'String', [{['0  ' startText(sc)]}; {''}; ...
            {'"Sync" = canzone e movimenti insieme;  "Montaggio" = tutta la scena;  "Passo singolo" (o barra spaziatrice) = un passo alla volta.'}]);
        f = findMusic(sc.num);
        if isempty(f), set(S.hMusic, 'String', sprintf('Canzone non trovata.\nMetti in "audio" un file che inizi con "%02d".', sc.num));
        else, [~, nm, ex] = fileparts(f); set(S.hMusic, 'String', ['Canzone: ' nm ex]); end
        loadCues();
        if ~isempty(S.cueT), set(S.hMusic, 'String', [get(S.hMusic, 'String') '  (tempi registrati)']); end
        if ~isempty(figShow) && ishandle(figShow), set(hShow.lb, 'Value', k); end
    end

    function s = startText(sc)
        s = sc.start;
        if isempty(s)
            nm = {};
            for q = 1:numel(sc.objects)
                if sc.objects(q).start && strcmp(sc.objects(q).kind, 'char'), nm{end+1} = sc.objects(q).label; end %#ok<AGROW>
            end
            if isempty(nm), s = 'Inizio della scena: palco vuoto.'; else, s = ['Inizio della scena: in scena ' strjoin(nm, ', ') '.']; end
        end
    end

    function drawScene2D()
        ax = S.ax; cla(ax); sc = curScene();
        stagePlan(ax, false); hold(ax, 'on');
        drawFixed2D(ax);
        S.objs = sc.objects; n = numel(S.objs);
        S.pos = zeros(n, 2); S.A = zeros(1, n); S.g2 = cell(1, n);
        for pass = {'light', 'el', 'char'}
            for i = 1:n
                if ~strcmp(S.objs(i).kind, pass{1}), continue; end
                S.g2{i} = make2D(ax, S.objs(i));
            end
        end
        hold(ax, 'off');
        if S.view3, build3D(); end
        resetScene();
    end

    function resetScene()
        S.stop = true; S.step = 0; S.token = S.token + 1;
        for i = 1:numel(S.objs)
            S.pos(i, :) = [0 0]; setObj(i, 0, 0, double(S.objs(i).start));
        end
        if ishandle(S.hComment), set(S.hComment, 'String', {['0  ' startText(curScene())]}); end
        drawnow; S.stop = false;
    end

    function setObj(i, dx, dy, a)
        o = S.objs(i); G = S.g2{i};
        if ~isempty(G) && ishandle(G.h)
            set(G.h, 'Matrix', makehgtform('translate', [o.x + dx, o.y + dy, G.z]), 'Visible', onoff(a > 0.02));
            if strcmp(o.kind, 'light'), set(G.pa, 'FaceAlpha', G.base * min(1, a)); end
        end
        S.A(i) = a;
        update3D(i, dx, dy, a);
    end

    function runMontaggio()
        if S.running, return; end
        sc = curScene();
        if S.step >= numel(sc.steps), resetScene(); end
        S.stop = false; tok = S.token;
        while S.step < numel(sc.steps) && ~S.stop && ishandle(figScene) && tok == S.token
            runStep(); if S.stop || tok ~= S.token, break; end
            pause(0.9);
        end
    end

    function runStep()
        if S.running || isempty(figScene) || ~ishandle(figScene), return; end
        sc = curScene();
        if S.step >= numel(sc.steps)
            set(S.hComment, 'String', [get(S.hComment, 'String'); {''; [char(8212) ' Fine della scena ' char(8212)]}]); return
        end
        S.running = true; S.step = S.step + 1; k = S.step; tok = S.token;
        eff = sc.steps{k};
        txt = [{sprintf('%d  %s', k, cueText(sc, k))}; ensLine(sc, k); describeStep(eff)];
        set(S.hComment, 'String', txt);
        ids = [S.objs.id];
        if ~isempty(eff), eff = eff(ismember([eff.spid], ids)); end
        T = 0; for e = 1:numel(eff), T = max(T, eff(e).delay + eff(e).dur); end
        idxOf = zeros(1, numel(eff));
        for e = 1:numel(eff), idxOf(e) = find(ids == eff(e).spid, 1); end
        if S.syncing && numel(S.cueEnd) >= k && numel(S.cueT) >= k && ~isnan(S.cueEnd(k)) && ~isnan(S.cueT(k)) && T > 0
            Tw = S.cueEnd(k) - S.cueT(k);
            if Tw > 0.2
                fk = Tw / T;
                for e = 1:numel(eff), eff(e).delay = eff(e).delay * fk; eff(e).dur = eff(e).dur * fk; end
                T = Tw;
            end
        end
        a0 = S.A;
        t0 = tic; fps = 30;
        while true
            t = toc(t0); if S.stop || ~ishandle(figScene) || tok ~= S.token, break; end
            for e = 1:numel(eff)
                i = idxOf(e); u = min(max((t - eff(e).delay) / max(eff(e).dur, 0.01), 0), 1);
                u = 0.5 - 0.5*cos(pi*u);
                switch eff(e).cls
                    case 'path'
                        p = pathPoint(eff(e).pts, u); S.pos(i, :) = p; setObj(i, p(1), p(2), S.A(i));
                    case 'entr'
                        if t >= eff(e).delay, setObj(i, S.pos(i, 1), S.pos(i, 2), max(a0(i), u)); end
                    case 'exit'
                        if t >= eff(e).delay, setObj(i, S.pos(i, 1), S.pos(i, 2), min(a0(i), 1 - u)); end
                end
            end
            drawnow limitrate;
            if t > T, break; end
            pause(1/fps);
        end
        S.running = false;
    end

    function fastForward(m)
        sc = curScene(); ids = [S.objs.id];
        for k = 1:min(m, numel(sc.steps))
            eff = sc.steps{k};
            for e = 1:numel(eff)
                i = find(ids == eff(e).spid, 1); if isempty(i), continue; end
                switch eff(e).cls
                    case 'path', p = eff(e).pts(end, :); S.pos(i, :) = p; setObj(i, p(1), p(2), S.A(i));
                    case 'entr', setObj(i, S.pos(i, 1), S.pos(i, 2), 1);
                    case 'exit', setObj(i, S.pos(i, 1), S.pos(i, 2), 0);
                end
            end
        end
        S.step = min(m, numel(sc.steps)); drawnow;
    end

    function L = ensLine(sc, k)
        L = {};
        if k > 0 && k <= numel(sc.ens) && ~isempty(sc.ens{k}), L = {['   ' char(9670) ' Corpo di ballo: ' sc.ens{k}]}; end
    end

    function L = describeStep(eff)
        L = {}; T = SH.theater;
        for e = 1:numel(eff)
            k = find([S.objs.id] == eff(e).spid, 1); if isempty(k), continue; end
            o = S.objs(k); nm = o.label;
            switch eff(e).cls
                case 'path'
                    p0 = [o.x o.y] + eff(e).pts(1, :); p1 = [o.x o.y] + eff(e).pts(end, :);
                    if strcmp(o.kind, 'char'), L{end+1, 1} = [char(8226) ' ' nm ': ' moveVerb(p0, p1, T)]; %#ok<AGROW>
                    elseif strcmp(o.kind, 'light'), L{end+1, 1} = [char(8226) ' Luce "' nm '": segue verso ' zoneName(p1, T)]; %#ok<AGROW>
                    else, L{end+1, 1} = [char(8226) ' ' nm ': viene spostato verso ' zoneName(p1, T)]; end %#ok<AGROW>
                case 'entr'
                    if strcmp(o.kind, 'light'), L{end+1, 1} = [char(8226) ' Luce "' nm '": si accende']; %#ok<AGROW>
                    else, L{end+1, 1} = [char(8226) ' ' nm ': entra in scena']; end %#ok<AGROW>
                case 'exit'
                    if strcmp(o.kind, 'light'), L{end+1, 1} = [char(8226) ' Luce "' nm '": si spegne']; %#ok<AGROW>
                    else, L{end+1, 1} = [char(8226) ' ' nm ': esce di scena']; end %#ok<AGROW>
            end
        end
    end

    function sceneCostumes()
        sc = curScene();
        nm = {};
        for q = 1:numel(sc.objects)
            if strcmp(sc.objects(q).kind, 'char') && ~any(strcmp(nm, sc.objects(q).ref)), nm{end+1} = sc.objects(q).ref; end %#ok<AGROW>
        end
        if isempty(nm), msgbox('In questa scena non ci sono personaggi.', 'Costumi'); return; end
        f = figure('Name', ['Costumi  -  ' sc.title], 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', 'ToolBar', 'figure', ...
            'Units', 'normalized', 'Position', [0.1 0.15 0.8 0.7]);
        n = numel(nm);
        for q = 1:n
            ci = find(strcmp({SH.chars.name}, nm{q}), 1); if isempty(ci), continue; end
            code = castCode(sc, nm{q}); j = find(strcmp({SH.chars(ci).costumes.code}, code), 1); if isempty(j), j = 1; end
            co = SH.chars(ci).costumes(j);
            ax = axes('Parent', f, 'Units', 'normalized', 'Position', [(q - 1)/n + 0.005, 0.12, 1/n - 0.01, 0.82], 'Color', BG);
            P = charParts(ci, code);
            if ~isempty(P)
                drawParts(ax, P, eye(4)); axis(ax, 'equal'); axis(ax, 'off'); view(ax, [-20 6]); camlight(ax, 'headlight'); lighting(ax, 'gouraud');
            end
            uicontrol(f, 'Style', 'text', 'String', {nm{q}; sprintf('costume %s: %s', co.code, co.desc)}, 'FontSize', 10, ...
                'ForegroundColor', TXT, 'BackgroundColor', BG, 'Units', 'normalized', 'Position', [(q - 1)/n, 0.01, 1/n, 0.1]);
        end
        rotate3d(f, 'on');
    end

% ------------------------------- vista da pubblico (3D) -------------------------------
    function toggleView()
        S.view3 = ~S.view3;
        if S.view3
            set(S.hView, 'String', 'Vista dall''alto');
            set(S.pan2, 'Visible', 'off'); set(S.pan3, 'Visible', 'on');
            build3D();
            for i = 1:numel(S.objs), update3D(i, S.pos(i, 1), S.pos(i, 2), S.A(i)); end
        else
            set(S.hView, 'String', 'Vista da pubblico');
            set(S.pan3, 'Visible', 'off'); set(S.pan2, 'Visible', 'on');
            cla(S.ax3); S.h3 = [];
        end
        drawnow;
    end

    function build3D()
        S.h3 = draw3D(S.ax3, curScene(), true);
        title(S.ax3, [curScene().title '  ' char(8212) '  vista dalla platea'], 'Color', GOLD, 'FontSize', 12);
    end

    function H = draw3D(ax, sc, live)
        cla(ax); hold(ax, 'on');
        T = SH.theater; W = T.W; D = T.D; P = T.P; wg = T.wing; Hh = T.H;
        objs = sc.objects; n = numel(objs);
        H = repmat(struct('t', [], 'lbl', [], 'z', 0, 'pa', [], 'base', 1, 'rot', 0), 1, n);
        xa = -W/2 - wg; xb = W/2 + wg;
        patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [-P -P D D], 'ZData', [0 0 0 0], ...
            'FaceColor', [0.36 0.27 0.19], 'EdgeColor', 'none', 'FaceLighting', 'gouraud', 'AmbientStrength', 0.5);
        for yy = -P:0.4:D
            plot3(ax, [xa xb], [yy yy], [0.003 0.003], 'Color', [0.25 0.19 0.13], 'LineWidth', 0.5);
        end
        patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [-P -P -P -P], 'ZData', [0 0 -0.9 -0.9], 'FaceColor', [0.12 0.10 0.09], 'EdgeColor', 'none');
        for yy = quinteY(T)
            for sd = [-1 1]
                qw = quinteWidth(T); patch('Parent', ax, 'XData', sd*[W/2 - 0.2, W/2 - 0.2 + qw, W/2 - 0.2 + qw, W/2 - 0.2], 'YData', [yy yy yy yy], 'ZData', [0 0 Hh Hh], ...
                    'FaceColor', [0.06 0.06 0.07], 'EdgeColor', 'none');
            end
        end
        switch T.back
            case 'Ciclorama bianco', bc = [0.85 0.85 0.85];
            case 'Grigio', bc = [0.35 0.35 0.36];
            otherwise, bc = [0.05 0.05 0.06];
        end
        switch T.back
            case 'Immagine (foto o disegno)'
                try
                    im = backImage(); hI = min(Hh, (xb - xa) * size(im, 1) / size(im, 2));
                    surface('Parent', ax, 'XData', [xa xb; xa xb], 'YData', [D D; D D], 'ZData', [hI hI; 0 0], 'CData', im, ...
                        'FaceColor', 'texturemap', 'EdgeColor', 'none', 'FaceLighting', 'none');
                    if hI < Hh
                        patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [D D D D] + 0.01, 'ZData', [hI hI Hh Hh], 'FaceColor', [0.05 0.05 0.06], 'EdgeColor', 'none');
                    end
                catch
                    patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [D D D D], 'ZData', [0 0 Hh Hh], 'FaceColor', bc, 'EdgeColor', 'none', 'FaceLighting', 'none');
                end
            case 'Modello 3D'
                patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [D D D D] + 0.5, 'ZData', [0 0 Hh Hh], 'FaceColor', bc, 'EdgeColor', 'none', 'FaceLighting', 'none');
                Pb = backModelParts(); if ~isempty(Pb), drawParts(ax, Pb, eye(4)); end
            otherwise
                patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [D D D D], 'ZData', [0 0 Hh Hh], 'FaceColor', bc, 'EdgeColor', 'none', 'FaceLighting', 'none');
        end
        for q = 1:numel(SH.elements)
            e = SH.elements(q); if ~e.fixed, continue; end
            Pp = elementParts(e); if isempty(Pp), continue; end
            drawParts(ax, Pp, makehgtform('translate', [e.x e.y 0]) * makehgtform('zrotate', e.rot*pi/180));
        end
        for i = 1:n
            o = objs(i);
            switch o.kind
                case 'char'
                    ci = find(strcmp({SH.chars.name}, o.ref), 1); if isempty(ci), continue; end
                    Pp = charParts(ci, castCode(sc, o.ref)); if isempty(Pp), continue; end
                    H(i).t = drawParts(ax, Pp, eye(4));
                    zt = 0; for q = 1:numel(Pp), zt = max(zt, max(Pp(q).V(:, 3))); end
                    if zt <= 0, zt = 1.8; end
                    H(i).z = zt + 0.15;
                    H(i).lbl = text(0, 0, zt + 0.15, o.label, 'Parent', ax, 'Color', [1 1 1], 'FontSize', 7, 'FontWeight', 'bold', ...
                        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Clipping', 'off');
                case 'el'
                    ei = find(strcmp({SH.elements.name}, o.ref), 1); if isempty(ei), continue; end
                    Pp = elementParts(SH.elements(ei)); if isempty(Pp), continue; end
                    H(i).t = drawParts(ax, Pp, eye(4)); H(i).rot = o.rot;
                otherwise
                    g = zoneGeom(o.zone, T, [0 0]);
                    hg = hgtransform('Parent', ax);
                    switch g.shape
                        case 'circle'
                            th = linspace(0, 2*pi, 40);
                            pa = patch('Parent', hg, 'XData', g.r*cos(th), 'YData', g.r*sin(th), 'ZData', 0.012 + 0*th, 'FaceColor', o.rgb, ...
                                'FaceAlpha', 0.35, 'EdgeColor', 'none', 'FaceLighting', 'none');
                            base = 0.35;
                        case 'cyc'
                            pa = patch('Parent', hg, 'XData', [-W/2 - wg, W/2 + wg, W/2 + wg, -W/2 - wg], 'YData', [0.1 0.1 0.1 0.1], ...
                                'ZData', [0 0 Hh Hh], 'FaceColor', o.rgb, 'FaceAlpha', 0.6, 'EdgeColor', 'none', 'FaceLighting', 'none');
                            base = 0.6;
                        otherwise
                            pa = patch('Parent', hg, 'XData', [-g.w g.w g.w -g.w]/2, 'YData', [-g.h -g.h g.h g.h]/2, 'ZData', [0.01 0.01 0.01 0.01], ...
                                'FaceColor', o.rgb, 'FaceAlpha', 0.26, 'EdgeColor', 'none', 'FaceLighting', 'none');
                            base = 0.26;
                    end
                    H(i).t = hg; H(i).pa = pa; H(i).base = base;
            end
        end
        hold(ax, 'off');
        set(ax, 'XTick', [], 'YTick', [], 'ZTick', [], 'XColor', 'none', 'YColor', 'none', 'ZColor', 'none', 'Color', [0 0 0], ...
            'DataAspectRatio', [1 1 1], 'XLim', [xa - 3, xb + 3], 'YLim', [-P - 4, D + 2], 'ZLim', [-1 Hh + 2], 'Clipping', 'off');
        S.cam0 = struct('pos', [0, -max(14, 1.5*W + P), 0.45*Hh + 1.8], 'tgt', [0, D*0.42, 1.6], 'va', 34);
        cam = S.cam0; if live && ~isempty(S.camCur), cam = S.camCur; end
        set(ax, 'Projection', 'perspective', 'CameraPosition', cam.pos, 'CameraTarget', cam.tgt, 'CameraUpVector', [0 0 1], 'CameraViewAngle', cam.va);
        light('Parent', ax, 'Position', [0 -9 10], 'Style', 'local', 'Color', [1 .95 .86]);
        light('Parent', ax, 'Position', [-8 2 9], 'Style', 'local', 'Color', [.45 .45 .6]);
        light('Parent', ax, 'Position', [8 2 9], 'Style', 'local', 'Color', [.6 .5 .45]);
    end

    function place3D(Hi, o, dx, dy, a)
        if isempty(Hi.t) || ~ishandle(Hi.t), return; end
        X = o.x + dx; Y = o.y + dy;
        M = makehgtform('translate', [X Y 0]);
        if Hi.rot ~= 0, M = M * makehgtform('zrotate', Hi.rot*pi/180); end
        set(Hi.t, 'Matrix', M, 'Visible', onoff(a > 0.02));
        if ~isempty(Hi.pa) && ishandle(Hi.pa), set(Hi.pa, 'FaceAlpha', Hi.base * min(1, a)); end
        if ~isempty(Hi.lbl) && ishandle(Hi.lbl), set(Hi.lbl, 'Position', [X, Y, Hi.z], 'Visible', onoff(a > 0.3)); end
    end

    function update3D(i, dx, dy, a)
        if ~S.view3 || isempty(S.h3) || i > numel(S.h3), return; end
        place3D(S.h3(i), S.objs(i), dx, dy, a);
    end

    % ---- telecamera della vista da pubblico
    function ok = over3D()
        ok = false;
        if ~S.view3 || ~ishandle(S.ax3), return; end
        try
            h = hittest(figScene); ok = ~isempty(h) && isequal(ancestor(h, 'axes'), S.ax3);
        catch
            ok = false;
        end
    end
    function cam3Down()
        if ~over3D(), return; end
        md = 'orbit'; if any(strcmp(get(figScene, 'SelectionType'), {'alt', 'extend'})), md = 'pan'; end
        S.camDrag = struct('p0', get(0, 'PointerLocation'), 'pos', get(S.ax3, 'CameraPosition'), 'tgt', get(S.ax3, 'CameraTarget'), 'mode', md);
    end
    function cam3Up()
        if isempty(S.camDrag), return; end
        S.camDrag = []; cam3Store();
    end
    function cam3Move()
        if isempty(S.camDrag) || ~S.view3 || ~ishandle(S.ax3), return; end
        d = get(0, 'PointerLocation') - S.camDrag.p0;
        p = S.camDrag.pos; t = S.camDrag.tgt; v = p - t; r = norm(v);
        if strcmp(S.camDrag.mode, 'orbit')
            az = atan2(v(2), v(1)) - d(1) * 0.006;
            el = asin(max(-1, min(1, v(3) / r))) - d(2) * 0.005; el = max(0.02, min(1.45, el));
            v = r * [cos(el) * cos(az), cos(el) * sin(az), sin(el)];
            set(S.ax3, 'CameraPosition', t + v, 'CameraUpVector', [0 0 1]);
        else
            fw = -v / r; rt = cross(fw, [0 0 1]); rt = rt / max(norm(rt), 1e-6); up = cross(rt, fw);
            k = r * 0.0016; m = -d(1) * k * rt - d(2) * k * up;
            set(S.ax3, 'CameraPosition', p + m, 'CameraTarget', t + m);
        end
        drawnow limitrate;
    end
    function cam3Zoom(f)
        if ~S.view3 || ~ishandle(S.ax3), return; end
        va = get(S.ax3, 'CameraViewAngle') * f; set(S.ax3, 'CameraViewAngle', max(4, min(70, va))); cam3Store();
    end
    function cam3Store()
        if ~ishandle(S.ax3), return; end
        S.camCur = struct('pos', get(S.ax3, 'CameraPosition'), 'tgt', get(S.ax3, 'CameraTarget'), 'va', get(S.ax3, 'CameraViewAngle'));
    end
    function cam3Reset()
        S.camCur = [];
        if isempty(S.cam0) || ~ishandle(S.ax3), return; end
        set(S.ax3, 'CameraPosition', S.cam0.pos, 'CameraTarget', S.cam0.tgt, 'CameraUpVector', [0 0 1], 'CameraViewAngle', S.cam0.va);
    end

% ------------------------------- musica -------------------------------
    function f = findMusic(num)
        % la canzone di una scena e' il file in "audio" il cui nome inizia con il numero della scena (es. "03 Titolo.mp3")
        f = ''; if isempty(showDir), return; end
        dd = dir(fullfile(showDir, 'audio')); exts = {'.mp3', '.wav', '.m4a', '.ogg', '.flac', '.aac'};
        for q = 1:numel(dd)
            [~, nm, ex] = fileparts(dd(q).name);
            if dd(q).isdir || ~any(strcmpi(ex, exts)), continue; end
            t = regexp(nm, '^\s*(\d+)', 'tokens', 'once');
            if ~isempty(t) && str2double(t{1}) == num, f = fullfile(showDir, 'audio', dd(q).name); return; end
        end
    end

    function ok = loadPlayer()
        ok = ~isempty(S.player) && isobject(S.player);
        if ok, return; end
        sc = curScene(); f = findMusic(sc.num);
        if isempty(f)
            msgbox(sprintf('Nessuna canzone per la scena %d.\nMetti nella cartella "audio" dello spettacolo un file che inizi con "%02d", ad esempio:\n"%02d %s.mp3"', ...
                sc.num, sc.num, sc.num, safeName(sc.title)), 'Canzone'); return
        end
        try
            [y, fs] = audioread(f);
            S.player = audioplayer(y, fs); S.fs = fs; S.dur = size(y, 1) / fs;
            S.onsets = detectOnsets(y, fs);
            set(S.player, 'TimerPeriod', 0.25, 'TimerFcn', @(~,~) updatePos());
            set(S.hSlider, 'Max', max(S.dur, 0.1), 'Value', 0, 'SliderStep', [min(1, 5/max(S.dur,5)) min(1, 30/max(S.dur,30))]);
            showTime(0); ok = true;
        catch err
            errordlg(['Impossibile leggere il file audio: ' err.message], 'Canzone');
        end
    end

    function playMusic()
        if ~loadPlayer(), return; end
        try
            if ~isempty(S.seek)
                st = max(1, min(round(S.seek * S.fs), get(S.player, 'TotalSamples'))); stop(S.player); play(S.player, st); S.seek = [];
            elseif ~isplaying(S.player)
                if get(S.player, 'CurrentSample') > 1, resume(S.player); else, play(S.player); end
            end
        catch err
            errordlg(['Errore di riproduzione: ' err.message], 'Canzone');
        end
    end

    function pauseMusic()
        if ~isempty(S.player) && isobject(S.player), try, pause(S.player); catch, end, end
    end

    function stopMusic()
        if ~isempty(S.player) && isobject(S.player), try, stop(S.player); delete(S.player); catch, end, end
        S.player = []; S.seek = []; S.dur = 0;
        if isfield(S, 'hSlider') && ~isempty(S.hSlider) && ishandle(S.hSlider), set(S.hSlider, 'Value', 0, 'Max', 1); set(S.hTime, 'String', '00:00 / --:--'); end
    end

    function seekTo(t)
        S.dragging = false;
        if isempty(S.player) || ~isobject(S.player)
            if ~loadPlayer(), set(S.hSlider, 'Value', 0); return; end
            t = min(t, S.dur);
        end
        showTime(t);
        if isplaying(S.player)
            st = max(1, min(round(t * S.fs), get(S.player, 'TotalSamples'))); stop(S.player); play(S.player, st); S.seek = [];
        else
            S.seek = t;
        end
    end

    function dragSlider(t)
        S.dragging = true; showTime(t);
    end

    function updatePos()
        if S.dragging || isempty(S.player) || ~isobject(S.player) || ~ishandle(S.hSlider), return; end
        try
            t = (get(S.player, 'CurrentSample') - 1) / S.fs;
            set(S.hSlider, 'Value', min(max(t, 0), get(S.hSlider, 'Max'))); showTime(t);
        catch
        end
    end

    function showTime(t)
        mmss = @(x) sprintf('%02d:%02d', floor(x/60), floor(mod(x, 60)));
        if S.dur > 0, set(S.hTime, 'String', [mmss(t) ' / ' mmss(S.dur)]); else, set(S.hTime, 'String', [mmss(t) ' / --:--']); end
    end

% ------------------------------- Sync, registrazione e tempi dei passi -------------------------------
    function syncMontaggio(k0)
        if nargin < 1, k0 = 1; end
        if S.running || S.syncing || S.rec, return; end
        resetScene(); stopMusic();
        if ~loadPlayer(), return; end
        sc = curScene(); n = numel(sc.steps);
        if n == 0, play(S.player); return; end
        loadCues();
        if ~isempty(S.cueT), tk = fillCues(S.cueT, S.dur); how = 'tempi registrati';
        else, tk = fillCues(nan(1, n), S.dur); how = 'distribuiti in modo uniforme'; end
        k0 = max(1, min(k0, n));
        S.syncing = true; tok = S.token;
        if k0 > 1, fastForward(k0 - 1); end
        t0 = 0; if k0 > 1, t0 = max(0, tk(k0) - 3); end
        play(S.player, max(1, round(t0 * S.fs) + 1));
        set(S.hComment, 'String', [get(S.hComment, 'String'); {''; sprintf('Sync: %d passi, %s (canzone %02d:%02d).', n, how, floor(S.dur/60), floor(mod(S.dur, 60)))}]);
        k = k0;
        while k <= n && ~S.stop && tok == S.token && ishandle(figScene)
            if isempty(S.player) || ~isobject(S.player), break; end
            t = (get(S.player, 'CurrentSample') - 1) / S.fs;
            if t >= tk(k), runStep(); k = k + 1; else, pause(0.04); end
        end
        S.syncing = false;
    end

    function setSnap(v)
        S.snap = (v == 1);
    end

    function f = cueFile()
        f = fullfile(showDir, 'cue', sprintf('scena_%d.cue.csv', curScene().uid));
    end

    function loadCues()
        S.cueT = []; S.cueEnd = [];
        f = cueFile(); if ~exist(f, 'file'), return; end
        n = numel(curScene().steps); T = nan(1, n); E = nan(1, n);
        fid = fopen(f, 'r', 'n', 'UTF-8'); if fid < 0, return; end
        fgetl(fid);
        while true
            l = fgetl(fid); if ~ischar(l), break; end
            c = strsplit(l, ';'); if numel(c) < 2, continue; end
            k = str2double(c{1}); if isnan(k) || k < 1 || k > n, continue; end
            T(k) = parseTime(c{2}); if numel(c) >= 3, E(k) = parseTime(c{3}); end
        end
        fclose(fid);
        if any(~isnan(T)), S.cueT = T; S.cueEnd = E; end
    end

    function saveCues(T, E)
        f = cueFile(); sc = curScene();
        fid = fopen(f, 'w', 'n', 'UTF-8');
        if fid < 0, errordlg(['Impossibile scrivere il file: ' f], 'Tempi dei passi'); return; end
        fprintf(fid, 'passo;inizio;fine;descrizione\n');
        for k = 1:numel(T), fprintf(fid, '%d;%s;%s;%s\n', k, fmtTime(T(k)), fmtTime(E(k)), strrep(cueText(sc, k), ';', ',')); end
        fclose(fid);
        S.cueT = T; S.cueEnd = E;
    end

    function t = snapBeat(t)
        if isempty(S.onsets), return; end
        [d, i] = min(abs(S.onsets - t)); if d < 0.2, t = S.onsets(i); end
    end

    function recordCues()
        if S.rec, stopRecording(true); return; end
        if S.running || S.syncing, return; end
        sc = curScene(); n = numel(sc.steps);
        if n == 0, msgbox('Questa scena non ha passi da sincronizzare.', 'Registra'); return; end
        resetScene(); stopMusic();
        if ~loadPlayer(), return; end
        loadCues();
        S.rec = true; S.recT = nan(1, n); tok = S.token;
        set(S.hRec, 'String', [char(9632) ' Stop'], 'ForegroundColor', [0.75 0.1 0.1]);
        set(S.hRec, 'Enable', 'off'); drawnow; set(S.hRec, 'Enable', 'on');
        figure(figScene);
        set(S.hComment, 'String', {['REGISTRAZIONE TEMPI ' char(8212) ' ' sc.title]; ...
            'Premi la BARRA SPAZIATRICE nel momento in cui deve partire ogni passo (il passo parte subito).'; ...
            sprintf('Passi da segnare: %d.   Esc oppure "Stop" per terminare e salvare.', n); ''; ['Prossimo: 1  ' cueText(sc, 1)]});
        play(S.player);
        while S.rec && tok == S.token && ishandle(figScene)
            done = sum(~isnan(S.recT));
            if done > S.step && ~S.running
                runStep();
                if S.step < n, set(S.hComment, 'String', [get(S.hComment, 'String'); {''; sprintf('Prossimo: %d  %s', S.step + 1, cueText(sc, S.step + 1))}]); end
            end
            if S.step >= n && ~S.running, pause(0.5); stopRecording(true); break; end
            if ~isempty(S.player) && isobject(S.player) && ~isplaying(S.player) && ~S.running && done == S.step, stopRecording(true); break; end
            pause(0.03);
        end
    end

    function markCue()
        if ~S.rec || isempty(S.player) || ~isobject(S.player), return; end
        k = find(isnan(S.recT), 1); if isempty(k), return; end
        t = (get(S.player, 'CurrentSample') - 1) / S.fs; if S.snap, t = snapBeat(t); end
        S.recT(k) = t;
    end

    function stopRecording(doSave)
        if ~S.rec, return; end
        S.rec = false;
        if ~isempty(S.player) && isobject(S.player), try, stop(S.player); catch, end, end
        if ishandle(S.hRec), set(S.hRec, 'String', [char(9679) ' Registra'], 'ForegroundColor', [0 0 0]); end
        done = sum(~isnan(S.recT));
        if doSave && done > 0
            E = nan(size(S.recT)); if numel(S.cueEnd) == numel(S.recT), E = S.cueEnd; end
            saveCues(S.recT, E);
            set(S.hComment, 'String', [get(S.hComment, 'String'); {''; sprintf('Salvati %d tempi su %d.', done, numel(S.recT)); ...
                'Apri "Tempi passi" per correggerli. "Sync" ora segue questi tempi.'}]);
            set(S.hMusic, 'String', [get(S.hMusic, 'String') '  (tempi registrati)']);
        end
    end

    function openCueTable()
        sc = curScene(); n = numel(sc.steps);
        if n == 0, msgbox('Questa scena non ha passi.', 'Tempi dei passi'); return; end
        loadCues(); T = nan(1, n); E = nan(1, n);
        if ~isempty(S.cueT), T = S.cueT; E = S.cueEnd; end
        if ~isempty(S.cueFig) && ishandle(S.cueFig), delete(S.cueFig); end
        f = figure('Name', ['Tempi dei passi ' char(8212) ' ' sc.title], 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', ...
            'ToolBar', 'none', 'Units', 'normalized', 'Position', [0.22 0.15 0.56 0.66]);
        S.cueFig = f; sel = 1;
        uicontrol(f, 'Style', 'text', 'String', {'Tempi nel formato mm:ss.d (es. 01:12.4).  Seleziona una riga e usa i pulsanti per spostarla.'; ...
            '"Fine" vuota = durata scritta nel passo; se la scrivi, il movimento dura fino a quel momento.'}, ...
            'ForegroundColor', GOLD, 'BackgroundColor', BG, 'FontSize', 10, 'Units', 'normalized', 'Position', [0.02 0.915 0.96 0.075]);
        tb = uitable(f, 'Units', 'normalized', 'Position', [0.02 0.17 0.96 0.74], 'ColumnName', {'Passo', 'Inizio', 'Fine', 'Descrizione'}, ...
            'ColumnFormat', {'numeric', 'char', 'char', 'char'}, 'ColumnEditable', [false true true false], ...
            'ColumnWidth', {50, 90, 90, 560}, 'RowName', [], 'FontSize', 11, 'Data', makeData(), ...
            'CellEditCallback', @cellEdit, 'CellSelectionCallback', @cellSel);
        pb = @(str, x, y, w, cb) uicontrol(f, 'Style', 'pushbutton', 'String', str, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x y w 0.06], 'Callback', cb);
        pb([char(9664) ' 0,5 s'], 0.02, 0.09, 0.09, @(~,~) nudge(-0.5));
        pb([char(9664) ' 0,1 s'], 0.12, 0.09, 0.09, @(~,~) nudge(-0.1));
        pb(['0,1 s ' char(9654)], 0.22, 0.09, 0.09, @(~,~) nudge(+0.1));
        pb(['0,5 s ' char(9654)], 0.32, 0.09, 0.09, @(~,~) nudge(+0.5));
        pb([char(9654) ' Ascolta da questo passo'], 0.42, 0.09, 0.21, @(~,~) listenFrom());
        pb('Aggancia alle battute', 0.64, 0.09, 0.165, @(~,~) snapAll());
        pb('Riempi i vuoti', 0.815, 0.09, 0.165, @(~,~) fillGaps());
        pb('Salva', 0.02, 0.015, 0.19, @(~,~) doSave());
        pb('Chiudi', 0.79, 0.015, 0.19, @(~,~) delete(f));
        st = uicontrol(f, 'Style', 'text', 'String', '', 'ForegroundColor', TXT, 'BackgroundColor', BG, 'FontSize', 10, ...
            'Units', 'normalized', 'Position', [0.23 0.02 0.54 0.045]);
        function C = makeData()
            C = cell(n, 4);
            for kk = 1:n, C{kk, 1} = kk; C{kk, 2} = fmtTime(T(kk)); C{kk, 3} = fmtTime(E(kk)); C{kk, 4} = cueText(sc, kk); end
        end
        function refresh(m), set(tb, 'Data', makeData()); set(st, 'String', m); end
        function cellEdit(~, ev)
            r = ev.Indices(1); cc = ev.Indices(2); v = parseTime(ev.NewData);
            if cc == 2, T(r) = v; else, E(r) = v; end
            sel = r; refresh('Modificato (premi Salva)');
        end
        function cellSel(~, ev), if ~isempty(ev.Indices), sel = ev.Indices(1, 1); end, end
        function nudge(d)
            if isnan(T(sel)), set(st, 'String', 'Questo passo non ha ancora un tempo'); return; end
            T(sel) = max(0, T(sel) + d); if ~isnan(E(sel)), E(sel) = E(sel) + d; end
            refresh(sprintf('Passo %d  %s  (premi Salva)', sel, fmtTime(T(sel))));
        end
        function doSave()
            saveCues(T, E); refresh('Salvato');
            if ishandle(S.hMusic) && isempty(strfind(get(S.hMusic, 'String'), 'registrati')) %#ok<STREMP>
                set(S.hMusic, 'String', [get(S.hMusic, 'String') '  (tempi registrati)']);
            end
        end
        function listenFrom(), doSave(); if ishandle(figScene), figure(figScene); end; syncMontaggio(sel); end
        function snapAll()
            if isempty(S.onsets) && ~loadPlayer(), return; end
            for kk = 1:n, if ~isnan(T(kk)), T(kk) = snapBeat(T(kk)); end, end
            refresh('Tempi agganciati all''attacco musicale piu'' vicino (premi Salva)');
        end
        function fillGaps()
            if S.dur <= 0 && ~loadPlayer(), return; end
            T = fillCues(T, S.dur); refresh('Passi senza tempo riempiti tra quelli vicini (premi Salva)');
        end
    end

% =====================================================================
%                 ELENCO PASSI: modifica, elimina, aggiungi
% =====================================================================
    function commitScene(sc)
        n = numel(sc.steps);
        sc.cues = padCell(sc.cues, n); sc.ens = padCell(sc.ens, n);
        sc.cues = sc.cues(1:n); sc.ens = sc.ens(1:n);
        sc = pruneObjs(sc);
        SH.scenes{S.idx} = sc; saveShow();
        goScene(S.idx); refreshShow();
    end

    function openStepList()
        if S.running || S.syncing || S.rec, return; end
        sc = curScene();
        if ~isempty(S.stepFig) && ishandle(S.stepFig), delete(S.stepFig); end
        f = figure('Name', ['Elenco passi ' char(8212) ' ' sc.title], 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', ...
            'ToolBar', 'none', 'Units', 'normalized', 'Position', [0.2 0.12 0.52 0.72]);
        S.stepFig = f;
        uicontrol(f, 'Style', 'text', 'String', {['Passi della scena: ' sc.title]; 'Doppio clic su un passo per modificarlo.'}, ...
            'ForegroundColor', GOLD, 'BackgroundColor', BG, 'FontSize', 10, 'Units', 'normalized', 'Position', [0.02 0.91 0.96 0.08]);
        lb = uicontrol(f, 'Style', 'listbox', 'FontSize', 11, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, 'Units', 'normalized', ...
            'Position', [0.02 0.2 0.96 0.7], 'Callback', @lbClick);
        pb = @(str, x, y, w, cb) uicontrol(f, 'Style', 'pushbutton', 'String', str, 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x y w 0.06], 'Callback', cb);
        h = pb('+ Aggiungi passo', 0.02, 0.11, 0.18, @(~,~) addStep()); set(h, 'FontWeight', 'bold');
        pb('Modifica', 0.21, 0.11, 0.14, @(~,~) editStep());
        pb('Elimina', 0.36, 0.11, 0.12, @(~,~) delStep());
        pb([char(9650) ' Su'], 0.49, 0.11, 0.10, @(~,~) moveStep(-1));
        pb([char(9660) ' Gi' char(249)], 0.60, 0.11, 0.10, @(~,~) moveStep(+1));
        pb([char(9654) ' Prova il passo'], 0.71, 0.11, 0.27, @(~,~) tryStep());
        h = pb([char(9113) ' Salva PDF'], 0.02, 0.025, 0.2, @(~,~) exportStepsPdf());
        set(h, 'FontWeight', 'bold', 'TooltipString', 'PDF: titolo e passi, poi la scena vista dalla platea');
        pb('Chiudi', 0.78, 0.025, 0.20, @(~,~) delete(f));
        stt = uicontrol(f, 'Style', 'text', 'String', '', 'ForegroundColor', TXT, 'BackgroundColor', BG, 'FontSize', 9, ...
            'Units', 'normalized', 'Position', [0.24 0.03 0.52 0.045]);
        fillList();
        function fillList()
            sc = curScene(); n = numel(sc.steps); items = cell(max(n, 1), 1);
            for kk = 1:n, items{kk} = sprintf('%2d.  %s   [%s]', kk, cueText(sc, kk), actSummary(sc, kk)); end
            if n == 0, items = {'(nessun passo: premi "+ Aggiungi passo")'}; end
            v = get(lb, 'Value'); if isempty(v) || v > numel(items), v = numel(items); end
            set(lb, 'String', items, 'Value', max(1, v));
        end
        function k = selK()
            k = get(lb, 'Value'); if numel(curScene().steps) == 0, k = 0; end
        end
        function lbClick(~, ~), if strcmp(get(f, 'SelectionType'), 'open'), editStep(); end, end
        function addStep(), stepEditor(selK() + 1, true, @afterEdit); end
        function editStep(), k = selK(); if k < 1, return; end; stepEditor(k, false, @afterEdit); end
        function afterEdit(k)
            if ~ishandle(f), return; end
            fillList(); set(lb, 'Value', max(1, k)); set(stt, 'String', sprintf('Passo %d salvato.', k));
        end
        function delStep()
            k = selK(); if k < 1, return; end
            a = questdlg(sprintf('Eliminare il passo %d?', k), 'Elimina passo', 'Elimina', 'Annulla', 'Annulla');
            if ~strcmp(a, 'Elimina'), return; end
            sc = curScene(); n = numel(sc.steps); sc.cues = padCell(sc.cues, n); sc.ens = padCell(sc.ens, n);
            sc.steps(k) = []; sc.cues(k) = []; sc.ens(k) = [];
            commitScene(sc); fillList(); set(stt, 'String', sprintf('Passo %d eliminato.', k));
        end
        function moveStep(d)
            k = selK(); sc = curScene(); j = k + d; n = numel(sc.steps);
            if k < 1 || j < 1 || j > n, return; end
            sc.cues = padCell(sc.cues, n); sc.ens = padCell(sc.ens, n);
            sc.steps([k j]) = sc.steps([j k]); sc.cues([k j]) = sc.cues([j k]); sc.ens([k j]) = sc.ens([j k]);
            commitScene(sc); fillList(); set(lb, 'Value', j);
        end
        function tryStep()
            k = selK(); if k < 1, return; end
            if ishandle(figScene), figure(figScene); end
            resetScene(); fastForward(k - 1); runStep();
        end
    end

    function stepEditor(k, isNew, doneFcn)
        sc = curScene(); T = SH.theater;
        eff = struct('cls', {}, 'spid', {}, 'pts', {}, 'dur', {}, 'delay', {}); desc = ''; ens = '';
        if ~isNew
            eff = sc.steps{k}; desc = cueText(sc, k);
            if k <= numel(sc.ens) && ~isempty(sc.ens{k}), ens = sc.ens{k}; end
        end
        objs = sc.objects; st0 = stateAt(sc, k - 1); cast = sc.cast;
        P = zeros(0, 2); drawing = false; startPt = []; hPath = []; hStart = [];
        % chi/cosa si puo' muovere
        tgK = {}; tgR = {}; tgN = {};
        for q = 1:numel(SH.chars), tgK{end+1} = 'char'; tgR{end+1} = SH.chars(q).name; tgN{end+1} = SH.chars(q).name; end %#ok<AGROW>
        for q = 1:numel(SH.elements)
            if SH.elements(q).fixed, continue; end
            tgK{end+1} = 'el'; tgR{end+1} = SH.elements(q).name; tgN{end+1} = ['Elemento: ' SH.elements(q).name]; %#ok<AGROW>
        end
        if isempty(tgK), errordlg('Prima crea almeno un personaggio o un elemento scenico (finestra dello spettacolo).', 'Passo'); return; end
        FOL = SH.lights(strcmp({SH.lights.zone}, 'Segue un personaggio'));
        if isempty(FOL), FOL = newLight('Occhio di bue', 'Seguipersona (occhio di bue)', 1, 'Bianco', [1 1 0.95], 'Segue un personaggio'); end
        WL = SH.lights(~strcmp({SH.lights.zone}, 'Segue un personaggio'));

        g = figure('Name', sprintf('Passo %d %s %s', k, char(8212), sc.title), 'NumberTitle', 'off', 'Color', BG, 'MenuBar', 'none', ...
            'ToolBar', 'none', 'Units', 'normalized', 'Position', [0.04 0.06 0.9 0.86]);
        ax = axes('Parent', g, 'Units', 'normalized', 'Position', [0.01 0.11 0.55 0.86]);
        try, disableDefaultInteractivity(ax); catch, end %#ok<NOCOM>
        hint = uicontrol(g, 'Style', 'text', 'String', '', 'ForegroundColor', [1 .85 .45], 'BackgroundColor', BG, 'FontSize', 11, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0.02 0.01 0.53 0.08]);
        x0 = 0.58; w0 = 0.40;
        lbl = @(str, y) uicontrol(g, 'Style', 'text', 'String', str, 'ForegroundColor', GOLD, 'BackgroundColor', BG, 'FontSize', 10, ...
            'FontWeight', 'bold', 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 y w0 0.028]);
        txt = @(str, x, y, w) uicontrol(g, 'Style', 'text', 'String', str, 'ForegroundColor', TXT, 'BackgroundColor', BG, 'FontSize', 10, ...
            'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x y w 0.028]);
        lbl('Descrizione del passo', 0.962);
        edDesc = uicontrol(g, 'Style', 'edit', 'String', desc, 'FontSize', 11, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 0.922 w0 0.04]);
        lbl('Corpo di ballo / note (facoltativo)', 0.89);
        edEns = uicontrol(g, 'Style', 'edit', 'String', ens, 'FontSize', 10, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 0.855 w0 0.036]);
        lbl('Azioni di questo passo (tutte insieme, salvo il ritardo)', 0.822);
        lbA = uicontrol(g, 'Style', 'listbox', 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, 'Units', 'normalized', 'Position', [x0 0.69 w0 0.132]);
        uicontrol(g, 'Style', 'pushbutton', 'String', 'Elimina l''azione selezionata', 'Units', 'normalized', 'Position', [x0 0.652 w0 0.034], 'Callback', @(~,~) delAction());
        lbl('NUOVA AZIONE', 0.615);
        txt('Chi / cosa', x0, 0.578, 0.1);
        popC = uicontrol(g, 'Style', 'popupmenu', 'String', tgN, 'FontSize', 10, 'Units', 'normalized', 'Position', [x0 + 0.1 0.58 w0 - 0.1 0.032], 'Callback', @(~,~) newAction());
        txt('Azione', x0, 0.54, 0.1);
        popT = uicontrol(g, 'Style', 'popupmenu', 'String', {'Movimento', 'Entra in scena', 'Esce di scena'}, 'FontSize', 10, ...
            'Units', 'normalized', 'Position', [x0 + 0.1 0.542 w0 - 0.1 0.032], 'Callback', @(~,~) newAction());
        txt('Percorso', x0, 0.502, 0.1);
        popP = uicontrol(g, 'Style', 'popupmenu', 'String', {'Linea retta (clicca il punto di arrivo)', 'Percorso libero (tieni premuto e disegna)'}, ...
            'FontSize', 10, 'Units', 'normalized', 'Position', [x0 + 0.1 0.504 w0 - 0.1 0.032], 'Callback', @(~,~) newAction());
        txt('Luce che lo segue', x0, 0.464, 0.1);
        popL = uicontrol(g, 'Style', 'popupmenu', 'String', [{'Nessuna'}, {FOL.name}], 'FontSize', 10, 'Units', 'normalized', ...
            'Position', [x0 + 0.1 0.466 w0 - 0.1 0.032], 'TooltipString', 'Un occhio di bue che fa lo stesso percorso (si spegne quando il personaggio esce)');
        chkS = uicontrol(g, 'Style', 'checkbox', 'String', 'Scegli anche il punto di partenza (primo clic)', 'Value', 0, 'FontSize', 10, ...
            'ForegroundColor', TXT, 'BackgroundColor', BG, 'Units', 'normalized', 'Position', [x0 0.428 w0 0.032], 'Callback', @(~,~) newAction());
        txt('Durata (s)', x0, 0.39, 0.09);
        edDur = uicontrol(g, 'Style', 'edit', 'String', '2', 'FontSize', 10, 'Units', 'normalized', 'Position', [x0 + 0.09 0.39 0.07 0.034]);
        txt('Ritardo (s)', x0 + 0.2, 0.39, 0.09);
        edDel = uicontrol(g, 'Style', 'edit', 'String', '0', 'FontSize', 10, 'Units', 'normalized', 'Position', [x0 + 0.29 0.39 0.07 0.034], ...
            'TooltipString', 'Secondi di attesa dall''inizio del passo (0 = parte insieme alle altre azioni)');
        uicontrol(g, 'Style', 'pushbutton', 'String', '+   Aggiungi questa azione  (poi puoi farne un''altra in contemporanea)', ...
            'FontSize', 11, 'FontWeight', 'bold', 'Units', 'normalized', 'Position', [x0 0.335 w0 0.045], 'Callback', @(~,~) addAction());
        uicontrol(g, 'Style', 'pushbutton', 'String', 'Cancella il disegno', 'FontSize', 10, 'Units', 'normalized', 'Position', [x0 0.298 w0 0.032], 'Callback', @(~,~) newAction());
        lbl('LUCI GENERALI DEL PASSO (selezione multipla con Ctrl)', 0.258);
        lbW = uicontrol(g, 'Style', 'listbox', 'String', arrayfun(@(x) sprintf('%s  (%s, %s)', x.name, x.cname, x.zone), WL, 'UniformOutput', false), ...
            'Max', 2, 'Min', 0, 'FontSize', 10, 'BackgroundColor', PANEL, 'ForegroundColor', TXT, 'Units', 'normalized', 'Position', [x0 0.085 w0 * 0.6 0.17]);
        uicontrol(g, 'Style', 'pushbutton', 'String', 'Come il passo precedente', 'FontSize', 9, 'Units', 'normalized', ...
            'Position', [x0 + w0 * 0.62 0.2 w0 * 0.38 0.045], 'Callback', @(~,~) washPrev());
        uicontrol(g, 'Style', 'pushbutton', 'String', 'Buio (spegni tutto)', 'FontSize', 9, 'Units', 'normalized', ...
            'Position', [x0 + w0 * 0.62 0.145 w0 * 0.38 0.045], 'Callback', @(~,~) set(lbW, 'Value', []));
        uicontrol(g, 'Style', 'text', 'String', 'Le luci selezionate restano accese durante il passo.', 'FontSize', 8, 'ForegroundColor', DIM, ...
            'BackgroundColor', BG, 'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [x0 + w0 * 0.62 0.085 w0 * 0.38 0.055]);
        uicontrol(g, 'Style', 'pushbutton', 'String', 'Salva passo', 'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized', ...
            'Position', [x0 0.015 0.19 0.055], 'Callback', @(~,~) saveStep());
        uicontrol(g, 'Style', 'pushbutton', 'String', 'Annulla', 'FontSize', 11, 'Units', 'normalized', 'Position', [x0 + 0.21 0.015 0.19 0.055], 'Callback', @(~,~) delete(g));
        set(g, 'WindowButtonDownFcn', @(~,~) mDown(), 'WindowButtonMotionFcn', @(~,~) mMove(), 'WindowButtonUpFcn', @(~,~) mUp());
        washSel(); drawPlan(); showActions(); newAction();

        function msg(str), if ishandle(hint), set(hint, 'String', str); end, end
        function ip = tgIndex(t)
            ip = [];
            if isempty(objs), return; end
            ip = find(strcmp({objs.kind}, tgK{t}) & strcmp({objs.ref}, tgR{t}), 1);
        end
        function c = curPos(ip)
            c = st0(ip, 1:2);
            for jj = 1:numel(eff)
                if eff(jj).spid == objs(ip).id && strcmp(eff(jj).cls, 'path'), c = eff(jj).pts(end, :); end
            end
        end
        function a = curVis(ip)
            a = st0(ip, 3) > 0.5;
            for jj = 1:numel(eff)
                if eff(jj).spid == objs(ip).id
                    if strcmp(eff(jj).cls, 'entr'), a = true; elseif strcmp(eff(jj).cls, 'exit'), a = false; end
                end
            end
        end
        function ip = addObj(o)
            objs(end+1) = o; st0(end+1, :) = [0 0 0]; ip = numel(objs);
        end
        function ip = addTarget(t, pt)
            if strcmp(tgK{t}, 'char')
                ci = find(strcmp({SH.chars.name}, tgR{t}), 1);
                ip = addObj(newObj(newUid(), 'char', tgR{t}, tgR{t}, pt(1), pt(2), SH.chars(ci).pawn, '', 0, 0, 0, false));
                cast = setCast(struct('cast', cast), tgR{t}, castCode(struct('cast', cast), tgR{t})); cast = cast.cast;
            else
                e = SH.elements(strcmp({SH.elements.name}, tgR{t}));
                ip = addObj(newObj(newUid(), 'el', e.name, e.name, pt(1), pt(2), planColor(e), '', e.size(1), e.size(2), 0, false));
            end
        end
        function ip = lightObj(L, label, center)
            ip = [];
            for q1 = 1:numel(objs)
                if strcmp(objs(q1).kind, 'light') && strcmp(objs(q1).label, label), ip = q1; return; end
            end
            ip = addObj(newObj(newUid(), 'light', L.name, label, center(1), center(2), L.rgb, L.zone, 0, 0, 0, false));
        end
        function drawPlan()
            cla(ax); stagePlan(ax, false); hold(ax, 'on'); drawFixed2D(ax);
            for pass = {'light', 'el', 'char'}
                for ii = 1:numel(objs)
                    o = objs(ii);
                    if ~strcmp(o.kind, pass{1}) || ~curVis(ii), continue; end
                    if strcmp(o.kind, 'light') && ~strcmp(o.zone, 'Segue un personaggio'), continue; end
                    p = curPos(ii); G = make2D(ax, o); set(G.h, 'Matrix', makehgtform('translate', [o.x + p(1), o.y + p(2), G.z]));
                end
            end
            for jj = 1:numel(eff)
                if ~strcmp(eff(jj).cls, 'path'), continue; end
                ii = find([objs.id] == eff(jj).spid, 1); if isempty(ii) || strcmp(objs(ii).kind, 'light'), continue; end
                q2 = eff(jj).pts + repmat([objs(ii).x objs(ii).y], size(eff(jj).pts, 1), 1);
                cc = objs(ii).rgb;
                plot(ax, q2(:, 1), q2(:, 2), '-', 'LineWidth', 2, 'Color', cc, 'HitTest', 'off');
                plot(ax, q2(end, 1), q2(end, 2), 's', 'MarkerSize', 8, 'MarkerFaceColor', cc, 'MarkerEdgeColor', 'w', 'HitTest', 'off');
            end
            hPath = plot(ax, NaN, NaN, '-', 'LineWidth', 3, 'Color', [1 .85 .3], 'HitTest', 'off');
            hStart = plot(ax, NaN, NaN, 'o', 'MarkerSize', 18, 'LineWidth', 2, 'Color', [1 .85 .3], 'HitTest', 'off');
            hold(ax, 'off');
            title(ax, 'Pianta del palco  (pubblico in basso)', 'Color', GOLD);
        end
        function showActions()
            items = cell(numel(eff), 1);
            for jj = 1:numel(eff)
                ii = find([objs.id] == eff(jj).spid, 1); nm = '?';
                if ~isempty(ii), nm = objs(ii).label; end
                switch eff(jj).cls
                    case 'path', v = sprintf('si muove (%d punti)', size(eff(jj).pts, 1));
                    case 'entr', v = 'entra / si accende';
                    otherwise, v = 'esce / si spegne';
                end
                items{jj} = sprintf('%s: %s  %s  %.1f s, ritardo %.1f s', nm, v, char(8212), eff(jj).dur, eff(jj).delay);
            end
            if isempty(items), items = {'(nessuna azione)'}; end
            set(lbA, 'String', items, 'Value', 1);
        end
        function delAction()
            v = get(lbA, 'Value'); if isempty(eff) || v > numel(eff), return; end
            eff(v) = []; showActions(); drawPlan(); newAction();
        end
        function newAction()
            P = zeros(0, 2); drawing = false; startPt = [];
            if ~isempty(hPath) && ishandle(hPath), set(hPath, 'XData', NaN, 'YData', NaN); end
            t = get(popC, 'Value'); ip = tgIndex(t); ty = get(popT, 'Value'); nm = tgR{t};
            if ~isempty(ip) && ~curVis(ip) && ty ~= 2, ip = []; end
            if ~isempty(hStart) && ishandle(hStart)
                if ~isempty(ip), p = [objs(ip).x objs(ip).y] + curPos(ip); set(hStart, 'XData', p(1), 'YData', p(2));
                else, set(hStart, 'XData', NaN, 'YData', NaN); end
            end
            switch ty
                case 1
                    if isempty(ip), msg([nm ' non ' char(232) ' in scena: clicca dove compare, poi indica il percorso.']);
                    elseif get(chkS, 'Value') == 1, msg('Primo clic: punto di partenza. Poi indica il percorso.');
                    elseif get(popP, 'Value') == 1, msg(['Clicca sulla pianta il punto di arrivo (il cerchio giallo ' char(232) ' la partenza).']);
                    else, msg('Tieni premuto il mouse sulla pianta e disegna il percorso, poi rilascia.'); end
                case 2, msg('Clicca dove deve comparire (es. in una quinta). Poi premi "+ Aggiungi questa azione".');
                case 3, msg('Premi "+ Aggiungi questa azione": esce dalla posizione in cui si trova.');
            end
        end
        function pt = planPoint()
            pt = []; cp = get(ax, 'CurrentPoint'); x = cp(1, 1); y = cp(1, 2);
            xl = get(ax, 'XLim'); yl = get(ax, 'YLim');
            if x >= xl(1) && x <= xl(2) && y >= yl(1) && y <= yl(2), pt = [x y]; end
        end
        function mDown()
            pt = planPoint(); if isempty(pt), return; end
            t = get(popC, 'Value'); ty = get(popT, 'Value'); ip = tgIndex(t);
            if ~isempty(ip) && ~curVis(ip), ipv = []; else, ipv = ip; end
            needStart = isempty(ipv) || get(chkS, 'Value') == 1 || ty == 2;
            if needStart && isempty(startPt)
                startPt = pt; set(hStart, 'XData', pt(1), 'YData', pt(2));
                if ty == 2, msg('Punto scelto. Premi "+ Aggiungi questa azione".'); else, msg('Partenza scelta: ora indica il percorso.'); end
                return
            end
            if ty ~= 1, return; end
            s0 = startPt; if isempty(s0), s0 = [objs(ip).x objs(ip).y] + curPos(ip); end
            P = [s0; pt]; drawing = (get(popP, 'Value') == 2);
            set(hPath, 'XData', P(:, 1), 'YData', P(:, 2));
            if ~drawing, msg('Percorso pronto: regola durata e ritardo, poi premi "+ Aggiungi questa azione".'); end
        end
        function mMove()
            if ~drawing, return; end
            pt = planPoint(); if isempty(pt), return; end
            if norm(pt - P(end, :)) > 0.05, P(end+1, :) = pt; set(hPath, 'XData', P(:, 1), 'YData', P(:, 2)); end
        end
        function mUp()
            if drawing, drawing = false; msg('Percorso disegnato: premi "+ Aggiungi questa azione" (o "Cancella il disegno").'); end
        end
        function addAction()
            t = get(popC, 'Value'); ty = get(popT, 'Value'); nm = tgR{t};
            du = str2double(strrep(get(edDur, 'String'), ',', '.')); if isnan(du) || du <= 0, du = 1.5; end
            dl = str2double(strrep(get(edDel, 'String'), ',', '.')); if isnan(dl) || dl < 0, dl = 0; end
            ip = tgIndex(t);
            if ty == 1 && size(P, 1) < 2, msg('Prima indica il movimento sulla pianta.'); return; end
            if isempty(ip) || ~curVis(ip)
                if ty == 3, msg([nm ' non ' char(232) ' in scena.']); return; end
                if isempty(startPt), msg(['Clicca sulla pianta il punto in cui compare: ' nm]); return; end
                if isempty(ip), ip = addTarget(t, startPt); end
                o = objs(ip);
                eff(end+1) = mkEff('path', o.id, [curPos(ip); startPt - [o.x o.y]], 0.01, dl);
                eff(end+1) = mkEff('entr', o.id, [], 0.5, dl);
                if ty == 1, dl = dl + 0.5; end
                if ty == 2, ty = 0; end
            end
            o = objs(ip); org = [o.x o.y];
            switch ty
                case 1
                    eff(end+1) = mkEff('path', o.id, simplifyPath(P - repmat(org, size(P, 1), 1)), du, dl);
                case 2
                    if ~isempty(startPt), eff(end+1) = mkEff('path', o.id, [curPos(ip); startPt - org], 0.01, dl); end
                    eff(end+1) = mkEff('entr', o.id, [], du, dl);
                case 3
                    eff(end+1) = mkEff('exit', o.id, [], du, dl);
                    for ii = 1:numel(objs)
                        if strcmp(objs(ii).kind, 'light') && ~isempty(regexp(objs(ii).label, [' su ' regexptranslate('escape', o.label) '$'], 'once')) && curVis(ii)
                            eff(end+1) = mkEff('exit', objs(ii).id, [], du, dl); %#ok<AGROW>
                        end
                    end
            end
            sp = get(popL, 'Value');
            if sp > 1 && ty == 1
                L = FOL(sp - 1); lab = [L.name ' su ' o.label];
                il = lightObj(L, lab, P(1, :));
                lo = objs(il); lorg = [lo.x lo.y];
                if ~curVis(il)
                    eff(end+1) = mkEff('path', lo.id, [curPos(il); P(1, :) - lorg], 0.01, max(0, dl - 0.5));
                    eff(end+1) = mkEff('entr', lo.id, [], 0.5, max(0, dl - 0.5));
                end
                eff(end+1) = mkEff('path', lo.id, simplifyPath(P - repmat(lorg, size(P, 1), 1)), du, dl);
            end
            showActions(); drawPlan(); newAction();
            msg('Azione aggiunta. Scegli un altro personaggio o elemento per farlo muovere in contemporanea, oppure "Salva passo".');
        end
        function wi = washObj(q3)
            wi = [];
            for ii = 1:numel(objs)
                if strcmp(objs(ii).kind, 'light') && strcmp(objs(ii).label, WL(q3).name), wi = ii; return; end
            end
        end
        function washSel()
            v = [];
            for q3 = 1:numel(WL)
                wi = washObj(q3); if ~isempty(wi) && curVis(wi), v(end+1) = q3; end %#ok<AGROW>
            end
            set(lbW, 'Value', v);
        end
        function washPrev()
            v = [];
            for q3 = 1:numel(WL)
                wi = washObj(q3); if ~isempty(wi) && st0(wi, 3) > 0.5, v(end+1) = q3; end %#ok<AGROW>
            end
            set(lbW, 'Value', v);
        end
        function applyWash()
            sel = get(lbW, 'Value');
            keep = true(1, numel(eff));
            for jj = 1:numel(eff)
                ii = find([objs.id] == eff(jj).spid, 1);
                if ~isempty(ii) && strcmp(objs(ii).kind, 'light') && ~strcmp(objs(ii).zone, 'Segue un personaggio') && any(strcmp(eff(jj).cls, {'entr', 'exit'}))
                    keep(jj) = false;
                end
            end
            eff = eff(keep);
            for q3 = 1:numel(WL)
                on = any(sel == q3); wi = washObj(q3);
                before = ~isempty(wi) && st0(wi, 3) > 0.5;
                if on && ~before
                    if isempty(wi), gz = zoneGeom(WL(q3).zone, T, [0 0]); wi = lightObj(WL(q3), WL(q3).name, [gz.cx gz.cy]); end
                    eff(end+1) = mkEff('entr', objs(wi).id, [], 1.2, 0); %#ok<AGROW>
                elseif ~on && before
                    eff(end+1) = mkEff('exit', objs(wi).id, [], 1.2, 0); %#ok<AGROW>
                end
            end
        end
        function saveStep()
            applyWash();
            sc2 = curScene(); sc2.objects = objs; sc2.cast = cast; n = numel(sc2.steps);
            sc2.cues = padCell(sc2.cues, n); sc2.ens = padCell(sc2.ens, n);
            dsc = strtrim(get(edDesc, 'String')); if isempty(dsc), dsc = sprintf('passo %d', k); end
            en = strtrim(get(edEns, 'String'));
            if isNew
                sc2.steps = [sc2.steps(1:k-1), {eff}, sc2.steps(k:end)];
                sc2.cues = [sc2.cues(1:k-1), {dsc}, sc2.cues(k:end)];
                sc2.ens = [sc2.ens(1:k-1), {en}, sc2.ens(k:end)];
            else
                sc2.steps{k} = eff; sc2.cues{k} = dsc; sc2.ens{k} = en;
            end
            delete(g); commitScene(sc2);
            if ~isempty(doneFcn), doneFcn(k); end
        end
    end

    function s = actSummary(sc, k)
        e = sc.steps{k}; nm = {};
        ids = []; if ~isempty(sc.objects), ids = [sc.objects.id]; end
        for j = 1:numel(e)
            i = find(ids == e(j).spid, 1); if isempty(i), continue; end
            o = sc.objects(i);
            if strcmp(o.kind, 'light')
                switch e(j).cls, case 'entr', v = 'si accende'; case 'exit', v = 'si spegne'; otherwise, v = 'si sposta'; end
                nm{end+1} = ['luce ' o.label ' ' v]; %#ok<AGROW>
            else
                switch e(j).cls, case 'entr', v = 'entra'; case 'exit', v = 'esce'; otherwise, v = 'si muove'; end
                nm{end+1} = [o.label ' ' v]; %#ok<AGROW>
            end
        end
        if isempty(nm), s = 'nessuna azione'; else, s = strjoin(unique(nm, 'stable'), ', '); end
    end

    function L = actionLines(sc, k)
        e = sc.steps{k}; L = {}; T = SH.theater;
        ids = []; if ~isempty(sc.objects), ids = [sc.objects.id]; end
        for j = 1:numel(e)
            i = find(ids == e(j).spid, 1); if isempty(i), continue; end
            o = sc.objects(i); nm = o.label;
            if strcmp(o.kind, 'light')
                if strcmp(e(j).cls, 'path') && e(j).dur < 0.05, continue; end
                switch e(j).cls, case 'entr', v = 'si accende'; case 'exit', v = 'si spegne'; otherwise, v = 'segue il percorso'; end
                s = ['Luce ' nm ': ' v];
            else
                switch e(j).cls
                    case 'entr', v = 'entra in scena';
                    case 'exit', v = 'esce di scena';
                    otherwise
                        if e(j).dur < 0.05, continue; end
                        p1 = [o.x o.y] + e(j).pts(end, :); v = ['va verso ' zoneName(p1, T)];
                        if size(e(j).pts, 1) > 2, v = [v ' (percorso libero)']; end
                end
                s = [nm ': ' v];
            end
            s = sprintf('%s  (%.1f s', s, e(j).dur);
            if e(j).delay > 0, s = sprintf('%s, dopo %.1f s', s, e(j).delay); end
            L{end+1} = strrep([s ')'], '.', ','); %#ok<AGROW>
        end
        if isempty(L), L = {'(nessuna azione)'}; end
    end

% =====================================================================
%                              PDF
% =====================================================================
    function R = sceneRows(sc, Tc)
        % righe di testo di una scena: 'h' passo, 'd' azione, 'b' corpo di ballo, 'i' informazione, 'g' spazio
        R = cell(0, 2);
        if ~isempty(sc.start), W = wrapText(['Situazione iniziale: ' sc.start], 92); for w = 1:numel(W), R(end+1, :) = {W{w}, 'i'}; end, end %#ok<AGROW>
        cs = {};
        for q = 1:numel(sc.objects)
            o = sc.objects(q);
            if ~strcmp(o.kind, 'char') || any(strcmp(cs, o.ref)), continue; end
            cs{end+1} = o.ref; %#ok<AGROW>
        end
        if ~isempty(cs)
            parts = cell(1, numel(cs));
            for q = 1:numel(cs)
                code = castCode(sc, cs{q}); ci = find(strcmp({SH.chars.name}, cs{q}), 1); d = '';
                if ~isempty(ci)
                    j = find(strcmp({SH.chars(ci).costumes.code}, code), 1);
                    if ~isempty(j), d = SH.chars(ci).costumes(j).desc; end
                end
                parts{q} = sprintf('%s (costume %s%s)', cs{q}, code, iff(isempty(d), '', [': ' d]));
            end
            W = wrapText(['Personaggi: ' strjoin(parts, ', ')], 92); for w = 1:numel(W), R(end+1, :) = {W{w}, 'i'}; end %#ok<AGROW>
        end
        if ~isempty(R), R(end+1, :) = {'', 'g'}; end
        n = numel(sc.steps);
        for k = 1:n
            t = sprintf('Passo %d  %s  %s', k, char(8212), cueText(sc, k));
            if numel(Tc) >= k && ~isnan(Tc(k)), t = [t '   [' fmtTime(Tc(k)) ']']; end
            W = wrapText(t, 78); for w = 1:numel(W), R(end+1, :) = {W{w}, 'h'}; end %#ok<AGROW>
            ac = actionLines(sc, k);
            for a = 1:numel(ac)
                W = wrapText(ac{a}, 92); for w = 1:numel(W), R(end+1, :) = {['     ' W{w}], 'd'}; end %#ok<AGROW>
            end
            if k <= numel(sc.ens) && ~isempty(sc.ens{k})
                W = wrapText(['Corpo di ballo / note: ' sc.ens{k}], 92); for w = 1:numel(W), R(end+1, :) = {['     ' W{w}], 'b'}; end %#ok<AGROW>
            end
            R(end+1, :) = {'', 'g'}; %#ok<AGROW>
        end
        if n == 0, R(end+1, :) = {'Nessun passo in questa scena.', 'd'}; end
    end

    function jp = renderPages(R, header, footer, tmpd, jp, hw)
        % impagina le righe R su fogli A4 verticali (JPEG); header = {titolo, sottotitolo}
        i = 1; first = true;
        while i <= size(R, 1) || first
            f = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', 'Position', [20 20 620 877], ...
                'PaperUnits', 'centimeters', 'PaperSize', [21 29.7], 'PaperPositionMode', 'manual', 'PaperPosition', [0 0 21 29.7], 'InvertHardcopy', 'off');
            axp = axes('Parent', f, 'Units', 'normalized', 'Position', [0 0 1 1], 'XLim', [0 21], 'YLim', [0 29.7], 'YDir', 'reverse', 'Visible', 'off');
            hold(axp, 'on');
            tt = @(x, y, s, varargin) text(x, y, s, 'Parent', axp, 'Interpreter', 'none', varargin{:});
            y = 2.0;
            if first
                tt(10.5, 1.8, header{1}, 'FontSize', 22, 'FontWeight', 'bold', 'Color', [0.45 0.30 0.05], 'HorizontalAlignment', 'center');
                tt(10.5, 2.8, header{2}, 'FontSize', 12, 'Color', [0.2 0.2 0.2], 'HorizontalAlignment', 'center');
                plot(axp, [2 19], [3.5 3.5], '-', 'Color', [0.8 0.7 0.5]);
                y = 4.3; first = false;
            end
            while i <= size(R, 1) && y < 27.6
                tx = R{i, 1};
                switch R{i, 2}
                    case 'h', tt(2, y, tx, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1]); y = y + 0.55;
                    case 'd', tt(2, y, tx, 'FontSize', 9.5, 'Color', [0.22 0.22 0.22]); y = y + 0.45;
                    case 'b', tt(2, y, tx, 'FontSize', 9.5, 'FontAngle', 'italic', 'Color', [0.35 0.22 0.45]); y = y + 0.45;
                    case 'i', tt(2, y, tx, 'FontSize', 10, 'Color', [0.3 0.25 0.15]); y = y + 0.48;
                    case 's', tt(2.5, y, tx, 'FontSize', 11, 'Color', [0.15 0.15 0.15]); y = y + 0.6;
                    otherwise, y = y + 0.3;
                end
                i = i + 1;
            end
            pg = numel(jp) + 1;
            tt(19, 28.7, sprintf('%s  %s  pag. %d', footer, char(8212), pg), 'FontSize', 8, 'Color', [0.5 0.5 0.5], 'HorizontalAlignment', 'right');
            jp{end+1} = fullfile(tmpd, sprintf('p%04d.jpg', pg)); %#ok<AGROW>
            print(f, jp{end}, '-djpeg95', '-r150', '-opengl');
            delete(f);
            if ~isempty(hw) && ishandle(hw), waitbar(min(1, i / max(size(R, 1), 1)), hw); end
        end
    end

    function exportStepsPdf()
        sc = curScene();
        def = regexprep(sprintf('Atto %s - Scena %d - %s', roman(sc.act), sc.num, sc.title), '[\\/:*?"<>|]', '');
        [fnm, pth] = uiputfile({'*.pdf', 'PDF (*.pdf)'}, 'Salva l''elenco dei passi in PDF', fullfile(showDir, [def '.pdf']));
        if isequal(fnm, 0), return; end
        out = fullfile(pth, fnm);
        loadCues(); R = sceneRows(sc, S.cueT);
        n = numel(sc.steps);
        stv = stateAt(sc, 0);
        for m = 1:n
            sm = stateAt(sc, m);
            for ii = 1:size(stv, 1), if stv(ii, 3) < 0.5 && sm(ii, 3) > 0.5, stv(ii, :) = sm(ii, :); end, end
        end
        tmpd = tempname; mkdir(tmpd);
        hwt = waitbar(0, 'Creo il PDF...');
        try
            jp = renderPages(R, {sc.title, sprintf('Atto %s   %s   Scena %d   %s   %s', roman(sc.act), char(183), sc.num, char(183), SH.title)}, ...
                sc.title, tmpd, {}, hwt);
            f3 = figure('Visible', 'off', 'Color', [0 0 0], 'Units', 'pixels', 'Position', [20 20 1100 778], 'PaperUnits', 'centimeters', ...
                'PaperSize', [29.7 21], 'PaperPositionMode', 'manual', 'PaperPosition', [0 0 29.7 21], 'InvertHardcopy', 'off');
            pa = axes('Parent', f3, 'Units', 'normalized', 'Position', [0 0 1 0.9]);
            H = draw3D(pa, sc, false);
            for ii = 1:numel(H), place3D(H(ii), sc.objects(ii), stv(ii, 1), stv(ii, 2), stv(ii, 3)); end
            set(pa, 'Clipping', 'on');
            annotation(f3, 'textbox', [0 0.91 1 0.08], 'String', sprintf('Atto %s  -  Scena %d  -  %s  -  vista dalla platea', roman(sc.act), sc.num, sc.title), ...
                'Color', [1 0.85 0.45], 'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'EdgeColor', 'none', 'Interpreter', 'none');
            annotation(f3, 'textbox', [0 0 1 0.04], 'String', 'Personaggi ed elementi nel punto in cui compaiono per la prima volta', ...
                'Color', [0.7 0.7 0.7], 'FontSize', 9, 'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'Interpreter', 'none');
            jp{end+1} = fullfile(tmpd, 'vista3d.jpg');
            print(f3, jp{end}, '-djpeg95', '-r150', '-opengl'); delete(f3);
            writeJpegPdf(out, jp);
            if ishandle(hwt), close(hwt); end
            msgbox({'PDF salvato in:'; out}, 'Elenco passi');
        catch err
            if ishandle(hwt), close(hwt); end
            errordlg(['Errore nella creazione del PDF: ' err.message], 'Elenco passi');
        end
        try, rmdir(tmpd, 's'); catch, end %#ok<NOCOM>
    end

    function printScript()
        if isempty(SH.scenes), msgbox('Lo spettacolo non ha ancora scene.', 'Copione'); return; end
        sortScenes();
        [fnm, pth] = uiputfile({'*.pdf', 'PDF (*.pdf)'}, 'Salva l''intero copione in PDF', fullfile(showDir, [safeName(SH.title) ' - copione.pdf']));
        if isequal(fnm, 0), return; end
        out = fullfile(pth, fnm);
        tmpd = tempname; mkdir(tmpd); hwt = waitbar(0, 'Creo il copione...');
        try
            Rs = cell(0, 2);
            for q = 1:numel(SH.scenes)
                sc = SH.scenes{q};
                Rs(end+1, :) = {sprintf('Atto %-5s Scena %2d   %s', roman(sc.act), sc.num, sc.title), 's'}; %#ok<AGROW>
            end
            jp = renderPages(Rs, {SH.title, 'Copione di regia  -  elenco delle scene'}, SH.title, tmpd, {}, []);
            for q = 1:numel(SH.scenes)
                sc = SH.scenes{q};
                Tc = [];
                cf = fullfile(showDir, 'cue', sprintf('scena_%d.cue.csv', sc.uid));
                if exist(cf, 'file'), Tc = readCueTimes(cf, numel(sc.steps)); end
                jp = renderPages(sceneRows(sc, Tc), {sc.title, sprintf('Atto %s   %s   Scena %d', roman(sc.act), char(183), sc.num)}, ...
                    sprintf('%s  -  %s', SH.title, sc.title), tmpd, jp, []);
                if ishandle(hwt), waitbar(q / numel(SH.scenes), hwt); end
            end
            writeJpegPdf(out, jp);
            if ishandle(hwt), close(hwt); end
            showMsg(['Copione salvato: ' out]); msgbox({'Copione salvato in:'; out}, 'Copione');
        catch err
            if ishandle(hwt), close(hwt); end
            errordlg(['Errore nella creazione del copione: ' err.message], 'Copione');
        end
        try, rmdir(tmpd, 's'); catch, end %#ok<NOCOM>
    end

% =====================================================================
%                        SPETTACOLO DI ESEMPIO
% =====================================================================
    function makeDemo()
        t = 'Spettacolo di esempio';
        dd = fullfile(showsDir, uniqueFolder(t));
        mkdir(dd); mkdir(fullfile(dd, 'audio')); mkdir(fullfile(dd, 'modelli')); mkdir(fullfile(dd, 'cue'));
        closeShowWindows();
        SH = defaultShow(t); showDir = dd;
        SH.chars = newChar('Giulia', 'F', 1); SH.chars(2) = newChar('Marco', 'M', 2); SH.chars(3) = newChar('Il Narratore', 'M', 3);
        c = SH.chars(1).costumes(1); c.desc = 'abito rosso da sera';
        c.items = setItem(c.items, 'Sopra', ''); c.items = setItem(c.items, 'Sotto', '');
        c.items = setItem(c.items, 'Abito', 'abito_lungo'); c.irgb(6, :) = [0.72 0.2 0.29];
        c.items = setItem(c.items, 'Scarpe', 'tacchi'); c.irgb(7, :) = [0.1 0.1 0.1];
        c.hair = 'raccolti'; c.hairRGB = [0.42 0.24 0.12]; c.mk.lips = 1; c.mk.lipsRGB = [0.72 0.12 0.18]; c.mk.lashes = 1;
        SH.chars(1).costumes = c; SH.chars(1).skin = [0.93 0.76 0.62]; SH.chars(1).height = 1.66;
        c2 = c; c2.code = 'B'; c2.desc = 'jeans e giubbotto'; c2.items = setItem(c2.items, 'Abito', '');
        c2.items = setItem(c2.items, 'Sopra', 'tshirt'); c2.irgb(1, :) = [0.95 0.95 0.92];
        c2.items = setItem(c2.items, 'Giacca', 'giubbotto'); c2.irgb(3, :) = [0.3 0.22 0.16];
        c2.items = setItem(c2.items, 'Sotto', 'jeans'); c2.irgb(5, :) = [0.23 0.36 0.55];
        c2.items = setItem(c2.items, 'Scarpe', 'stivali'); c2.irgb(7, :) = [0.16 0.11 0.07]; c2.hair = 'mossi';
        SH.chars(1).costumes(2) = c2;
        c = SH.chars(2).costumes(1); c.desc = 'camicia e gilet';
        c.items = setItem(c.items, 'Sopra', 'camicia'); c.irgb(1, :) = [0.96 0.95 0.92];
        c.items = setItem(c.items, 'Gilet', 'gilet'); c.irgb(2, :) = [0.23 0.23 0.28];
        c.items = setItem(c.items, 'Sotto', 'pantaloni'); c.irgb(5, :) = [0.17 0.17 0.2];
        c.items = setItem(c.items, 'Scarpe', 'scarpe'); c.irgb(7, :) = [0.16 0.11 0.07];
        c.hair = 'pettinati'; c.hairRGB = [0.2 0.13 0.08]; c.facial = 'barba'; c.facialRGB = [0.2 0.13 0.08];
        SH.chars(2).costumes = c; SH.chars(2).skin = [0.82 0.62 0.46];
        c = SH.chars(3).costumes(1); c.desc = 'cappotto e cappello';
        c.items = setItem(c.items, 'Sopra', 'maglione'); c.irgb(1, :) = [0.45 0.16 0.16];
        c.items = setItem(c.items, 'Giacca', 'cappotto'); c.irgb(3, :) = [0.23 0.23 0.24];
        c.items = setItem(c.items, 'Sotto', 'pantaloni'); c.irgb(5, :) = [0.3 0.3 0.32];
        c.items = setItem(c.items, 'Scarpe', 'stivali'); c.irgb(7, :) = [0.1 0.08 0.06];
        c.items = setItem(c.items, 'Cappello', 'fedora'); c.irgb(8, :) = [0.15 0.15 0.15];
        c.hair = 'corti'; c.hairRGB = [0.5 0.5 0.5]; c.facial = 'baffi'; c.facialRGB = [0.55 0.55 0.55];
        SH.chars(3).costumes = c; SH.chars(3).height = 1.8;
        SH.elements = newElement('Panca', 'lib', 'panca', [1.6 0.35 0.47], [0.54 0.38 0.22], true);
        SH.elements(2) = newElement('Praticabile 2x1', 'lib', 'praticabile', [2 1 0.41], [0.42 0.35 0.28], true);
        SH.elements(3) = newElement('Colonna', 'lib', 'colonna', [0.6 0.6 3.2], [0.7 0.65 0.55], true);
        SH.elements(3).fixed = true; SH.elements(3).x = -3; SH.elements(3).y = 6.8;
        SH.elements(4) = SH.elements(3); SH.elements(4).name = 'Colonna 2'; SH.elements(4).x = 3;
        T = SH.theater; Lw = SH.lights;
        % scena 0: ouverture
        sc = newScene(newUid(), 1, 0, 'Ouverture', 'Buio. Il Narratore e'' gia'' in scena, in fondo al centro.');
        sc.objects = newObj(newUid(), 'char', 'Il Narratore', 'Il Narratore', 0, 6, SH.chars(3).pawn, '', 0, 0, 0, true);
        ow = Lw(strcmp({Lw.zone}, 'Segue un personaggio')); if isempty(ow), ow = Lw(1); end
        sc.objects(2) = newObj(newUid(), 'light', ow.name, [ow.name ' su Il Narratore'], 0, 6, ow.rgb, 'Segue un personaggio', 0, 0, 0, false);
        lc = Lw(strcmp({Lw.zone}, 'Fondale (ciclorama)')); if isempty(lc), lc = Lw(end); end
        g = zoneGeom(lc.zone, T, [0 0]);
        sc.objects(3) = newObj(newUid(), 'light', lc.name, lc.name, g.cx, g.cy, lc.rgb, lc.zone, 0, 0, 0, false);
        sc.steps = {[mkEff('entr', sc.objects(3).id, [], 2, 0), mkEff('entr', sc.objects(2).id, [], 1, 0.5)], ...
                    [mkEff('path', sc.objects(1).id, [0 0; 0 -3.5], 4, 0), mkEff('path', sc.objects(2).id, [0 0; 0 -3.5], 4, 0)], ...
                    [mkEff('exit', sc.objects(2).id, [], 1.5, 0), mkEff('exit', sc.objects(3).id, [], 2, 0.5)]};
        sc.cues = {'Si accende il fondale; un occhio di bue cerca il Narratore', 'Il Narratore avanza verso il pubblico', 'Buio'};
        sc.ens = {'', '', ''};
        SH.scenes = {sc};
        % scena 1: l'incontro
        sc = newScene(newUid(), 1, 1, 'L''incontro', 'Piazza. Luce calda su tutto il palco. La panca e'' a sinistra.');
        sc.cast = struct('name', {'Giulia', 'Marco'}, 'code', {'A', 'A'});
        lw = Lw(strcmp({Lw.zone}, 'Tutto il palco')); if isempty(lw), lw = Lw(1); end
        g = zoneGeom(lw.zone, T, [0 0]);
        sc.objects = newObj(newUid(), 'light', lw.name, lw.name, g.cx, g.cy, lw.rgb, lw.zone, 0, 0, 0, true);
        sc.objects(2) = newObj(newUid(), 'el', 'Panca', 'Panca', -2.2, 3.5, [0.54 0.38 0.22], '', 1.6, 0.35, 0, true);
        sc.objects(3) = newObj(newUid(), 'char', 'Giulia', 'Giulia', -T.W/2 - 0.8, 2.5, SH.chars(1).pawn, '', 0, 0, 0, false);
        sc.objects(4) = newObj(newUid(), 'char', 'Marco', 'Marco', T.W/2 + 0.8, 4, SH.chars(2).pawn, '', 0, 0, 0, false);
        sc.steps = {[mkEff('entr', sc.objects(3).id, [], 0.5, 0), mkEff('path', sc.objects(3).id, [0 0; 2.5 0.5; 5.0 0.5], 3, 0.5)], ...
                    [mkEff('entr', sc.objects(4).id, [], 0.5, 0), mkEff('path', sc.objects(4).id, [0 0; -3 -0.5; -5.2 -1.0], 3.5, 0.5)], ...
                    [mkEff('path', sc.objects(3).id, [5.0 0.5; 5.2 -0.5], 2, 0), mkEff('path', sc.objects(4).id, [-5.2 -1.0; -5.4 -2.0], 2, 0)], ...
                    [mkEff('path', sc.objects(3).id, [5.2 -0.5; 4.5 0.5; 3.6 1.0], 3, 0), mkEff('path', sc.objects(4).id, [-5.4 -2.0; -3 -1; 1.5 0], 3, 0.8), ...
                     mkEff('exit', sc.objects(4).id, [], 0.6, 3.6)]};
        sc.cues = {'Giulia entra da sinistra e attraversa la piazza', 'Marco entra da destra', 'Si incontrano al centro, avanti', 'Giulia va verso la panca, Marco esce a destra'};
        sc.ens = {'', 'Il coro entra dal fondo e si dispone a semicerchio', '', ''};
        SH.scenes{2} = sc;
        saveShow(); refreshHome(); openShowWin();
        showMsg('Spettacolo di esempio creato: apri una scena, prova "Montaggio" e "Vista da pubblico". Metti le canzoni "00 ....mp3" e "01 ....mp3" nella cartella audio.');
    end
end
% ============================== fine della funzione principale ==============================

% =====================================================================
%                     FUNZIONI DI SUPPORTO (file)
% =====================================================================
function C = readCatalog(fn)
C = struct('cat', {}, 'id', {}, 'name', {}, 'hex', {}, 'rgb', {}, 'size', {});
txt = fileread(fn); L = regexp(txt, '\r?\n', 'split');
for i = 2:numel(L)
    if isempty(strtrim(L{i})), continue; end
    c = strsplit(L{i}, ';'); c(end+1:8) = {''};
    hx = strtrim(c{5}); rgb = [0.6 0.6 0.6];
    if numel(hx) == 6, rgb = double([hex2dec(hx(1:2)) hex2dec(hx(3:4)) hex2dec(hx(5:6))]) / 255; end
    sz = [str2double(c{6}) str2double(c{7}) str2double(c{8})]; sz(isnan(sz)) = 1;
    C(end+1) = struct('cat', strtrim(c{1}), 'id', strtrim(c{2}), 'name', strtrim(c{3}), 'hex', hx, 'rgb', rgb, 'size', sz); %#ok<AGROW>
end
end

function L = lightLibrary()
L = struct('type', {}, 'note', {}, 'zone', {}, 'col', {}, 'qty', {});
add = @(t, n, z, c, q) struct('type', t, 'note', n, 'zone', z, 'col', c, 'qty', q);
L(end+1) = add('Piazzato PC', 'luce generale morbida', 'Tutto il palco', 'Bianco caldo', 6);
L(end+1) = add('Fresnel', 'luce generale, bordi morbidi', 'Avanti', 'Bianco caldo', 4);
L(end+1) = add('PAR LED RGB', 'colore a scelta', 'Tutto il palco', 'Blu', 8);
L(end+1) = add('Controluce', 'da dietro, stacca le figure', 'Fondo', 'Azzurro', 4);
L(end+1) = add('Testa mobile wash', 'luce colorata su una zona', 'Centro', 'Viola', 2);
L(end+1) = add('Sagomatore', 'luce precisa su un punto', 'Puntiforme (centro)', 'Bianco', 2);
L(end+1) = add('Gobo', 'disegni proiettati a terra', 'Centro', 'Verde', 2);
L(end+1) = add('Seguipersona (occhio di bue)', 'segue un personaggio', 'Segue un personaggio', 'Bianco', 1);
L(end+1) = add('Testa mobile spot', 'segue un personaggio', 'Segue un personaggio', 'Bianco', 2);
L(end+1) = add('Strip LED ciclorama', 'colora il fondale', 'Fondale (ciclorama)', 'Blu', 4);
L(end+1) = add('Ribalta', 'dal basso, sul proscenio', 'Avanti', 'Ambra', 4);
L(end+1) = add('Luce da sinistra', 'taglio laterale', 'Sinistra', 'Bianco', 2);
L(end+1) = add('Luce da destra', 'taglio laterale', 'Destra', 'Bianco', 2);
L(end+1) = add('Strobo', 'lampi', 'Tutto il palco', 'Bianco', 1);
end

function [N, V] = lightColours()
N = {'Bianco', 'Bianco caldo', 'Ambra', 'Rosso', 'Rosa', 'Viola', 'Blu', 'Azzurro', 'Verde', 'Personalizzato'};
V = [1 1 0.95; 1 0.86 0.62; 1 0.68 0.25; 1 0.15 0.12; 1 0.45 0.7; 0.62 0.3 1; 0.25 0.4 1; 0.45 0.75 1; 0.3 0.9 0.4; 1 1 1];
end

function SH = defaultShow(title)
SH.title = title; SH.created = datestr(now, 'yyyy-mm-dd HH:MM'); SH.modified = SH.created; %#ok<DATST>
SH.theater = fixTheater(struct('W', 10, 'Dtot', 9.2, 'D', 8, 'H', 7, 'nq', 3, 'wing', 2, 'P', 1.2, 'back', 'Nero', 'backImg', '', 'backModel', ''));
[N, V] = lightColours(); c = @(n) V(strcmp(N, n), :);
SH.lights = newLight('Piazzato caldo', 'Piazzato PC', 6, 'Bianco caldo', c('Bianco caldo'), 'Tutto il palco');
SH.lights(2) = newLight('Controluce blu', 'Controluce', 4, 'Blu', c('Blu'), 'Fondo');
SH.lights(3) = newLight('Ciclorama', 'Strip LED ciclorama', 4, 'Azzurro', c('Azzurro'), 'Fondale (ciclorama)');
SH.lights(4) = newLight('Occhio di bue', 'Seguipersona (occhio di bue)', 1, 'Bianco', c('Bianco'), 'Segue un personaggio');
e = newElement('', 'lib', '', [1 1 1], [1 1 1], false); SH.elements = e([]);
ch = newChar('x', 'M', 1); SH.chars = ch([]);
SH.scenes = {};
SH.nextId = 0;
end

function SH = normShow(SH)
D = defaultShow(SH.title);
for f = fieldnames(D)'
    if ~isfield(SH, f{1}), SH.(f{1}) = D.(f{1}); end
end
if ~isfield(SH.theater, 'Dtot') && isfield(SH.theater, 'D') && isfield(SH.theater, 'P'), SH.theater.Dtot = SH.theater.D + SH.theater.P; end
for f = fieldnames(D.theater)'
    if ~isfield(SH.theater, f{1}), SH.theater.(f{1}) = D.theater.(f{1}); end
end
SH.theater = fixTheater(SH.theater);
if ~iscell(SH.scenes), SH.scenes = num2cell(SH.scenes); end
mx = SH.nextId;
for q = 1:numel(SH.scenes)
    sc = SH.scenes{q}; d = newScene(0, 1, 1, '', '');
    for f = fieldnames(d)'
        if ~isfield(sc, f{1}), sc.(f{1}) = d.(f{1}); end
    end
    if ~iscell(sc.steps), sc.steps = num2cell(sc.steps); end
    sc.steps = sc.steps(:)'; sc.cues = padCell(sc.cues, numel(sc.steps)); sc.ens = padCell(sc.ens, numel(sc.steps));
    mx = max(mx, sc.uid);
    if ~isempty(sc.objects), mx = max(mx, max([sc.objects.id])); end
    SH.scenes{q} = sc;
end
SH.nextId = mx;
end

function L = newLight(name, type, qty, cname, rgb, zone)
L = struct('name', name, 'type', type, 'qty', qty, 'cname', cname, 'rgb', rgb, 'zone', zone);
end

function e = newElement(name, src, file, sz, rgb, tint)
e = struct('name', name, 'src', src, 'file', file, 'size', sz(:)', 'rgb', rgb(:)', 'tint', logical(tint), 'fixed', false, ...
    'x', 0, 'y', 0, 'rot', 0, 'occ', '', 'how', '');
end

function ch = newChar(name, sex, idx)
PAL = [0.85 0.15 0.15; 0.2 0.45 0.9; 0.2 0.7 0.3; 0.95 0.8 0.2; 0.55 0.35 0.18; 0.6 0.3 0.8; 0.1 0.1 0.1; 0.95 0.5 0.15; 0.62 0.62 0.65; 0.1 0.65 0.7];
ht = 1.78; if sex == 'F', ht = 1.66; end
ch = struct('name', name, 'pawn', PAL(mod(idx - 1, size(PAL, 1)) + 1, :), 'sex', sex, 'height', ht, 'skin', [0.93 0.76 0.62], ...
    'eyes', [0.29 0.2 0.14], 'costumes', newCostume('A', sex), 'rev', 1);
end

function co = newCostume(code, sex)
mk = struct('lips', 0, 'lipsRGB', [0.7 0.15 0.2], 'lashes', 0, 'lashesRGB', [0.06 0.05 0.05], 'shadow', 0, 'shadowRGB', [0.45 0.35 0.55], ...
    'blush', 0, 'blushRGB', [0.85 0.45 0.45], 'brows', 'normali', 'browsRGB', [0.2 0.13 0.08]);
co = struct('code', code, 'desc', ['costume ' code], 'mode', 'lib', 'file', '', 'items', {repmat({''}, 1, 10)}, ...
    'irgb', repmat([0.5 0.5 0.5], 10, 1), 'hair', 'corti', 'hairRGB', [0.23 0.14 0.09], 'facial', '', 'facialRGB', [0.2 0.13 0.08], 'mk', mk);
co.items = setItem(co.items, 'Sopra', 'tshirt'); co.irgb(1, :) = [0.95 0.95 0.95];
co.items = setItem(co.items, 'Sotto', 'jeans'); co.irgb(5, :) = [0.23 0.36 0.55];
co.items = setItem(co.items, 'Scarpe', 'scarpe'); co.irgb(7, :) = [0.16 0.11 0.07];
if sex == 'F', co.hair = 'lisci'; co.hairRGB = [0.35 0.2 0.1]; co.mk.brows = 'sottili'; end
end

function it = setItem(it, slot, id)
SL = {'Sopra', 'Gilet', 'Giacca', 'Mantello', 'Sotto', 'Abito', 'Scarpe', 'Cappello', 'Accessorio', 'Accessorio'};
k = find(strcmp(SL, slot), 1); it{k} = id;
end

function sc = newScene(uid, act, num, title, start)
if isnan(act), act = 1; end
if isnan(num), num = 1; end
ob = newObj(0, 'char', '', '', 0, 0, [1 1 1], '', 0, 0, 0, false);
sc = struct('uid', uid, 'act', act, 'num', num, 'title', title, 'start', start, ...
    'cast', struct('name', {}, 'code', {}), 'objects', ob([]), 'steps', {{}}, 'cues', {{}}, 'ens', {{}});
if isempty(sc.title), sc.title = sprintf('Scena %d', num); end
end

function o = newObj(id, kind, ref, label, x, y, rgb, zone, w, d, rot, start)
o = struct('id', id, 'kind', kind, 'ref', ref, 'label', label, 'x', x, 'y', y, 'rgb', rgb(:)', 'zone', zone, ...
    'w', w, 'd', d, 'rot', rot, 'start', logical(start));
end

function sc = setCast(sc, name, code)
if isempty(sc.cast), sc.cast = struct('name', name, 'code', code); return; end
j = find(strcmp({sc.cast.name}, name), 1);
if isempty(j), sc.cast(end+1) = struct('name', name, 'code', code); else, sc.cast(j).code = code; end
end

function sc = pruneObjs(sc)
% toglie gli oggetti che non sono in scena all'inizio e che nessun passo usa
if isempty(sc.objects), return; end
used = [];
for k = 1:numel(sc.steps)
    e = sc.steps{k}; if ~isempty(e), used = [used, [e.spid]]; end %#ok<AGROW>
end
sc.objects = sc.objects([sc.objects.start] | ismember([sc.objects.id], used));
end

function st = stateAt(sc, m)
% stato [dx dy visibile] di ogni oggetto dopo i primi m passi
objs = sc.objects; n = numel(objs); st = zeros(n, 3);
if n == 0, return; end
st(:, 3) = double([objs.start]');
ids = [objs.id];
for k = 1:min(m, numel(sc.steps))
    e = sc.steps{k};
    for j = 1:numel(e)
        i = find(ids == e(j).spid, 1); if isempty(i), continue; end
        switch e(j).cls
            case 'path', st(i, 1:2) = e(j).pts(end, :);
            case 'entr', st(i, 3) = 1;
            case 'exit', st(i, 3) = 0;
        end
    end
end
end

function e = mkEff(cls, id, pts, du, dl)
e = struct('cls', cls, 'spid', id, 'pts', pts, 'dur', du, 'delay', dl);
end

function q = simplifyPath(p)
if size(p, 1) <= 2, q = p; return; end
q = p(1, :);
for i = 2:size(p, 1) - 1
    if norm(p(i, :) - q(end, :)) >= 0.12, q(end+1, :) = p(i, :); end %#ok<AGROW>
end
q(end+1, :) = p(end, :);
if size(q, 1) > 40, q = q(round(linspace(1, size(q, 1), 40)), :); end
end

function p = pathPoint(P, u)
if size(P, 1) == 1, p = P; return; end
seg = sqrt(sum(diff(P).^2, 2)); L = [0; cumsum(seg)];
if L(end) == 0, p = P(end, :); return; end
t = u * L(end); k = find(L <= t, 1, 'last'); k = min(k, size(P, 1) - 1);
f = (t - L(k)) / max(seg(k), eps); p = P(k, :) + f * (P(k+1, :) - P(k, :));
end

function c = padCell(c, n)
if isempty(c), c = {}; end
c = c(:)';
for i = numel(c)+1:n, c{i} = ''; end
end

function s = cueText(sc, k)
s = sprintf('passo %d', k);
if k <= numel(sc.cues) && ~isempty(sc.cues{k}), s = sc.cues{k}; end
end

function t = parseTime(s)
t = NaN;
if isnumeric(s), t = double(s); return; end
s = strtrim(strrep(char(s), ',', '.'));
if isempty(s), return; end
p = strsplit(s, ':');
if numel(p) == 1, t = str2double(p{1}); else, t = str2double(p{end-1}) * 60 + str2double(p{end}); end
end

function s = fmtTime(t)
if isnan(t), s = ''; return; end
m = floor(t / 60); x = t - 60*m; s = sprintf('%02d:%04.1f', m, x);
end

function T = readCueTimes(f, n)
T = nan(1, n);
fid = fopen(f, 'r', 'n', 'UTF-8'); if fid < 0, return; end
fgetl(fid);
while true
    l = fgetl(fid); if ~ischar(l), break; end
    c = strsplit(l, ';'); if numel(c) < 2, continue; end
    k = str2double(c{1}); if isnan(k) || k < 1 || k > n, continue; end
    T(k) = parseTime(c{2});
end
fclose(fid);
end

function T = fillCues(T, dur)
n = numel(T); if n == 0, return; end
known = find(~isnan(T));
if isempty(known), lead = min(2, 0.05*dur); T = lead + (0:n-1) * max(dur*0.92 - lead, 1) / n; return; end
x = [0, known, n + 1];
y = [min(0.5, T(known(1))*0.5), T(known), max(dur*0.95, T(known(end)) + 1)];
miss = isnan(T); idx = 1:n;
if any(miss), T(miss) = interp1(x, y, idx(miss)); end
end

function on = detectOnsets(y, fs)
on = [];
try
    x = mean(double(y), 2); hop = max(1, round(fs * 0.01)); win = 4 * hop;
    c = [0; cumsum(x.^2)]; st = 1:hop:(numel(x) - win);
    if numel(st) < 20, return; end
    E = c(st + win) - c(st); E = E(:)';
    fl = [0, max(0, diff(log(E + 1e-9)))];
    thr = conv(fl, ones(1, 50) / 50, 'same') * 1.6 + 0.05;
    pk = find(fl > thr & fl >= [fl(2:end) 0] & fl >= [0 fl(1:end-1)]);
    t = (st(pk) + win/2 - 1) / fs;
    keep = true(size(t)); last = -inf;
    for i = 1:numel(t), if t(i) - last < 0.12, keep(i) = false; else, last = t(i); end, end
    on = t(keep);
catch
    on = [];
end
end

function writeJpegPdf(out, files)
% PDF A4 con una immagine JPEG a pagina intera per ogni pagina
n = numel(files);
fid = fopen(out, 'w');
if fid < 0, error('Impossibile scrivere il file %s (forse e'' aperto in un altro programma).', out); end
nobj = 2 + 3 * n; off = zeros(1, nobj);
fprintf(fid, '%%PDF-1.4\n');
off(1) = ftell(fid); fprintf(fid, '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n');
kids = sprintf('%d 0 R ', 3 + 3 * (0:n-1));
off(2) = ftell(fid); fprintf(fid, '2 0 obj\n<< /Type /Pages /Kids [%s] /Count %d >>\nendobj\n', kids, n);
for i = 1:n
    info = imfinfo(files{i}); W = info.Width; H = info.Height;
    f2 = fopen(files{i}, 'r'); data = fread(f2, inf, 'uint8=>uint8'); fclose(f2);
    cspace = '/DeviceRGB'; if isfield(info, 'NumberOfSamples') && info.NumberOfSamples == 1, cspace = '/DeviceGray'; end
    p = 3 + 3 * (i - 1);
    pw = 595.28; ph = 841.89; if W > H, pw = 841.89; ph = 595.28; end
    off(p) = ftell(fid);
    fprintf(fid, '%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %.2f %.2f] /Resources << /XObject << /Im%d %d 0 R >> >> /Contents %d 0 R >>\nendobj\n', ...
        p, pw, ph, i, p + 2, p + 1);
    cs = sprintf('q %.2f 0 0 %.2f 0 0 cm /Im%d Do Q', pw, ph, i);
    off(p + 1) = ftell(fid); fprintf(fid, '%d 0 obj\n<< /Length %d >>\nstream\n%s\nendstream\nendobj\n', p + 1, numel(cs), cs);
    off(p + 2) = ftell(fid);
    fprintf(fid, '%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent 8 /Filter /DCTDecode /Length %d >>\nstream\n', ...
        p + 2, W, H, cspace, numel(data));
    fwrite(fid, data, 'uint8'); fprintf(fid, '\nendstream\nendobj\n');
end
xr = ftell(fid);
fprintf(fid, 'xref\n0 %d\n0000000000 65535 f \n', nobj + 1);
for i = 1:nobj, fprintf(fid, '%010d 00000 n \n', off(i)); end
fprintf(fid, 'trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n', nobj + 1, xr);
fclose(fid);
end

function L = wrapText(s, n)
w = strsplit(char(s), ' '); L = {}; cur = '';
for i = 1:numel(w)
    if numel(cur) + numel(w{i}) + 1 > n, L{end+1, 1} = cur; cur = w{i}; %#ok<AGROW>
    elseif isempty(cur), cur = w{i}; else, cur = [cur ' ' w{i}]; end %#ok<AGROW>
end
if ~isempty(cur), L{end+1, 1} = cur; end
if isempty(L), L = {''}; end
end

function s = safeName(t)
s = regexprep(char(t), '[\\/:*?"<>|]', '-'); s = strtrim(s);
end

function s = onoff(b)
if b, s = 'on'; else, s = 'off'; end
end

function v = iff(c, a, b)
if c, v = a; else, v = b; end
end

function r = roman(n)
R = {'0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'};
if n >= 0 && n <= 10 && n == round(n), r = R{n + 1}; else, r = num2str(n); end
end

function v = numOr(s, d)
v = str2double(strrep(s, ',', '.')); if isnan(v), v = d; end
end

function s = joinLines(c)
if iscell(c), s = strjoin(c(:)', sprintf('\n')); elseif size(c, 1) > 1, s = strjoin(cellstr(c)', sprintf('\n')); else, s = char(c); end
end

function k = nearestRow(M, v)
[~, k] = min(sum((M - repmat(v(:)', size(M, 1), 1)).^2, 2));
end

function C = blendC(C, w, rgb)
w = w(:);
C = C .* repmat(1 - w, 1, 3) + repmat(rgb(:)', numel(w), 1) .* repmat(w, 1, 3);
end

function s = initials(nm)
w = strsplit(strtrim(nm), ' ');
w = w(~cellfun(@isempty, w));
if isempty(w), s = '?'; return; end
w = w(~ismember(lower(w), {'il', 'lo', 'la', 'i', 'gli', 'le', 'l''', 'un', 'una', 'di', 'de', 'del', 'della'}));
if isempty(w), w = strsplit(strtrim(nm), ' '); end
if numel(w) == 1, s = upper(w{1}(1:min(2, end))); else, s = upper([w{1}(1) w{2}(1)]); end
end

function openFolder(d)
if ~exist(d, 'dir'), mkdir(d); end
try
    if ispc, winopen(d); elseif ismac, system(['open "' d '"']); else, system(['xdg-open "' d '" &']); end
catch
    msgbox(d, 'Cartella');
end
end

function m = dirRec(d, name)
m = {};
L = dir(d);
for i = 1:numel(L)
    if strcmp(L(i).name, '.') || strcmp(L(i).name, '..'), continue; end
    f = fullfile(d, L(i).name);
    if L(i).isdir, m = [m, dirRec(f, name)]; elseif strcmp(L(i).name, name), m{end+1} = f; end %#ok<AGROW>
end
end

% ---------------------------------------------------------------- palco
function T = fixTheater(T)
% misure derivate: profondita' del palco = totale - proscenio; spazio delle quinte calcolato
T.W = max(2, T.W); T.P = max(0, min(T.P, T.Dtot - 2)); T.Dtot = max(T.Dtot, T.P + 2);
T.D = T.Dtot - T.P; T.nq = max(0, round(T.nq)); T.H = max(2, T.H);
T.wing = quinteWidth(T) + 0.6;
end

function s = quinteStep(T)
% distanza tra una quinta e la successiva (le quinte si dividono la profondita' del palco)
if T.nq <= 0, s = T.D; else, s = T.D / T.nq; end
end

function w = quinteWidth(T)
% larghezza di ogni quinta: un po' piu' della distanza tra due quinte, cosi' copre la vista dalla platea
w = min(3, max(1.2, 1.25 * quinteStep(T)));
if T.nq <= 0, w = 1.5; end
end

function y = quinteY(T)
if T.nq <= 0, y = []; else, s = quinteStep(T); y = (0:T.nq - 1) * s + 0.25 * s; end
end

function drawStagePlan(ax, T, labels)
W = T.W; D = T.D; P = T.P; wg = T.wing;
xa = -W/2 - wg; xb = W/2 + wg;
hold(ax, 'on');
patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [0 0 D D], 'FaceColor', [0.12 0.12 0.14], 'EdgeColor', 'none', 'HitTest', 'off');
patch('Parent', ax, 'XData', [-W/2 W/2 W/2 -W/2], 'YData', [0 0 D D], 'FaceColor', [0.34 0.26 0.19], 'EdgeColor', 'none', 'HitTest', 'off');
patch('Parent', ax, 'XData', [xa xb xb xa], 'YData', [-P -P 0 0], 'FaceColor', [0.4 0.31 0.22], 'EdgeColor', 'none', 'HitTest', 'off');
for yy = 0:1:D, plot(ax, [-W/2 W/2], [yy yy], '-', 'Color', [0.3 0.23 0.17], 'HitTest', 'off'); end
for xx = ceil(-W/2):1:floor(W/2), plot(ax, [xx xx], [0 D], '-', 'Color', [0.3 0.23 0.17], 'HitTest', 'off'); end
for yy = quinteY(T)
    for sd = [-1 1]
        plot(ax, sd * [W/2 - 0.2, W/2 - 0.2 + quinteWidth(T)], [yy yy], '-', 'Color', [0 0 0], 'LineWidth', 5, 'HitTest', 'off');
    end
end
plot(ax, [xa xb], [D D], '-', 'Color', [0.05 0.05 0.05], 'LineWidth', 7, 'HitTest', 'off');
plot(ax, [xa xb], [0 0], '--', 'Color', [0.75 0.2 0.2], 'LineWidth', 1, 'HitTest', 'off');
plot(ax, 0, 0, '^', 'Color', [0.9 0.9 0.9], 'MarkerSize', 5, 'HitTest', 'off');
tc = [0.75 0.72 0.66];
text(0, -P - 0.55, 'PUBBLICO', 'Parent', ax, 'Color', tc, 'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'HitTest', 'off');
text(0, D + 0.35, 'FONDALE', 'Parent', ax, 'Color', tc, 'FontSize', 8, 'HorizontalAlignment', 'center', 'HitTest', 'off');
text(xa + 0.1, D/2, 'QUINTE SX', 'Parent', ax, 'Color', tc, 'FontSize', 8, 'Rotation', 90, 'HorizontalAlignment', 'center', 'HitTest', 'off');
text(xb - 0.1, D/2, 'QUINTE DX', 'Parent', ax, 'Color', tc, 'FontSize', 8, 'Rotation', -90, 'HorizontalAlignment', 'center', 'HitTest', 'off');
text(xb, -P/2, 'proscenio', 'Parent', ax, 'Color', tc, 'FontSize', 7, 'HorizontalAlignment', 'right', 'HitTest', 'off');
if labels
    text(0, D/2, sprintf('%g x %g m', W, D), 'Parent', ax, 'Color', [1 1 1], 'FontSize', 12, 'HorizontalAlignment', 'center');
end
hold(ax, 'off');
set(ax, 'XLim', [xa - 0.4, xb + 0.4], 'YLim', [-P - 1.0, D + 0.7], 'DataAspectRatio', [1 1 1], 'XTick', [], 'YTick', [], ...
    'Color', [0.08 0.09 0.11], 'XColor', [0.08 0.09 0.11], 'YColor', [0.08 0.09 0.11], 'YDir', 'normal');
end

function g = zoneGeom(zone, T, p)
W = T.W; D = T.D; P = T.P;
g = struct('shape', 'rect', 'cx', 0, 'cy', D/2, 'w', W, 'h', D, 'r', 1);
switch zone
    case 'Tutto il palco', g.cy = (D - P)/2; g.h = D + P;
    case 'Avanti', g.cy = (-P + 0.4*D)/2; g.h = 0.4*D + P;
    case 'Centro', g.w = 0.55*W; g.h = 0.5*D; g.cy = 0.5*D;
    case 'Fondo', g.cy = 0.8*D; g.h = 0.4*D;
    case 'Sinistra', g.cx = -W/3; g.w = W/3; g.cy = (D - P)/2; g.h = D + P;
    case 'Destra', g.cx = W/3; g.w = W/3; g.cy = (D - P)/2; g.h = D + P;
    case 'Fondale (ciclorama)', g.shape = 'cyc'; g.cy = D - 0.15; g.w = W + 2*T.wing; g.h = 0.3;
    case 'Puntiforme (centro)', g.shape = 'circle'; g.r = 1.1; g.cy = D/2;
    case 'Segue un personaggio', g.shape = 'circle'; g.r = 0.6; g.cx = p(1); g.cy = p(2);
end
end

function z = zoneName(p, T)
x = p(1); y = p(2); W = T.W; D = T.D;
if x < -W/2, z = 'la quinta SX'; return; end
if x > W/2, z = 'la quinta DX'; return; end
if y > D - 0.4, z = 'il fondale'; return; end
if x < -W/6, side = 'SX'; elseif x > W/6, side = 'DX'; else, side = 'centro'; end
if y < 0
    if strcmp(side, 'centro'), z = 'il centro del proscenio'; else, z = ['il proscenio ' side]; end
elseif y > 2*D/3
    if strcmp(side, 'centro'), z = 'il fondo, al centro'; else, z = ['il fondo ' side]; end
elseif y > D/3
    if strcmp(side, 'centro'), z = 'il centro del palco'; else, z = ['il lato ' side]; end
else
    if strcmp(side, 'centro'), z = 'il centro, avanti'; else, z = ['avanti ' side]; end
end
end

function s = moveVerb(p0, p1, T)
inWing = @(p) abs(p(1)) > T.W/2;
z1 = zoneName(p1, T); z0 = zoneName(p0, T);
if inWing(p1) && ~inWing(p0), s = ['esce verso ' z1];
elseif inWing(p0) && ~inWing(p1), s = ['entra dal' z0(3:end) ' e va verso ' z1]; s = strrep(s, 'dal quinta', 'dalla quinta');
else, s = ['si sposta verso ' z1]; end
if norm(p1 - p0) < 0.35, s = 'fa un piccolo movimento sul posto'; end
end

% ---------------------------------------------------------------- modelli
function P = loadPartsFile(fn)
P = [];
if ~exist(fn, 'file'), return; end
M = load(fn);
if ~isfield(M, 'parts'), return; end
P = M.parts;
if ~isfield(P, 'tint'), [P.tint] = deal(0); end
if ~isfield(P, 'mix'), [P.mix] = deal([]); end
if ~isfield(P, 'alpha'), [P.alpha] = deal(1); end
if ~isfield(P, 'name'), [P.name] = deal(''); end
end

function Q = normalizeImport(P, yup, isChar)
V = vertcat(P.V);
if isempty(V), error('il modello non contiene geometria'); end
for q = 1:numel(P)
    v = double(P(q).V);
    if yup, v = [v(:, 1), -v(:, 3), v(:, 2)]; end
    P(q).V = v;
end
V = vertcat(P.V); ext = max(V, [], 1) - min(V, [], 1); big = max(ext);
s = 1; if big > 300, s = 0.001; elseif big > 30, s = 0.01; end
V = V * s; mn = min(V, [], 1); mx = max(V, [], 1); c = [(mn(1:2) + mx(1:2)) / 2, mn(3)];
nf = 0; for q = 1:numel(P), nf = nf + size(P(q).F, 1); end
ratio = min(1, 80000 / max(nf, 1));
Q = struct('V', {}, 'F', {}, 'C', {}, 'alpha', {}, 'shiny', {}, 'name', {}, 'tint', {}, 'mix', {});
for q = 1:numel(P)
    v = (double(P(q).V) * s) - repmat(c, size(P(q).V, 1), 1); F = double(P(q).F); C = double(P(q).C);
    if size(C, 1) ~= size(v, 1), C = repmat(C(1, :), size(v, 1), 1); end
    if max(C(:)) <= 1, C = C * 255; end
    if ratio < 1 && size(F, 1) > 500 && size(F, 2) == 3
        [F2, v2] = reducepatch(F, v, ratio);
        if ~isempty(F2), C = repmat(mean(C, 1), size(v2, 1), 1); F = F2; v = v2; end
    end
    if isfield(P, 'name') && ~isempty(P(q).name), nm = char(P(q).name); else, nm = sprintf('parte %d', q); end
    a = 1; if isfield(P, 'alpha') && ~isempty(P(q).alpha), a = double(P(q).alpha); end
    Q(end+1) = struct('V', single(v), 'F', uint32(F), 'C', uint8(min(255, max(0, C))), 'alpha', a, 'shiny', 0.2, ...
        'name', nm, 'tint', 0, 'mix', zeros(0, 1, 'single')); %#ok<AGROW>
end
if isChar && isempty(Q), error('nessuna parte trovata'); end
end

function P = readOBJ(fn)
txt = fileread(fn); L = regexp(txt, '\r?\n', 'split'); L = strtrim(L);
dirn = fileparts(fn);
% vertici (eventuali colori per vertice: v x y z r g b)
vl = L(strncmp(L, 'v ', 2));
if isempty(vl), error('nessun vertice nel file .obj'); end
vals = cellfun(@(s) sscanf(s(3:end), '%f')', vl, 'UniformOutput', false);
nv = numel(vals); V = zeros(nv, 3); VC = [];
nn = cellfun(@numel, vals);
for i = 1:nv, V(i, :) = vals{i}(1:3); end
if all(nn >= 6), VC = zeros(nv, 3); for i = 1:nv, VC(i, :) = vals{i}(4:6); end; end
% materiali
mats = containers.Map();
ml = L(strncmp(L, 'mtllib', 6));
for i = 1:numel(ml)
    mf = fullfile(dirn, strtrim(ml{i}(7:end)));
    if exist(mf, 'file'), mats = readMTL(mf, mats); end
end
% facce, divise per materiale
fi = find(strncmp(L, 'f ', 2) | strncmp(L, 'usemtl', 6));
cur = ''; names = {}; tris = {}; buf = zeros(0, 3); nb = 0;
for i = fi
    s = L{i};
    if s(1) == 'u'
        if nb > 0, [names, tris] = pushTri(names, tris, cur, buf(1:nb, :)); end
        cur = strtrim(s(7:end)); buf = zeros(1000, 3); nb = 0; continue
    end
    id = sscanf(regexprep(s(3:end), '/\S*', ''), '%d')';
    id(id < 0) = nv + 1 + id(id < 0);
    for t = 2:numel(id) - 1
        nb = nb + 1; if nb > size(buf, 1), buf(end + 1000, 3) = 0; end
        buf(nb, :) = id([1 t t + 1]);
    end
end
if nb > 0, [names, tris] = pushTri(names, tris, cur, buf(1:nb, :)); end
P = struct('V', {}, 'F', {}, 'C', {}, 'alpha', {}, 'name', {});
for k = 1:numel(names)
    F = tris{k}; [u, ~, j] = unique(F(:)); Fk = reshape(j, size(F));
    col = [0.75 0.75 0.75]; a = 1;
    if isKey(mats, names{k}), m = mats(names{k}); col = m.kd; a = m.d; end
    if ~isempty(VC), C = VC(u, :); else, C = repmat(col, numel(u), 1); end
    nm = names{k}; if isempty(nm), nm = 'modello'; end
    P(end+1) = struct('V', V(u, :), 'F', Fk, 'C', C, 'alpha', a, 'name', nm); %#ok<AGROW>
end
end

function [names, tris] = pushTri(names, tris, cur, F)
k = find(strcmp(names, cur), 1);
if isempty(k), names{end+1} = cur; tris{end+1} = F; else, tris{k} = [tris{k}; F]; end
end

function mats = readMTL(fn, mats)
L = strtrim(regexp(fileread(fn), '\r?\n', 'split')); cur = '';
for i = 1:numel(L)
    s = L{i};
    if strncmp(s, 'newmtl', 6), cur = strtrim(s(7:end)); mats(cur) = struct('kd', [0.75 0.75 0.75], 'd', 1);
    elseif strncmp(s, 'Kd', 2) && ~isempty(cur), m = mats(cur); v = sscanf(s(3:end), '%f')'; if numel(v) >= 3, m.kd = v(1:3); end; mats(cur) = m;
    elseif strncmp(s, 'd ', 2) && ~isempty(cur), m = mats(cur); v = sscanf(s(2:end), '%f'); if ~isempty(v), m.d = v(1); end; mats(cur) = m;
    elseif strncmp(s, 'map_Kd', 6) && ~isempty(cur)
        try
            im = double(imread(fullfile(fileparts(fn), strtrim(s(7:end)))));
            if max(im(:)) > 1, im = im / 255; end
            if size(im, 3) == 1, im = repmat(im, [1 1 3]); end
            m = mats(cur); m.kd = m.kd .* squeeze(mean(mean(im(:, :, 1:3), 1), 2))'; mats(cur) = m;
        catch
        end
    end
end
end

function P = readGLB(fn)
fid = fopen(fn, 'r'); data = fread(fid, inf, 'uint8=>uint8'); fclose(fid);
if numel(data) < 20 || ~strcmp(char(data(1:4))', 'glTF'), error('il file non e'' un .glb valido'); end
L0 = double(typecast(data(13:16), 'uint32'));
G = jsondecode(char(data(21:20 + L0))');
bin = uint8([]); o = 20 + L0;
if numel(data) >= o + 8
    L1 = double(typecast(data(o + 1:o + 4), 'uint32')); bin = data(o + 9:o + 8 + L1);
end
P = struct('V', {}, 'F', {}, 'C', {}, 'alpha', {}, 'name', {});
roots = [];
if isfield(G, 'scenes') && ~isempty(G.scenes)
    si = 0; if isfield(G, 'scene'), si = G.scene; end
    sc = itm(G.scenes, si + 1); if isfield(sc, 'nodes'), roots = sc.nodes(:)'; end
end
if isfield(G, 'nodes') && ~isempty(roots)
    for r = roots, walk(r, eye(4)); end
elseif isfield(G, 'meshes')
    for mi = 0:numel(G.meshes) - 1, addMesh(mi, eye(4)); end
end
if isempty(P), error('nessuna mesh trovata nel file .glb'); end

    function walk(ni, Mp)
        nd = itm(G.nodes, ni + 1);
        M = eye(4);
        if isfield(nd, 'matrix') && numel(nd.matrix) == 16
            M = reshape(double(nd.matrix), 4, 4);
        else
            Tm = eye(4); Rm = eye(4); Sm = eye(4);
            if isfield(nd, 'translation'), Tm(1:3, 4) = double(nd.translation(:)); end
            if isfield(nd, 'rotation')
                q = double(nd.rotation(:)'); x = q(1); y = q(2); z = q(3); w = q(4);
                Rm(1:3, 1:3) = [1-2*(y^2+z^2), 2*(x*y-z*w), 2*(x*z+y*w); 2*(x*y+z*w), 1-2*(x^2+z^2), 2*(y*z-x*w); 2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x^2+y^2)];
            end
            if isfield(nd, 'scale'), Sm = diag([double(nd.scale(:))' 1]); end
            M = Tm * Rm * Sm;
        end
        Mw = Mp * M;
        if isfield(nd, 'mesh') && ~isempty(nd.mesh), addMesh(nd.mesh, Mw); end
        if isfield(nd, 'children'), for c = nd.children(:)', walk(c, Mw); end, end
    end

    function addMesh(mi, M)
        me = itm(G.meshes, mi + 1); nmM = sprintf('mesh %d', mi); if isfield(me, 'name'), nmM = me.name; end
        pr = me.primitives;
        for k = 1:numel(pr)
            p = itm(pr, k);
            if isfield(p, 'mode') && p.mode ~= 4, continue; end
            if isfield(p, 'extensions') && isfield(p.extensions, 'KHR_draco_mesh_compression')
                error('il modello e'' compresso (Draco): riesportalo senza compressione');
            end
            Vp = acc(p.attributes.POSITION);
            if isfield(p, 'indices'), I = acc(p.indices) + 1; else, I = (1:size(Vp, 1))'; end
            F = reshape(I, 3, [])';
            col = [1 1 1]; a = 1;
            if isfield(p, 'material') && isfield(G, 'materials')
                [col, a] = matColour(itm(G.materials, p.material + 1));
            end
            if isfield(p.attributes, 'COLOR_0')
                Cv = acc(p.attributes.COLOR_0); C = Cv(:, 1:3) .* repmat(col, size(Cv, 1), 1);
            else
                C = repmat(col, size(Vp, 1), 1);
            end
            Vh = [Vp, ones(size(Vp, 1), 1)] * M';
            P(end+1) = struct('V', Vh(:, 1:3), 'F', F, 'C', C, 'alpha', a, 'name', nmM); %#ok<AGROW>
        end
    end

    function [col, a] = matColour(m)
        col = [1 1 1]; a = 1;
        if isfield(m, 'pbrMetallicRoughness')
            pb = m.pbrMetallicRoughness;
            if isfield(pb, 'baseColorFactor'), f = double(pb.baseColorFactor(:)'); col = f(1:3); if numel(f) > 3, a = f(4); end, end
            if isfield(pb, 'baseColorTexture'), col = col .* texMean(pb.baseColorTexture.index); end
        end
        if ~(isfield(m, 'alphaMode') && strcmp(m.alphaMode, 'BLEND')), a = 1; end
    end

    function c = texMean(ti)
        c = [1 1 1];
        try
            tx = itm(G.textures, ti + 1); im = itm(G.images, tx.source + 1);
            bv = itm(G.bufferViews, im.bufferView + 1); off = 0; if isfield(bv, 'byteOffset'), off = bv.byteOffset; end
            raw = bin(off + 1:off + bv.byteLength);
            ext = '.png'; if isfield(im, 'mimeType') && ~isempty(strfind(im.mimeType, 'jpeg')), ext = '.jpg'; end %#ok<STREMP>
            tf = [tempname ext]; f2 = fopen(tf, 'w'); fwrite(f2, raw, 'uint8'); fclose(f2);
            I = double(imread(tf)); delete(tf);
            if max(I(:)) > 1, I = I / 255; end
            if size(I, 3) == 1, I = repmat(I, [1 1 3]); end
            c = squeeze(mean(mean(I(:, :, 1:3), 1), 2))';
        catch
        end
    end

    function A = acc(i)
        a = itm(G.accessors, i + 1);
        switch a.type
            case 'SCALAR', nc = 1; case 'VEC2', nc = 2; case 'VEC3', nc = 3; case 'VEC4', nc = 4; otherwise, nc = 16;
        end
        switch a.componentType
            case 5126, cls = 'single'; nbt = 4; case 5125, cls = 'uint32'; nbt = 4; case 5123, cls = 'uint16'; nbt = 2;
            case 5122, cls = 'int16'; nbt = 2; case 5121, cls = 'uint8'; nbt = 1; otherwise, cls = 'int8'; nbt = 1;
        end
        bv = itm(G.bufferViews, a.bufferView + 1);
        off = 0; if isfield(bv, 'byteOffset'), off = bv.byteOffset; end
        if isfield(a, 'byteOffset'), off = off + a.byteOffset; end
        es = nbt * nc; stride = es; if isfield(bv, 'byteStride') && ~isempty(bv.byteStride), stride = bv.byteStride; end
        n = a.count;
        if stride == es
            raw = bin(off + 1:off + n * es);
        else
            idx = off + (0:n - 1)' * stride + (1:es); idx = idx'; raw = bin(idx(:));
        end
        A = reshape(double(typecast(raw(:), cls)), nc, n)';
        if isfield(a, 'normalized') && a.normalized && ~strcmp(cls, 'single'), A = A / double(intmax(cls)); end
    end
end

function x = itm(arr, k)
if iscell(arr), x = arr{k}; else, x = arr(k); end
end
