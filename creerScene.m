function hs = creerScene(ax, P, res)
% CREERSCENE  Dessine le décor de l'animation et crée les objets qui bougeront.
%
%   hs = creerScene(ax, P, res)
%
%   ENTRÉES
%     ax    les axes (la zone de dessin) où tracer l'animation
%     P     structure des paramètres (voir parametres.m)
%     res   résultats d'un cycle (sortie de calculerCycle.m) ; on y lit les
%           angles de prise et de dépôt
%
%   SORTIE
%     hs    structure de « poignées » (handles). Une poignée est une
%           référence vers un objet graphique déjà dessiné. Elle permet de
%           le modifier plus tard sans tout redessiner. C'est ce qui rend
%           l'animation fluide : majScene.m déplace les objets existants.
%
%   PRINCIPE
%     On dessine UNE SEULE FOIS :
%       - le décor fixe (table, supports, pivot, trajectoire) ;
%       - les objets mobiles (bras, courroie, poulie, ventouse, pièce),
%         placés n'importe où pour l'instant.
%     Ensuite, majScene.m est appelée à chaque image pour replacer les
%     objets mobiles.
%
%   UNITÉS DU DESSIN : millimètres (les calculs sont en mètres ; on
%   multiplie par 1000 pour dessiner).
%
%   REPÈRE : origine au pivot, x vers le dépôt (droite), y vers le haut.

mm = 1000;                              % facteur de conversion m -> mm

% --- 1. Cotes utiles, en millimètres ----------------------------------------
L       = P.L * mm;                     % longueur du bras
yTable  = -P.hPivot * mm;               % la table est sous le pivot
D       = P.piece.D * mm;               % diamètre de la pièce
xPrise  = L * cos(res.thetaPrise);     % position horizontale de la prise
xDepot  = L * cos(res.thetaDepot);     % position horizontale du dépôt
hPrise  = P.hAppuiPrise * mm;           % hauteur du support de prise
hDepot  = P.hAppuiDepot * mm;           % hauteur du support de dépôt
largeur = D + 14;                       % largeur dessinée des supports
rPoulie = 10.5;                         % rayon dessiné des poulies (22 dents x 3 mm / (2*pi))

% Couleurs [rouge vert bleu], valeurs entre 0 et 1
grisFonce = [0.30 0.30 0.30];
grisPale  = [0.80 0.80 0.80];
laiton    = [0.72 0.58 0.20];

% --- 2. Réglage des axes ------------------------------------------------------
% cla efface le contenu des axes ; « hold on » permet d'empiler les dessins.
cla(ax);
hold(ax, 'on');
set(ax, 'DataAspectRatio', [1 1 1]);    % 1 mm en x = 1 mm en y (pas de déformation)
set(ax, 'XLim', [-(L + 78), L + 78], 'YLim', [yTable - 26, L + 38]);
set(ax, 'Box', 'on', 'Color', [1 1 1]);
xlabel(ax, 'x (mm)');
ylabel(ax, 'y (mm)');
title(ax, 'Animation du cycle (vue de côté)');

% --- 3. Décor fixe --------------------------------------------------------------
% a) La table : un trait épais
line('Parent', ax, 'XData', [-(L + 78), L + 78], 'YData', [yTable, yTable], ...
     'Color', grisFonce, 'LineWidth', 3);

% b) Les supports de prise et de dépôt : des rectangles pleins.
% patch dessine un polygone à partir de la liste de ses sommets (x puis y).
patch('Parent', ax, ...
      'XData', xPrise + [-1, 1, 1, -1] * largeur/2, ...
      'YData', yTable + [0, 0, hPrise, hPrise], ...
      'FaceColor', grisPale, 'EdgeColor', grisFonce);
patch('Parent', ax, ...
      'XData', xDepot + [-1, 1, 1, -1] * largeur/2, ...
      'YData', yTable + [0, 0, hDepot, hDepot], ...
      'FaceColor', grisPale, 'EdgeColor', grisFonce);

text(xPrise, yTable - 13, 'PRISE', 'Parent', ax, ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold');
text(xDepot, yTable - 13, 'DÉPÔT', 'Parent', ax, ...
     'HorizontalAlignment', 'center', 'FontWeight', 'bold');

% c) Le support du pivot : un trapèze qui va de la table au pivot
patch('Parent', ax, ...
      'XData', [-22, 22, 9, -9], ...
      'YData', [yTable, yTable, 0, 0], ...
      'FaceColor', grisPale, 'EdgeColor', grisFonce);

% d) La trajectoire de l'axe de la poulie : un arc de cercle en pointillé
angles = linspace(res.thetaPrise, res.thetaDepot, 100);
line('Parent', ax, 'XData', L * cos(angles), 'YData', L * sin(angles), ...
     'Color', [0.55 0.55 0.55], 'LineStyle', '--');

% --- 4. Objets mobiles (leurs positions seront fixées par majScene.m) ----------
% a) Les deux brins de la courroie crantée
hs.courroie1 = line('Parent', ax, 'XData', [0 0], 'YData', [0 0], ...
                    'Color', [0.10 0.10 0.10], 'LineWidth', 1);
hs.courroie2 = line('Parent', ax, 'XData', [0 0], 'YData', [0 0], ...
                    'Color', [0.10 0.10 0.10], 'LineWidth', 1);

% b) Le bras : un trait épais du pivot à l'axe de la poulie
hs.bras = line('Parent', ax, 'XData', [0 0], 'YData', [0 0], ...
               'Color', [0.55 0.57 0.60], 'LineWidth', 7);

% c) La poulie fixe (au pivot) et la poulie mobile (au bout du bras).
% Un cercle est dessiné comme un polygone de 40 sommets :
% x = r*cos(a), y = r*sin(a), avec a qui fait un tour complet (0 à 2*pi).
a = linspace(0, 2*pi, 40);
hs.cercleX = rPoulie * cos(a);
hs.cercleY = rPoulie * sin(a);
patch('Parent', ax, 'XData', hs.cercleX, 'YData', hs.cercleY, ...
      'FaceColor', [0.85 0.88 0.95], 'EdgeColor', grisFonce);
hs.poulie = patch('Parent', ax, 'XData', hs.cercleX, 'YData', hs.cercleY, ...
      'FaceColor', [0.85 0.88 0.95], 'EdgeColor', grisFonce);

% d) Le pivot : un petit disque noir
line('Parent', ax, 'XData', 0, 'YData', 0, 'Marker', 'o', 'MarkerSize', 5, ...
     'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k');

% e) La tige (support et adaptateur) entre la poulie et la ventouse
hs.tige = line('Parent', ax, 'XData', [0 0], 'YData', [0 0], ...
               'Color', laiton, 'LineWidth', 4);

% f) La ventouse : un trapèze noir
hs.ventouse = patch('Parent', ax, 'XData', [0 0 0 0], 'YData', [0 0 0 0], ...
                    'FaceColor', [0.15 0.15 0.15], 'EdgeColor', 'k');

% g) La pièce : un rectangle (rondelle vue de côté)
hs.piece = patch('Parent', ax, 'XData', [0 0 0 0], 'YData', [0 0 0 0], ...
                 'FaceColor', [0.5 0.5 0.5], 'EdgeColor', 'k', 'LineWidth', 1);

% h) Le texte qui indique le temps et l'étape en cours
hs.texte = text(-(L + 70), L + 24, '', 'Parent', ax, 'FontSize', 10, ...
                'FontWeight', 'bold', 'Color', [0.10 0.25 0.55]);

% On garde aussi le rayon dessiné des poulies pour majScene.m
% (hs.cercleX et hs.cercleY, créés plus haut, servent à déplacer la poulie)
hs.rPoulie = rPoulie;

end
