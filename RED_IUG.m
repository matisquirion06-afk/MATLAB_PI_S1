function RED_IUG()
% RED_IUG  Interface graphique (IUG) du système ramasse-dépose (RED) - Équipe 14.
%
%   POUR LANCER LE PROGRAMME
%     1. Dans Matlab, ouvrir le dossier qui contient ce fichier
%        (il doit apparaître dans « Current Folder »).
%     2. Taper  RED_IUG  dans la fenêtre de commande, puis Entrée.
%
%   CE QUE FAIT L'INTERFACE (exigences de la consigne)
%     a) Elle anime un cycle complet de ramassage et de dépôt.
%     b) Elle trace, en même temps que l'animation, la position, la vitesse
%        et l'accélération angulaires du bras, l'effort de la ventouse et
%        le facteur de sécurité de la prise.
%     c) Elle permet de changer de matériau et compare les trois matériaux
%        dans un tableau.
%     d) Elle calcule la durée minimale de chaque rotation : la plus courte
%        qui respecte la ventouse (facteur de sécurité exigé), le couple et
%        la fréquence du vérin, et l'énergie admissible en fin de course
%        (fiche Festo). La durée minimale selon le FS seul est affichée à
%        part (résumé et « Détails techniques »).
%     Elle refuse les entrées invalides, signale les résultats hors du
%     domaine de validité et sauvegarde les résultats dans un fichier texte.
%
%   À QUI ELLE S'ADRESSE
%     [Claude] Depuis le 19 nov. 2026, l'interface vise les utilisateurs du
%     Consortium des mini-usines de l'Estrie : notions de génie mécanique,
%     mais pas ingénieurs. L'écran principal parle en mots simples ; tous
%     les détails techniques restent dans la fenêtre « Détails techniques ».
%
%   LES RÉGLAGES (colonne de gauche)
%     1. La rondelle (Delrin, aluminium, acier).
%     2. La vitesse du bras :
%          « la plus rapide permise »  : durée minimale calculée (par défaut) ;
%          « comme la machine actuelle » : durées mesurées sur la vidéo ;
%          « je choisis la durée »     : l'utilisateur tape la durée du
%                                        transfert (case qui apparaît).
%     3. L'équipement : « ajouter des amortisseurs » retire la limite
%        d'énergie en fin de course (simulation : la machine n'en a pas).
%     Réglages avancés (cachés par défaut) : couple du vérin (2,00 N.m,
%     catalogue Festo) et facteur de sécurité exigé (2,0, choix de l'équipe).

%   COMMENT CE FICHIER EST ORGANISÉ
%     Ce fichier ne contient AUCUNE équation de physique. Il s'occupe
%     seulement de l'affichage et des boutons. Tous les calculs sont faits
%     par les autres fichiers (calculerCycle.m, dureeMinimale.m, etc.).
%
%     Il contient une fonction principale (RED_IUG) et plusieurs fonctions
%     « locales », rangées en quatre groupes :
%       A. Construction de la fenêtre      (construireInterface, ...)
%       B. Calcul et affichage             (mettreAJour, afficher...)
%       C. Animation                       (lancerAnimation, ...)
%       D. Autres boutons                  (sauvegarder, montrerDetails, montrerAide, ...)
%
%   TROIS NOTIONS UTILES POUR LIRE CE FICHIER
%     1. POIGNÉE (handle) : référence vers un objet graphique (bouton,
%        courbe, zone de texte). On lit une propriété avec get(...) et on
%        la change avec set(...).
%     2. FONCTION DE RAPPEL (callback) : fonction que Matlab exécute quand
%        l'utilisateur agit sur un objet. Exemple :
%            'Callback', @(~, ~) mettreAJour(fig)
%        veut dire « quand on clique, exécuter mettreAJour(fig) ». Les deux
%        symboles ~ sont des informations que Matlab envoie et dont on
%        n'a pas besoin.
%     3. MÉMOIRE DE LA FENÊTRE (guidata) : toutes les données du programme
%        sont rangées dans une structure S, attachée à la fenêtre.
%            S = guidata(fig);     lit la structure
%            guidata(fig, S);      enregistre la structure modifiée
%        Chaque fonction de rappel commence par lire S et, si elle l'a
%        modifiée, finit par l'enregistrer.
clc
% --- 1. Charger tous les paramètres -------------------------------------------
P    = parametres();
nMat = numel(P.materiaux);              % nombre de matériaux (3)

% --- 2. Créer la fenêtre --------------------------------------------------------
% 'Units' 'normalized' : les positions sont des fractions de l'écran
% (0 = bord gauche ou bas, 1 = bord droit ou haut).
% 'Position' = [gauche, bas, largeur, hauteur].
fig = figure('Name', 'Système ramasse-dépose (RED) - Équipe 14', ...
             'NumberTitle', 'off', ...
             'MenuBar', 'none', ...
             'Units', 'normalized', ...
             'Position', [0.02 0.06 0.96 0.86], ...
             'Color', [0.94 0.94 0.94]);

% --- 3. Préparer la mémoire de la fenêtre (structure S) --------------------------
S.P          = P;                       % les paramètres
S.iMat       = P.materiauDefaut;        % numéro du matériau choisi
S.FScible    = P.FScible;               % [-] facteur de sécurité cible
S.modeDurees = 1;                       % 1 = calculée au couple ; 2 = mesurée (vidéo)
S.valide     = false;                   % vrai si les entrées sont valides
S.R          = cell(1, nMat);           % résultats : S.R{i} pour le matériau i
                                        %   ([] si le couple ne suffit pas)
S.scene      = [];                      % poignées de l'animation
S.Tmin       = NaN(1, nMat);            % [s] durée minimale du transfert, par matériau
S.TretourMin = NaN;                     % [s] durée minimale du retour à vide
S.limiteRetour = 'couple';              % limite qui fixe cette durée
S.lignesDomaine = {};                   % jugement complet (verifierDomaine.m)
S.infoRetour = [];                      % informations sur le calcul du retour
S.infoOpt    = cell(1, nMat);           % informations sur le calcul du transfert
S.enMarche   = false;                   % vrai pendant que l'animation tourne
S.tCourant   = 0;                       % [s] instant affiché dans le cycle
S.vitesses   = [0.1, 0.25, 0.5, 1, 2];  % vitesses d'animation proposées
S.vitesse    = 1;                       % vitesse d'animation choisie

% --- 4. Créer les boutons, les textes et les graphiques --------------------------
S.h = construireInterface(fig, S);

% --- 5. Enregistrer S, puis faire le premier calcul et le premier affichage ------
guidata(fig, S);
mettreAJour(fig);

end


% =================================================================================
%%  GROUPE A - CONSTRUCTION DE LA FENÊTRE
% =================================================================================

function h = construireInterface(fig, S)
% CONSTRUIREINTERFACE  Crée tous les objets de la fenêtre et retourne leurs poignées.
%   La fenêtre est divisée en trois colonnes :
%     gauche  : réglages (en trois étapes), animation, valeurs à l'instant
%     centre  : animation, message d'état en langage simple, résumé des
%               résultats et comparaison des rondelles
%     droite  : les cinq tracés en fonction du temps
%
%   [Claude] Interface simplifiée le 19 nov. 2026 pour le Consortium des
%   mini-usines de l'Estrie (utilisateurs avec des notions de génie
%   mécanique, mais pas ingénieurs) :
%     - les réglages sont regroupés en trois étapes numérotées ;
%     - le couple et le facteur de sécurité sont des « réglages avancés »,
%       cachés par défaut (ils gardent les valeurs justifiées par l'équipe) ;
%     - les résultats sont résumés en phrases, avec la cause de chaque
%       limite en mots simples ;
%     - tous les détails techniques (durées par contrainte, efforts,
%       couples, avertissements complets, hypothèses, tests) restent
%       accessibles par le bouton « Détails techniques » ;
%     - une bulle d'aide apparaît sur chaque commande, et le bouton
%       « Aide » ouvre un mode d'emploi.

P    = S.P;
fond = [0.94 0.94 0.94];                % couleur de fond (gris pâle)

% ---------------------------------------------------------------------------------
%  COLONNE DE GAUCHE : RÉGLAGES
% ---------------------------------------------------------------------------------
% Dans un panneau, les positions sont des fractions DU PANNEAU. Les
% positions verticales sont calculées par placerCommandes : certaines
% lignes n'apparaissent que dans certains cas (durée choisie, réglages
% avancés), et les lignes suivantes remontent alors pour combler le vide.
pan = uipanel('Parent', fig, 'Title', 'Réglages', 'FontWeight', 'bold', ...
              'BackgroundColor', fond, ...
              'Units', 'normalized', 'Position', [0.006 0.015 0.208 0.975]);
h.panReglages = pan;

% --- Étape 1 : la rondelle ---
h.lblMat = etiquette(pan, [0 0 0.90 0.028], '1. Rondelle à déplacer', true);
nomsMenu = cell(1, numel(P.materiaux));
for i = 1:numel(P.materiaux)
    nomsMenu{i} = sprintf('%s (%.0f g)', P.materiaux(i).nom, 1000 * massePiece(P, i));
end
h.popMateriau = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
    'Units', 'normalized', 'Position', [0.05 0 0.90 0.038], ...
    'String', nomsMenu, 'Value', S.iMat, ...
    'TooltipString', 'Matériau de la rondelle transportée par le bras.', ...
    'Callback', @(~, ~) mettreAJour(fig));

% --- Étape 2 : la vitesse des rotations ---
% 1. La plus rapide permise : la plus courte durée qui respecte toutes
%    les limites (ventouse, couple, fréquence, chocs en fin de course).
% 2. Machine actuelle : les durées mesurées sur la vidéo.
% 3. Durée choisie : l'utilisateur tape la durée du transfert (le retour
%    à vide garde sa durée mesurée).
h.lblMode = etiquette(pan, [0 0 0.90 0.028], '2. Vitesse du bras', true);
h.popMode = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
    'Units', 'normalized', 'Position', [0.05 0 0.90 0.038], ...
    'String', {'La plus rapide permise (recommandé)', ...
               'Comme la machine actuelle (vidéo)', ...
               'Je choisis la durée du transfert'}, ...
    'Value', S.modeDurees, ...
    'TooltipString', ['Le programme peut chercher la vitesse maximale permise, ' ...
                      'reproduire la machine actuelle, ou utiliser votre durée.'], ...
    'Callback', @(~, ~) mettreAJour(fig));

h.lblT = etiquette(pan, [0 0 0.62 0.028], 'Durée du transfert (s)', false);
h.editT = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0 0.26 0.038], ...
    'String', sprintf('%.3f', P.duree.transfert), 'BackgroundColor', [1 1 1], ...
    'TooltipString', 'Durée de la rotation avec la rondelle, en secondes (ex. 1,5).', ...
    'Callback', @(~, ~) mettreAJour(fig));

% --- Étape 3 : l'équipement ---
h.lblEquip = etiquette(pan, [0 0 0.90 0.028], '3. Équipement', true);
h.caseAmort = uicontrol('Parent', pan, 'Style', 'checkbox', ...
    'Units', 'normalized', 'Position', [0.05 0 0.90 0.034], ...
    'String', 'Ajouter des amortisseurs (simulation)', 'Value', ~P.actionneur.festo.actif, ...
    'BackgroundColor', fond, ...
    'TooltipString', ['La machine actuelle n''a pas d''amortisseurs : le fabricant limite alors ' ...
                      'la vitesse pour éviter les chocs en fin de course. Cochez pour voir ' ...
                      'ce que permettraient des amortisseurs ou des butées externes.'], ...
    'Callback', @(~, ~) mettreAJour(fig));

h.caseAvance = uicontrol('Parent', pan, 'Style', 'checkbox', ...
    'Units', 'normalized', 'Position', [0.05 0 0.90 0.034], ...
    'String', 'Afficher les réglages avancés', 'Value', 0, ...
    'BackgroundColor', fond, ...
    'TooltipString', 'Couple du vérin et marge de sécurité exigée.', ...
    'Callback', @(~, ~) basculerAvance(fig));

% Réglages avancés (cachés par défaut)
h.lblCouple = etiquette(pan, [0 0 0.62 0.028], 'Couple du vérin (N.m)', false);
h.editCouple = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0 0.26 0.038], ...
    'String', sprintf('%.2f', P.actionneur.couple), 'BackgroundColor', [1 1 1], ...
    'TooltipString', sprintf(['Force de rotation du vérin. Vérin actuel (Festo DSR-16) : ' ...
                              '%.2f N.m à 6 bar.'], P.actionneur.coupleCatalogue), ...
    'Callback', @(~, ~) mettreAJour(fig));

h.lblFS = etiquette(pan, [0 0 0.62 0.028], 'Marge de sécurité exigée', false);
h.editFS = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0 0.26 0.038], ...
    'String', sprintf('%.2f', S.FScible), 'BackgroundColor', [1 1 1], ...
    'TooltipString', ['Facteur de sécurité (FS) de la prise : 2 veut dire que la ventouse ' ...
                      'doit pouvoir tenir deux fois l''effort nécessaire.'], ...
    'Callback', @(~, ~) mettreAJour(fig));

h.btnDefaut = bouton(pan, [0.05 0 0.90 0.038], 'Remettre les valeurs par défaut', ...
                     @(~, ~) valeursParDefaut(fig));

% --- Animation ---
h.lblAnim = etiquette(pan, [0 0 0.90 0.028], 'ANIMATION DU CYCLE', true);
h.btnLancer  = bouton(pan, [0.050 0 0.29 0.040], 'Lancer',  @(~, ~) lancerAnimation(fig));
h.btnPause   = bouton(pan, [0.355 0 0.29 0.040], 'Pause',   @(~, ~) mettreEnPause(fig));
h.btnArreter = bouton(pan, [0.660 0 0.29 0.040], 'Arrêter', @(~, ~) arreterAnimation(fig));

h.lblVitesse = etiquette(pan, [0 0 0.56 0.028], 'Vitesse de l''animation', false);
h.popVitesse = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
    'Units', 'normalized', 'Position', [0.62 0 0.33 0.038], ...
    'String', {'0,1 x', '0,25 x', '0,5 x', '1 x', '2 x'}, 'Value', 4, ...
    'TooltipString', '0,25 x montre le cycle quatre fois plus lentement que la réalité.', ...
    'Callback', @(~, ~) changerVitesse(fig));

% Glissière : permet de se déplacer à la main dans le cycle
h.lblGliss = etiquette(pan, [0 0 0.90 0.026], 'Moment du cycle (glisser)', false);
h.glissiere = uicontrol('Parent', pan, 'Style', 'slider', ...
    'Units', 'normalized', 'Position', [0.05 0 0.90 0.028], ...
    'Min', 0, 'Max', 1, 'Value', 0, 'SliderStep', [0.005 0.05], ...
    'TooltipString', 'Déplacez pour voir la machine à un moment précis du cycle.', ...
    'Callback', @(~, ~) deplacerGlissiere(fig));

% Case à cocher : agrandir les tracés sur l'étape du transfert
h.caseZoom = uicontrol('Parent', pan, 'Style', 'checkbox', ...
    'Units', 'normalized', 'Position', [0.05 0 0.90 0.034], ...
    'String', 'Graphiques : agrandir le transfert', 'Value', 0, ...
    'BackgroundColor', fond, ...
    'TooltipString', 'Montre seulement la rotation avec la rondelle dans les graphiques.', ...
    'Callback', @(~, ~) changerZoom(fig));

% Valeurs à l'instant affiché (mises à jour pendant l'animation)
h.lblInstant = etiquette(pan, [0 0 0.90 0.028], 'EN CE MOMENT', true);
h.txtInstant = uicontrol('Parent', pan, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.05 0.12 0.90 0.15], ...
    'String', '', 'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

% --- Boutons du bas (position fixe) ---
bouton(pan, [0.05 0.062 0.90 0.040], 'Sauvegarder les résultats (.txt)', ...
       @(~, ~) sauvegarder(fig));
bouton(pan, [0.05 0.012 0.44 0.042], 'Détails techniques', @(~, ~) montrerDetails(fig));
bouton(pan, [0.51 0.012 0.44 0.042], 'Aide', @(~, ~) montrerAide());

% ---------------------------------------------------------------------------------
%  COLONNE DU CENTRE : ANIMATION, MESSAGE, RÉSULTATS
% ---------------------------------------------------------------------------------
% Zone de dessin de l'animation (remplie par creerScene.m)
h.axScene = axes('Parent', fig, 'Units', 'normalized', ...
                 'Position', [0.255 0.525 0.410 0.415]);

% Bandeau de message : vert, orange ou rouge selon la situation
h.txtMessage = uicontrol('Parent', fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.222 0.375 0.455 0.085], ...
    'String', '', 'FontWeight', 'bold', 'FontSize', 10, 'HorizontalAlignment', 'left');

% Panneau des résultats
panV = uipanel('Parent', fig, 'Title', 'Résultats', ...
               'FontWeight', 'bold', 'BackgroundColor', fond, ...
               'Units', 'normalized', 'Position', [0.222 0.015 0.455 0.350]);

% a) Résumé du cas choisi, en phrases (voir afficherResume)
h.txtResume = uicontrol('Parent', panV, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.012 0.02 0.50 0.96], ...
    'String', '', 'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1], ...
    'FontSize', 10);

% b) Comparaison des trois rondelles (consigne, point c). Les durées par
%    contrainte (dont la durée minimale selon le FS, point d) sont aussi
%    dans le résumé et dans « Détails techniques ».
h.lblTableau = etiquette(panV, [0.525 0.90 0.47 0.07], 'Comparaison (masse en g, durées en s)', true);
h.tableau = uitable('Parent', panV, ...
    'Units', 'normalized', 'Position', [0.525 0.47 0.465 0.43], ...
    'ColumnName', {'Rondelle', 'Masse', 'Transf.', 'Limite', 'Cycle', 'FS'}, ...
    'RowName', [], ...
    'FontSize', 9, ...
    'Data', cell(numel(P.materiaux), 6));
ajusterTableau(h.tableau, [0.20 0.14 0.17 0.18 0.14 0.15]);

% c) Petit lexique pour lire les résultats
h.txtLexique = uicontrol('Parent', panV, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.525 0.02 0.465 0.43], ...
    'HorizontalAlignment', 'left', 'BackgroundColor', fond, 'FontSize', 8, ...
    'String', { ...
      'Comment lire :', ...
      '- Transf. : rotation du bras avec la rondelle.', ...
      '- Limite : ce qui empêche d''aller plus vite.', ...
      '   Chocs = énergie en fin de course (fabricant).', ...
      '   Couple = force du vérin.  Ventouse = prise.', ...
      '- FS (facteur de sécurité) : combien de fois la', ...
      '   ventouse tient plus que l''effort nécessaire.', ...
      '   Il doit rester au-dessus de la marge exigée.'});

% ---------------------------------------------------------------------------------
%  COLONNE DE DROITE : LES CINQ TRACÉS
% ---------------------------------------------------------------------------------
titres = {'Angle du bras (°)', ...
          'Vitesse du bras (rad/s)', ...
          'Accélération du bras (rad/s^2)', ...
          'Effort de la ventouse sur la rondelle (N)', ...
          'Facteur de sécurité de la prise (FS)'};

bleu  = [0.00 0.35 0.70];
rouge = [0.85 0.10 0.10];
gris  = [0.45 0.45 0.45];

nTraces = 5;

% h.ax(i) est la poignée de la zone de tracé numéro i (1 = en haut).
for i = 1:nTraces
    % Les tracés sont empilés de haut (i = 1) en bas (i = 5).
    bas = 0.075 + (nTraces - i) * 0.183;
    h.ax(i) = axes('Parent', fig, 'Units', 'normalized', ...
                   'Position', [0.725 bas 0.262 0.130], ...
                   'Box', 'on', 'XGrid', 'on', 'YGrid', 'on', 'FontSize', 8);
    title(h.ax(i), titres{i}, 'FontSize', 9);
    if i < nTraces
        set(h.ax(i), 'XTickLabel', []);     % graduations du temps : en bas seulement
    else
        xlabel(h.ax(i), 'Temps depuis le début du cycle (s)');
    end
end

% Courbes (vides pour l'instant : NaN veut dire « rien à tracer »).
% Tracés 1 à 3 : position, vitesse et accélération angulaires du bras.
for i = 1:3
    h.courbe(i) = line('Parent', h.ax(i), 'XData', NaN, 'YData', NaN, ...
                       'Color', bleu, 'LineWidth', 1.5);
end

% Tracé 4 : effort de la ventouse (trois lignes)
h.courbeFrequis = line('Parent', h.ax(4), 'XData', NaN, 'YData', NaN, ...
                       'Color', bleu, 'LineWidth', 2);
h.courbeFnorme  = line('Parent', h.ax(4), 'XData', NaN, 'YData', NaN, ...
                       'Color', [0.10 0.60 0.30], 'LineWidth', 1.2);
h.lignePoids    = line('Parent', h.ax(4), 'XData', NaN, 'YData', NaN, ...
                       'Color', gris, 'LineStyle', '--', 'LineWidth', 1);

% Tracé 5 : facteur de sécurité (courbe + ligne de la cible)
h.courbeFS     = line('Parent', h.ax(5), 'XData', NaN, 'YData', NaN, ...
                      'Color', bleu, 'LineWidth', 1.5);
h.ligneFScible = line('Parent', h.ax(5), 'XData', NaN, 'YData', NaN, ...
                      'Color', rouge, 'LineStyle', '--', 'LineWidth', 1);

% Curseurs : un trait vertical rouge par tracé. Il indique l'instant montré
% par l'animation : c'est lui qui SYNCHRONISE l'animation et les tracés.
for i = 1:nTraces
    h.curseur(i) = line('Parent', h.ax(i), 'XData', [0 0], 'YData', [0 1], ...
                        'Color', rouge, 'LineWidth', 1);
end

% Légende du tracé 4. On la crée APRÈS les curseurs et on donne la liste
% exacte des lignes à nommer : ainsi, le curseur n'y apparaît pas.
legend(h.ax(4), [h.courbeFrequis, h.courbeFnorme, h.lignePoids], ...
       {'Effort nécessaire', 'Effort total', 'Poids'}, ...
       'Location', 'north', 'Orientation', 'horizontal', 'FontSize', 7);

% Tracé 5 : petite étiquette « FS exigé » posée sur la ligne pointillée
% (sa position est fixée dans afficherTraces).
h.texteFScible = text(0, 0, 'FS exigé', 'Parent', h.ax(5), 'Color', rouge, ...
                      'FontSize', 8, 'VerticalAlignment', 'bottom');

% Positions verticales des commandes de gauche (voir placerCommandes)
placerCommandes(h, S.modeDurees, false);

end


function placerCommandes(h, modeDurees, avance)
% PLACERCOMMANDES  Range les commandes de gauche de haut en bas.
%   Les lignes « Durée du transfert » (mode 3 seulement) et « réglages
%   avancés » (case cochée seulement) sont cachées quand elles ne servent
%   pas ; les lignes suivantes remontent. La zone « En ce moment » prend
%   toute la place qui reste au-dessus des boutons du bas.
%
%   Chaque ligne : {poignées, hauteur, espace sous la ligne, visible}

lignes = { ...
    h.lblMat,                                  0.028, 0.006, true; ...
    h.popMateriau,                             0.038, 0.014, true; ...
    h.lblMode,                                 0.028, 0.006, true; ...
    h.popMode,                                 0.038, 0.008, true; ...
    [h.lblT, h.editT],                         0.038, 0.006, modeDurees == 3; ...
    h.lblEquip,                                0.028, 0.006, true; ...
    h.caseAmort,                               0.034, 0.004, true; ...
    h.caseAvance,                              0.034, 0.008, true; ...
    [h.lblCouple, h.editCouple],               0.038, 0.006, avance; ...
    [h.lblFS, h.editFS],                       0.038, 0.006, avance; ...
    h.btnDefaut,                               0.038, 0.008, avance; ...
    h.lblAnim,                                 0.028, 0.006, true; ...
    [h.btnLancer, h.btnPause, h.btnArreter],   0.040, 0.008, true; ...
    [h.lblVitesse, h.popVitesse],              0.038, 0.008, true; ...
    h.lblGliss,                                0.026, 0.004, true; ...
    h.glissiere,                               0.028, 0.008, true; ...
    h.caseZoom,                                0.034, 0.010, true; ...
    h.lblInstant,                              0.028, 0.004, true};

y = 0.985;                              % haut de la zone utile du panneau
for k = 1:size(lignes, 1)
    poignees = lignes{k, 1};
    hauteur  = lignes{k, 2};
    if lignes{k, 4}
        y = y - hauteur;
        for p = poignees
            pos = get(p, 'Position');           % [gauche, bas, largeur, hauteur]
            % Une étiquette (hauteur 0,028) est centrée sur une ligne plus haute.
            decalage = (hauteur - pos(4)) / 2;
            set(p, 'Position', [pos(1), y + decalage, pos(3), pos(4)], 'Visible', 'on');
        end
        y = y - lignes{k, 3};
    else
        set(poignees, 'Visible', 'off');
    end
end

% Zone « En ce moment » : du bas de la dernière ligne aux boutons du bas
basZone = 0.112;
set(h.txtInstant, 'Position', [0.05, basZone, 0.90, max(y - basZone, 0.08)]);

% Les étiquettes du haut sont alignées à gauche avec les commandes
for p = [h.lblMat, h.lblMode, h.lblEquip, h.lblAnim, h.lblGliss, h.lblInstant, ...
         h.lblT, h.lblCouple, h.lblFS, h.lblVitesse]
    pos = get(p, 'Position');
    set(p, 'Position', [0.05, pos(2), pos(3), pos(4)]);
end

end


function basculerAvance(fig)
% BASCULERAVANCE  Montre ou cache les réglages avancés (couple et FS exigé).
%   Cacher ces réglages ne change pas leurs valeurs : le calcul continue
%   d'utiliser ce qui est écrit dans les cases.
S = guidata(fig);
placerCommandes(S.h, get(S.h.popMode, 'Value'), get(S.h.caseAvance, 'Value') == 1);
end


function hObjet = etiquette(parent, position, texte, enGras)
% ETIQUETTE  Crée un texte fixe (titre d'une commande) dans un panneau.
if enGras
    graisse = 'bold';
else
    graisse = 'normal';
end
hObjet = uicontrol('Parent', parent, 'Style', 'text', ...
    'Units', 'normalized', 'Position', position, ...
    'String', texte, 'FontWeight', graisse, ...
    'HorizontalAlignment', 'left', 'BackgroundColor', [0.94 0.94 0.94]);
end


function hObjet = bouton(parent, position, texte, action)
% BOUTON  Crée un bouton. « action » est la fonction exécutée au clic.
hObjet = uicontrol('Parent', parent, 'Style', 'pushbutton', ...
    'Units', 'normalized', 'Position', position, ...
    'String', texte, 'Callback', action);
end


function ajusterTableau(hTableau, fractions)
% AJUSTERTABLEAU  Règle la largeur des colonnes d'un tableau pour qu'il soit rempli.
%   hTableau    poignée du tableau (uitable)
%   fractions   part de la largeur donnée à chaque colonne (somme = 1)
%
%   Un tableau demande des largeurs de colonnes en PIXELS. On lit donc la
%   largeur du tableau en pixels, puis on la partage entre les colonnes.

% Lire la largeur du tableau en pixels, puis revenir aux unités d'origine
unites = get(hTableau, 'Units');
set(hTableau, 'Units', 'pixels');
position = get(hTableau, 'Position');       % [gauche, bas, largeur, hauteur]
set(hTableau, 'Units', unites);

% On garde 24 pixels pour les bordures et la barre de défilement verticale.
largeurUtile = max(position(3) - 24, 120);
largeurs     = floor(largeurUtile * fractions);

% 'ColumnWidth' attend une liste de cellules : num2cell([60 80]) donne {60, 80}.
set(hTableau, 'ColumnWidth', num2cell(largeurs));
end


% =================================================================================
%  GROUPE B - CALCUL ET AFFICHAGE
% =================================================================================

function mettreAJour(fig)
% METTREAJOUR  Lit les entrées, les valide, refait les calculs et rafraîchit l'affichage.
%   Cette fonction est appelée à l'ouverture, puis chaque fois que
%   l'utilisateur change la rondelle, la vitesse du bras, les amortisseurs,
%   le couple ou la marge de sécurité.
%
%   L'ORDRE DES CALCULS (depuis le 18 nov. 2026)
%     couple de l'actionneur  ->  durée minimale de chaque rotation
%                             ->  cycle complet de chaque matériau
%   La durée n'est jamais tapée : elle est soit calculée à partir du
%   couple, soit lue dans les mesures de la vidéo.

S = guidata(fig);
S.enMarche = false;                     % toute animation en cours est arrêtée
nMat = numel(S.P.materiaux);

% --- 1. Lire les choix de l'utilisateur ------------------------------------------
S.iMat       = get(S.h.popMateriau, 'Value');   % numéro de la ligne choisie
S.modeDurees = get(S.h.popMode, 'Value');       % 1 calculée, 2 vidéo, 3 imposée
couple       = lireNombre(S.h.editCouple);
FScible      = lireNombre(S.h.editFS);

% La case de durée n'est visible (et lue) qu'en mode « je choisis ».
placerCommandes(S.h, S.modeDurees, get(S.h.caseAvance, 'Value') == 1);
if S.modeDurees == 3
    Timpose = lireNombre(S.h.editT);
else
    Timpose = [];                       % [] = pas de durée à vérifier
end

% Amortisseurs (simulation) : la limite d'énergie Festo ne s'applique
% plus quand des butées externes ou des amortisseurs absorbent le choc.
S.P.actionneur.festo.actif = (get(S.h.caseAmort, 'Value') == 0);

% --- 2. Valider les entrées AVANT de calculer --------------------------------------
[valide, message] = validerEntrees(S.P, couple, FScible, Timpose);

if ~valide
    % Entrée invalide : on n'affiche AUCUN résultat (exigence de la consigne).
    S.valide = false;
    guidata(fig, S);
    effacerResultats(S);
    afficherMessage(S.h, 'erreur', {['VALEUR INVALIDE : ' message], ...
                    'Aucun calcul n''a été fait. Corrigez la valeur dans les réglages.'});
    return;
end

S.FScible = FScible;

% Le couple tapé devient LE couple de l'actionneur pour tous les calculs
% qui suivent (dureeCouple.m, verifierDomaine.m, sauvegarde, etc.).
S.P.actionneur.couple = couple;

% --- 3. Durées minimales permises par ce couple ----------------------------------------
% Transfert : une durée par matériau (la rondelle portée change l'inertie
% et le critère de la ventouse). Retour à vide : une seule durée.
for i = 1:nMat
    [S.Tmin(i), S.infoOpt{i}] = dureeMinimale(S.P, i, S.FScible);
end
% Retour à vide : pas de critère de succion. Seules les limites de
% l'actionneur comptent : couple, fréquence et, depuis le 19 nov. 2026,
% l'énergie en fin de course (fiche Festo, sans butées externes).
[S.TretourMin, S.infoRetour] = dureeCouple(S.P, 0, S.P.thetaDepot, S.P.thetaPrise);
S.limiteRetour = 'couple';
if S.P.actionneur.verifier && ~isnan(S.TretourMin)
    candidats = [S.TretourMin, S.P.actionneur.dureeMin];
    noms      = {'couple', 'frequence'};
    if S.P.actionneur.festo.actif
        candidats(end+1) = dureeFesto(S.P, 0, S.P.thetaDepot, S.P.thetaPrise);
        noms{end+1}      = 'festo';
    end
    [S.TretourMin, k] = max(candidats);
    S.limiteRetour    = noms{k};
end

% --- 4. Durées réellement utilisées pour le cycle -----------------------------------------
% On arrondit VERS LE HAUT au millième de seconde (fonction ceil) pour
% rester du côté sûr : une durée un peu plus longue donne un FS un peu
% plus grand que la cible, jamais plus petit, et un couple requis un peu
% plus petit que celui de l'actionneur, jamais plus grand.
% En mode « imposée », la durée tapée peut être plus courte que la durée
% minimale : le calcul se fait quand même, et verifierDomaine signale
% alors que le couple ou le FS cible est dépassé (domaine de validité).
switch S.modeDurees
    case 1      % calculée à partir du couple
        Ttransfert = ceil(S.Tmin * 1000) / 1000;          % un par matériau
        Tretour    = ceil(S.TretourMin * 1000) / 1000;
    case 2      % mesures de la vidéo
        Ttransfert = S.P.duree.transfert * ones(1, nMat);
        Tretour    = S.P.duree.retour;
    otherwise   % imposée par l'utilisateur ; le retour garde sa durée mesurée
        Ttransfert = Timpose * ones(1, nMat);
        Tretour    = S.P.duree.retour;
end

% --- 5. Calculer le cycle pour les trois matériaux ---------------------------------------
% Un matériau que ce couple ne peut pas soulever reste vide ([]) : le
% tableau l'affichera comme « impossible ». (En mode vidéo, les durées
% sont imposées, donc tous les cycles existent ; si le couple ne permet
% pas de les tenir, verifierDomaine le signalera.)
for i = 1:nMat
    if isnan(Ttransfert(i)) || isnan(Tretour)
        S.R{i} = [];
    else
        S.R{i} = calculerCycle(S.P, i, Ttransfert(i), Tretour);
    end
end

% --- 6. Le couple suffit-il pour le matériau choisi ? -------------------------------------
% Si la gravité seule demande déjà plus que l'actionneur ne donne, aucune
% durée ne convient : ce n'est pas une erreur de saisie, c'est un résultat.
% On garde quand même le tableau à l'écran : il montre quels matériaux
% CE couple permet de déplacer.
if isempty(S.R{S.iMat})
    if isnan(Tretour)
        explication = S.infoRetour.message;
    else
        explication = S.infoOpt{S.iMat}.message;
    end
    S.valide = false;
    guidata(fig, S);
    effacerResultats(S);
    afficherTableau(S);
    afficherMessage(S.h, 'alerte', {sprintf(['IMPOSSIBLE : le vérin (%.2f N.m) n''a pas ' ...
        'assez de force pour soulever la rondelle en %s.'], couple, S.P.materiaux(S.iMat).nom), ...
        'Augmentez le couple dans les réglages avancés.'});
    S.lignesDomaine = {explication};
    guidata(fig, S);
    return;
end

S.valide = true;

% --- 7. Redessiner l'animation au début du cycle --------------------------------------
S.tCourant = 0;
S.scene    = creerScene(S.h.axScene, S.P, S.R{S.iMat});

% La glissière couvre maintenant toute la durée du nouveau cycle.
% (On remet d'abord sa valeur à 0 pour qu'elle reste entre Min et Max.)
set(S.h.glissiere, 'Value', 0);
set(S.h.glissiere, 'Max', S.R{S.iMat}.dureeCycle);

% --- 8. Enregistrer, puis rafraîchir tout l'affichage ----------------------------------
guidata(fig, S);

afficherTraces(S);
afficherResume(S);
afficherTableau(S);
afficherInstant(S);

% Le jugement complet (verifierDomaine) est gardé pour « Détails
% techniques » ; le bandeau en donne une version en langage simple.
[niveau, S.lignesDomaine] = verifierDomaine(S.P, S.R{S.iMat}, S.FScible);
guidata(fig, S);
afficherMessage(S.h, niveau, messageSimple(S, niveau));

end


function valeur = lireNombre(hCase)
% LIRENOMBRE  Lit le nombre tapé dans une case à remplir.
%   On accepte la virgule décimale française (« 0,9 ») en la remplaçant
%   par un point. Si le texte n'est pas un nombre, str2double retourne NaN
%   et validerEntrees.m signalera l'erreur.
texte  = get(hCase, 'String');
texte  = strrep(texte, ',', '.');
valeur = str2double(texte);
end


function afficherTraces(S)
% AFFICHERTRACES  Met à jour les cinq tracés pour le matériau choisi.

res = S.R{S.iMat};
t   = res.t;
h   = S.h;

% --- Tracés 1 à 3 : mouvement du bras -----------------------------------------------
% L'angle est converti en degrés pour l'affichage (180/pi).
set(h.courbe(1), 'XData', t, 'YData', res.theta * 180/pi);
set(h.courbe(2), 'XData', t, 'YData', res.omega);
set(h.courbe(3), 'XData', t, 'YData', res.alpha);

% --- Tracé 4 : effort de la ventouse ---------------------------------------------------
set(h.courbeFrequis, 'XData', t, 'YData', res.Frequis);
set(h.courbeFnorme,  'XData', t, 'YData', res.Fnorme);
set(h.lignePoids,    'XData', [0, res.dureeCycle], 'YData', [res.poids, res.poids]);

% --- Tracé 5 : facteur de sécurité ------------------------------------------------------
set(h.courbeFS,     'XData', t, 'YData', res.FS);
set(h.ligneFScible, 'XData', [0, res.dureeCycle], 'YData', [S.FScible, S.FScible]);

% --- Échelles verticales ------------------------------------------------------------------
% On les fixe nous-mêmes pour que les curseurs couvrent toute la hauteur.
limites = zeros(5, 2);
limites(1, :) = bornes(res.theta * 180/pi);
limites(2, :) = bornes(res.omega);
limites(3, :) = bornes(res.alpha);
% Effort : de 0 à un peu plus que la plus grande valeur (place pour la légende)
limites(4, :) = [0, 1.55 * max([res.FrequisMax, res.FnormeMax, res.poids])];
% Facteur de sécurité : de 0 à un peu plus que la valeur bras immobile.
% (Le FS peut devenir très grand en haut de la trajectoire ; on coupe.)
limites(5, :) = [0, max(1.7 * res.FSstatique, 1.7 * S.FScible)];

% --- Échelle horizontale (temps) ---------------------------------------------------------------
% Case « zoom » cochée : on montre seulement l'étape 2 (le transfert), avec
% une petite marge de chaque côté. Sinon : le cycle complet.
if get(h.caseZoom, 'Value') == 1
    marge    = 0.08 * (res.tFinEtape(4) - res.tDebutEtape(4));
    limTemps = [res.tDebutEtape(4) - marge, res.tFinEtape(4) + marge];
else
    limTemps = [0, res.dureeCycle];
end

for i = 1:5
    set(h.ax(i), 'XLim', limTemps, 'YLim', limites(i, :));
    set(h.curseur(i), 'YData', limites(i, :));
end

% Étiquette « FS cible » : au bord gauche du tracé, juste au-dessus de la ligne
set(h.texteFScible, 'Position', [limTemps(1) + 0.015 * (limTemps(2) - limTemps(1)), S.FScible, 0]);

end


function lim = bornes(y)
% BORNES  Limites d'un axe vertical : du minimum au maximum de y, avec une marge de 10 %.
yMin = min(y);
yMax = max(y);
marge = 0.10 * (yMax - yMin);
if marge == 0
    marge = 1;                          % courbe plate : marge arbitraire
end
lim = [yMin - marge, yMax + marge];
end


function texte = nomLimite(limite, court)
% NOMLIMITE  Nom en mots simples de la limite qui fixe une durée.
%   limite : 'ventouse', 'couple', 'frequence', 'festo' ou 'aucune'
%   court  : true pour le tableau (un mot), false pour une phrase
switch limite
    case 'ventouse'
        noms = {'Ventouse', 'la prise de la ventouse'};
    case 'couple'
        noms = {'Couple', 'la force du vérin (couple)'};
    case 'frequence'
        noms = {'Fréq.', 'la fréquence du vérin'};
    case 'festo'
        noms = {'Chocs', 'les chocs en fin de course'};
    otherwise
        noms = {'-', 'aucune limite'};
end
if court
    texte = noms{1};
else
    texte = noms{2};
end
end


function afficherResume(S)
% AFFICHERRESUME  Résume en phrases le cas choisi (panneau « Résultats »).
%   [Claude] Remplace depuis le 19 nov. 2026 la liste de valeurs
%   techniques, qui est maintenant dans « Détails techniques ».
%   On y garde : la cadence (comparée à la machine actuelle), la durée de
%   chaque rotation et ce qui la limite, la sécurité de la prise, et la
%   durée minimale compatible avec le FS exigé (point d de la consigne).

res  = S.R{S.iMat};
info = S.infoOpt{S.iMat};
P    = S.P;
cVid = P.dureeCycle;                    % [s] cycle mesuré sur la vidéo

switch S.modeDurees
    case 1
        origine = 'vitesse max.';
    case 2
        origine = 'machine actuelle';
    otherwise
        origine = 'durée choisie';
end

lignes = {sprintf('RONDELLE EN %s (%s)', upper(res.nomMateriau), origine), ...
          sprintf('Cycle complet : %.2f s, soit %.1f rondelles/min', res.dureeCycle, res.cadence), ...
          sprintf('   Machine actuelle : %.2f s, soit %.1f rondelles/min', cVid, 60 / cVid), ...
          ''};

if S.modeDurees == 1
    lignes{end+1} = sprintf('Transfert : %.3f s', res.T);
    lignes{end+1} = ['   limité par ' nomLimite(info.limite, false)];
    lignes{end+1} = sprintf('Retour à vide : %.3f s', res.Tretour);
    lignes{end+1} = ['   limité par ' nomLimite(S.limiteRetour, false)];
else
    lignes{end+1} = sprintf('Transfert : %.3f s   (minimum permis : %s s)', res.T, ...
                            texteDuree(S.Tmin(S.iMat)));
    lignes{end+1} = sprintf('Retour à vide : %.3f s   (minimum permis : %s s)', res.Tretour, ...
                            texteDuree(S.TretourMin));
end

lignes{end+1} = '';
lignes{end+1} = sprintf('Prise : FS minimal %.1f (exigé : %.1f)', res.FSmin, S.FScible);
lignes{end+1} = sprintf('Transfert le plus court sûr pour la ventouse : %s s', ...
                        texteDuree(info.Tventouse));

set(S.h.txtResume, 'String', lignes);

end


function afficherTableau(S)
% AFFICHERTABLEAU  Remplit le tableau comparatif des trois rondelles.
%   Une ligne par rondelle. En mode « la plus rapide permise », chaque
%   rondelle tourne à SA propre durée minimale : le tableau compare donc
%   les trois rondelles chacune à sa vitesse maximale. Le détail des
%   durées par contrainte est dans « Détails techniques ».
%
%   Si le couple ne suffit pas à soulever une rondelle, sa ligne indique
%   « impossible » au lieu des résultats.

nMat    = numel(S.P.materiaux);
donnees = cell(nMat, 6);                % tableau de cellules (texte)

for i = 1:nMat
    donnees{i, 1} = S.P.materiaux(i).nom;
    donnees{i, 2} = sprintf('%.0f', 1000 * massePiece(S.P, i));

    if isempty(S.R{i})
        donnees(i, 3:6) = {'impossible', '-', '-', '-'};
        continue;
    end

    donnees{i, 3} = sprintf('%.3f', S.R{i}.T);
    switch S.modeDurees
        case 1
            donnees{i, 4} = nomLimite(S.infoOpt{i}.limite, true);
        case 2
            donnees{i, 4} = '(vidéo)';
        otherwise
            donnees{i, 4} = '(choisie)';
    end
    donnees{i, 5} = sprintf('%.2f', S.R{i}.dureeCycle);
    donnees{i, 6} = sprintf('%.1f', S.R{i}.FSmin);
end

set(S.h.tableau, 'Data', donnees);

end


function lignes = lignesValeurs(S)
% LIGNESVALEURS  Valeurs techniques du cas choisi (fenêtre « Détails techniques »).

res = S.R{S.iMat};
P   = S.P;

lignes = { ...
    sprintf('MATÉRIAU CHOISI : %s', res.nomMateriau), ...
    sprintf('Masse : %.1f g     Poids : %.3f N', res.masse * 1000, res.poids), ...
    sprintf('Force de maintien : %.2f N', res.Fvide), ...
    sprintf('   (vide %.0f kPa, ventouse %.0f mm)', P.vide / 1000, P.ventouse.diametre * 1000), ...
    sprintf('Effort max : %.3f N (t = %.2f s)', res.FnormeMax, res.tFnormeMax), ...
    sprintf('Maintien requis max : %.3f N', res.FrequisMax), ...
    sprintf('FS minimal : %.2f (t = %.2f s)', res.FSmin, res.tFSmin), ...
    sprintf('FS bras immobile : %.2f', res.FSstatique), ...
    sprintf('Amplitude du bras : %.1f°', res.amplitude * 180/pi), ...
    sprintf('Couple max au pivot : %.2f N.m', res.coupleMax), ...
    sprintf('   (actionneur : %.2f N.m)', P.actionneur.couple), ...
    sprintf('Durée du cycle : %.2f s', res.dureeCycle), ...
    sprintf('Cadence : %.2f pièces/min', res.cadence)};

end


function donnees = donneesTableauDetaille(S)
% DONNEESTABLEAUDETAILLE  Durées minimales par contrainte, pour les trois matériaux.
%   T FS     : durée minimale pour que FS >= FS cible (consigne, point d) ;
%   T couple : durée minimale que permet le couple de l'actionneur ;
%   T Festo  : durée minimale selon l'énergie en fin de course (fiche
%              Festo, sans butées externes) ;
%   T min    : la plus longue des limites, donc la durée retenue.

nMat    = numel(S.P.materiaux);
donnees = cell(nMat, 7);
for i = 1:nMat
    info = S.infoOpt{i};
    donnees{i, 1} = S.P.materiaux(i).nom;
    if isempty(S.R{i})
        donnees(i, 2:3) = {'-', '-'};
    else
        donnees{i, 2} = sprintf('%.3f', S.R{i}.FnormeMax);
        donnees{i, 3} = sprintf('%.2f', S.R{i}.FSmin);
    end
    donnees{i, 4} = texteDuree(info.Tventouse);
    donnees{i, 5} = texteDuree(info.Tcouple);
    donnees{i, 6} = texteDuree(info.Tfesto);
    if isnan(S.Tmin(i))
        donnees{i, 7} = 'impossible';
    else
        donnees{i, 7} = sprintf('%.3f', S.Tmin(i));
    end
end
end


function lignes = lignesDurees(S)
% LIGNESDUREES  D'où viennent les durées des deux rotations (« Détails techniques »).

i     = S.iMat;
res   = S.R{i};
info  = S.infoOpt{i};
P     = S.P;
cVid  = P.dureeCycle;                   % [s] cycle mesuré sur la vidéo

lignes = {sprintf('DURÉES DES ROTATIONS - %s, couple %.2f N.m', ...
                  res.nomMateriau, P.actionneur.couple)};
lignes{end+1} = sprintf('Transfert utilisé (étape 4) : %.3f s', res.T);
lignes{end+1} = '   Durées minimales selon chaque limite :';
lignes{end+1} = sprintf('   - ventouse (FS >= %.2f, consigne point d) : %s s', ...
                        S.FScible, texteDuree(info.Tventouse));
lignes{end+1} = sprintf('   - couple de l''actionneur : %s s', texteDuree(info.Tcouple));
lignes{end+1} = sprintf('   - fréquence maximale : %s s', texteDuree(info.Tfrequence));
if P.actionneur.festo.actif
    lignes{end+1} = sprintf('   - énergie en fin de course (Festo) : %s s', texteDuree(info.Tfesto));
else
    lignes{end+1} = '   - énergie en fin de course : non appliquée (amortisseurs)';
end
lignes{end+1} = sprintf('   Minimum retenu : %s s (limite : %s)', texteDuree(S.Tmin(i)), ...
                        upper(info.limite));
lignes{end+1} = sprintf('Retour à vide utilisé (étape 2) : %.3f s', res.Tretour);
lignes{end+1} = sprintf('   Minimum : %s s (limite : %s)', texteDuree(S.TretourMin), ...
                        upper(S.limiteRetour));
lignes{end+1} = sprintf('Cycle : %.2f s (%.2f pièces/min) ; vidéo : %.2f s (%.2f)', ...
                        res.dureeCycle, res.cadence, cVid, 60 / cVid);

end


function lignes = messageSimple(S, niveau)
% MESSAGESIMPLE  Message du bandeau, en langage simple.
%   Le jugement technique complet vient de verifierDomaine.m et reste
%   affiché dans « Détails techniques ». Ici, on dit seulement ce que
%   l'utilisateur doit savoir, et quoi faire.

res = S.R{S.iMat};
P   = S.P;
lignes = {};

% 1. La rondelle est-elle bien tenue ?
if res.FSmin < 1
    lignes{end+1} = sprintf('DANGER : la rondelle tombe pendant le transfert (à t = %.2f s).', ...
                            res.tFSmin);
elseif res.FSmin < S.FScible
    lignes{end+1} = sprintf(['ATTENTION : la rondelle est tenue, mais avec une marge trop faible ' ...
                             '(FS %.1f au lieu de %.1f).'], res.FSmin, S.FScible);
end

% 2. Le vérin est-il utilisé dans ses limites ?
if P.actionneur.verifier
    if res.coupleMax > P.actionneur.couple || res.T < P.actionneur.dureeMin
        lignes{end+1} = 'ATTENTION : cette vitesse dépasse ce que le vérin peut faire.';
    end
    if P.actionneur.festo.actif
        Emax = P.actionneur.festo.energieMax;
        Etr  = energieFinCourse(P, res.masse, res.T,       P.thetaPrise, P.thetaDepot);
        Eret = energieFinCourse(P, 0,         res.Tretour, P.thetaDepot, P.thetaPrise);
        rapport = max(Etr, Eret) / Emax;
        if rapport > 1.001
            lignes{end+1} = sprintf(['ATTENTION : chocs trop forts en fin de course (%.1f fois ' ...
                                     'la limite du fabricant).'], rapport);
            lignes{end+1} = '   Il faut des amortisseurs, ou ralentir le bras.';
        end
    end
end

% 3. Tout va bien
if isempty(lignes)
    lignes{end+1} = ['Tout est correct : la rondelle est bien tenue et le vérin reste ' ...
                     'dans ses limites.'];
    if ~P.actionneur.festo.actif
        lignes{end+1} = '   Simulation avec amortisseurs : la machine actuelle n''en a pas.';
    elseif strcmp(niveau, 'ok')
        lignes{end+1} = '   Détails : bouton « Détails techniques ».';
    end
end

if ~strcmp(niveau, 'ok') && numel(lignes) < 3
    lignes{end+1} = '   Explications complètes : bouton « Détails techniques ».';
end

end


function texte = texteDuree(T)
% TEXTEDUREE  Écrit une durée [s] avec 3 décimales, ou « - » si elle n'existe pas.
%   Une durée vaut NaN quand la contrainte correspondante n'a pas pu être
%   calculée (par exemple : couple insuffisant, ou vérification du couple
%   désactivée avec P.actionneur.verifier = false).
if isnan(T)
    texte = '-';
else
    texte = sprintf('%.3f', T);
end
end


function afficherInstant(S)
% AFFICHERINSTANT  Affiche l'état du système à l'instant S.tCourant.
%   C'est ici que l'animation et les tracés sont synchronisés : la MÊME
%   valeur de temps place les objets de l'animation, les cinq curseurs
%   rouges, la glissière et les valeurs instantanées.

res = S.R{S.iMat};
t   = S.tCourant;

% Numéro du point de calcul le plus proche avant l'instant t.
% find(condition, 1, 'last') donne la position du DERNIER élément qui
% respecte la condition.
k = find(res.t <= t, 1, 'last');
if isempty(k)
    k = 1;
end

% --- 1. Animation ----------------------------------------------------------------------
majScene(S.scene, S.P, res, k);

% --- 2. Curseurs des cinq tracés --------------------------------------------------------
for i = 1:5
    set(S.h.curseur(i), 'XData', [t, t]);
end

% --- 3. Glissière --------------------------------------------------------------------------
set(S.h.glissiere, 'Value', min(max(t, 0), res.dureeCycle));

% --- 4. Valeurs à cet instant ------------------------------------------------------------------
% [Claude] Version en langage simple (19 nov. 2026) : nom de l'étape,
% effort du vérin en pourcentage de son maximum, état de la rondelle.
nomEtape = res.nomsEtapes{res.etape(k)};            % ex. « 4. Transfert »
lignes = { ...
    sprintf('t = %.2f s : %s', t, nomEtape(4:end)), ...
    sprintf('Angle du bras : %.0f°', res.theta(k) * 180/pi), ...
    sprintf('Vitesse du bras : %.2f rad/s', res.omega(k)), ...
    sprintf('Effort du vérin : %.0f %% de son maximum', ...
            100 * abs(res.couple(k)) / S.P.actionneur.couple)};

if res.tenue(k)
    lignes{end+1} = sprintf('Rondelle tenue : FS = %.1f', res.FS(k));
else
    lignes{end+1} = 'Pas de rondelle dans la ventouse';
end

set(S.h.txtInstant, 'String', lignes);

end


function afficherMessage(h, niveau, lignes)
% AFFICHERMESSAGE  Écrit un message dans le bandeau, avec une couleur selon la gravité.
%   niveau : 'ok' (vert), 'avertissement' (orange), 'alerte' ou 'erreur' (rouge)
%   lignes : liste de phrases (tableau de cellules)

switch niveau
    case 'ok'
        couleur = [0.78 0.93 0.78];     % vert pâle
    case 'avertissement'
        couleur = [1.00 0.85 0.55];     % orange pâle
    otherwise
        couleur = [1.00 0.70 0.70];     % rouge pâle
end

set(h.txtMessage, 'String', lignes, 'BackgroundColor', couleur);

end


function effacerResultats(S)
% EFFACERRESULTATS  Vide tous les affichages quand une entrée est invalide.
%   But : ne jamais laisser à l'écran un résultat qui ne correspond pas
%   aux valeurs tapées.

h = S.h;

% Courbes : NaN = rien à tracer
set(h.courbe(1), 'XData', NaN, 'YData', NaN);
set(h.courbe(2), 'XData', NaN, 'YData', NaN);
set(h.courbe(3), 'XData', NaN, 'YData', NaN);
set(h.courbeFrequis, 'XData', NaN, 'YData', NaN);
set(h.courbeFnorme,  'XData', NaN, 'YData', NaN);
set(h.lignePoids,    'XData', NaN, 'YData', NaN);
set(h.courbeFS,      'XData', NaN, 'YData', NaN);
set(h.ligneFScible,  'XData', NaN, 'YData', NaN);
for i = 1:5
    set(h.curseur(i), 'XData', [NaN NaN]);
end

% Textes et tableau
set(h.txtResume,  'String', 'Aucun résultat : une valeur des réglages est invalide.');
set(h.txtInstant, 'String', '');
set(h.tableau,    'Data', cell(numel(S.P.materiaux), 6));

% Animation
cla(h.axScene);
title(h.axScene, 'Animation indisponible : entrée invalide');

end


% =================================================================================
%  GROUPE C - ANIMATION
% =================================================================================

function lancerAnimation(fig)
% LANCERANIMATION  Fait défiler le cycle (bouton « Lancer »).
%
%   PRINCIPE : une boucle qui se répète environ 50 fois par seconde.
%   À chaque tour :
%     1. on mesure le temps réel écoulé depuis le tour précédent (tic/toc) ;
%     2. on avance l'instant affiché de ce temps, multiplié par la vitesse
%        d'animation choisie ;
%     3. on redessine l'animation et les curseurs (afficherInstant) ;
%     4. on laisse Matlab afficher le résultat et traiter les clics
%        (drawnow et pause).
%   La boucle s'arrête à la fin du cycle, ou si l'utilisateur clique sur
%   « Pause » ou « Arrêter » (S.enMarche devient faux), ou ferme la fenêtre.

S = guidata(fig);

if ~S.valide || S.enMarche
    return;                 % rien à animer, ou animation déjà en cours
end

dureeCycle = S.R{S.iMat}.dureeCycle;

% Si le cycle était terminé, on repart du début.
if S.tCourant >= dureeCycle
    S.tCourant = 0;
end

S.enMarche = true;
guidata(fig, S);

chrono = tic;               % démarre un chronomètre

while true

    % La fenêtre a-t-elle été fermée pendant l'animation ?
    if ~ishandle(fig)
        return;
    end

    % On relit S à chaque tour : un clic sur un bouton a pu la modifier.
    S = guidata(fig);
    if ~S.enMarche
        break;              % « Pause », « Arrêter » ou nouveau calcul
    end

    % Temps réel écoulé depuis le tour précédent [s]
    tempsReel = toc(chrono);
    chrono    = tic;

    % Nouvel instant affiché dans le cycle [s]
    S.tCourant = S.tCourant + tempsReel * S.vitesse;

    termine = (S.tCourant >= dureeCycle);
    if termine
        S.tCourant = dureeCycle;
        S.enMarche = false;
    end

    guidata(fig, S);        % enregistrer AVANT de laisser Matlab traiter les clics
    afficherInstant(S);

    drawnow;                % afficher l'image et traiter les clics en attente
    pause(0.01);            % courte pause : laisse du temps au reste de Matlab

    if termine
        break;
    end
end

end


function mettreEnPause(fig)
% METTREENPAUSE  Fige l'animation à l'instant courant (bouton « Pause »).
%   « Lancer » la fera repartir du même instant.
S = guidata(fig);
S.enMarche = false;
guidata(fig, S);
end


function arreterAnimation(fig)
% ARRETERANIMATION  Arrête l'animation et revient au début du cycle (bouton « Arrêter »).
S = guidata(fig);
S.enMarche = false;
S.tCourant = 0;
guidata(fig, S);
if S.valide
    afficherInstant(S);
end
end


function deplacerGlissiere(fig)
% DEPLACERGLISSIERE  Affiche l'instant choisi à la main avec la glissière.
S = guidata(fig);
S.enMarche = false;                         % on arrête l'animation
S.tCourant = get(S.h.glissiere, 'Value');   % position de la glissière = temps [s]
guidata(fig, S);
if S.valide
    afficherInstant(S);
end
end


function changerZoom(fig)
% CHANGERZOOM  Agrandit les tracés sur le transfert, ou revient au cycle complet.
%   Seule l'échelle de temps des tracés change. Les calculs ne changent pas.
S = guidata(fig);
if S.valide
    afficherTraces(S);
    afficherInstant(S);
end
end


function changerVitesse(fig)
% CHANGERVITESSE  Enregistre la vitesse d'animation choisie dans le menu.
%   Une vitesse de 0,25 x montre le cycle quatre fois plus lentement que
%   la réalité. Les calculs ne changent pas.
S = guidata(fig);
S.vitesse = S.vitesses(get(S.h.popVitesse, 'Value'));
guidata(fig, S);
end


% =================================================================================
%  GROUPE D - AUTRES BOUTONS
% =================================================================================

function valeursParDefaut(fig)
% VALEURSPARDEFAUT  Remet le couple du catalogue Festo et la marge de sécurité de l'équipe.
%
%   [Claude] Remplace depuis le 19 nov. 2026 le bouton « Couple du
%   catalogue Festo » : il remet aussi le FS exigé à la valeur justifiée
%   par l'équipe (parametres.m).
S  = guidata(fig);
P0 = parametres();
set(S.h.editCouple, 'String', sprintf('%.2f', P0.actionneur.coupleCatalogue));
set(S.h.editFS,     'String', sprintf('%.2f', P0.FScible));
mettreAJour(fig);
end


function sauvegarder(fig)
% SAUVEGARDER  Enregistre les résultats dans un fichier texte choisi par l'utilisateur.

S = guidata(fig);
if ~S.valide
    afficherMessage(S.h, 'erreur', {'Rien à sauvegarder : les entrées sont invalides.'});
    return;
end

% Nom proposé : resultats_RED_<matériau>_<date et heure>.txt
nomPropose = sprintf('resultats_RED_%s_%s.txt', S.P.materiaux(S.iMat).nom, ...
                     datestr(now, 'yyyy-mm-dd_HHMMSS'));

% uiputfile ouvre la fenêtre habituelle « Enregistrer sous ».
[nomFichier, dossier] = uiputfile('*.txt', 'Sauvegarder les résultats', nomPropose);
if isequal(nomFichier, 0)
    return;                 % l'utilisateur a cliqué sur « Annuler »
end

chemin = fullfile(dossier, nomFichier);
reussi = sauvegarderResultats(chemin, S.P, S.R, S.iMat, S.FScible, S.Tmin, S.infoOpt, ...
                              S.modeDurees, S.TretourMin);

if reussi
    [niveau, ~] = verifierDomaine(S.P, S.R{S.iMat}, S.FScible);
    afficherMessage(S.h, niveau, {['Résultats sauvegardés dans : ' chemin]});
else
    afficherMessage(S.h, 'erreur', {['Impossible d''écrire le fichier : ' chemin]});
end

end


function montrerDetails(fig)
% MONTRERDETAILS  Ouvre une fenêtre avec tous les résultats techniques.
%   [Claude] Ajoutée le 19 nov. 2026 avec la simplification de l'interface.
%   Rien n'a été retiré du programme : les valeurs clés, les durées par
%   contrainte (dont le point d de la consigne), le jugement complet du
%   domaine de validité, le tableau des hypothèses et les tests sont ici.
%   La fenêtre montre l'état au moment où on l'ouvre.

S = guidata(fig);
if ~S.valide
    afficherMessage(S.h, 'erreur', {'Aucun détail : corrigez d''abord les réglages.'});
    return;
end

figD = figure('Name', 'Détails techniques', 'NumberTitle', 'off', 'MenuBar', 'none', ...
              'Units', 'normalized', 'Position', [0.10 0.10 0.80 0.75], ...
              'Color', [0.94 0.94 0.94]);
fond = [0.94 0.94 0.94];

etiquette(figD, [0.02 0.94 0.30 0.04], 'VALEURS CLÉS DU CAS CHOISI', true);
uicontrol('Parent', figD, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.02 0.42 0.30 0.52], 'String', lignesValeurs(S), ...
          'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

etiquette(figD, [0.34 0.94 0.64 0.04], ...
          'DURÉES MINIMALES DU TRANSFERT PAR LIMITE (s), POUR LES TROIS MATÉRIAUX', true);
hT = uitable('Parent', figD, 'Units', 'normalized', 'Position', [0.34 0.72 0.64 0.22], ...
             'ColumnName', {'Matériau', 'Effort max (N)', 'FS min', 'T FS (point d)', ...
                            'T couple', 'T Festo', 'T min retenu'}, ...
             'RowName', [], 'Data', donneesTableauDetaille(S));
ajusterTableau(hT, [0.16 0.15 0.10 0.16 0.14 0.14 0.15]);

uicontrol('Parent', figD, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.34 0.42 0.64 0.28], 'String', lignesDurees(S), ...
          'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

etiquette(figD, [0.02 0.36 0.96 0.04], 'JUGEMENT COMPLET DU DOMAINE DE VALIDITÉ', true);
uicontrol('Parent', figD, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.02 0.12 0.96 0.24], 'String', S.lignesDomaine, ...
          'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

uicontrol('Parent', figD, 'Style', 'pushbutton', 'Units', 'normalized', ...
          'Position', [0.02 0.03 0.30 0.06], 'String', 'Tableau des hypothèses', ...
          'Callback', @(~, ~) montrerHypotheses(fig));
uicontrol('Parent', figD, 'Style', 'pushbutton', 'Units', 'normalized', ...
          'Position', [0.35 0.03 0.30 0.06], 'String', 'Tests et vérification', ...
          'Callback', @(~, ~) lancerVerifications(fig));
uicontrol('Parent', figD, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.68 0.03 0.30 0.06], 'BackgroundColor', fond, ...
          'HorizontalAlignment', 'left', 'FontSize', 8, ...
          'String', {'Les tableaux des tests s''écrivent dans la', ...
                     'fenêtre de commande de Matlab.'});
end


function montrerAide()
% MONTRERAIDE  Ouvre un court mode d'emploi en langage simple.
%   [Claude] Ajoutée le 19 nov. 2026 pour les utilisateurs du Consortium
%   des mini-usines de l'Estrie.

figA = figure('Name', 'Aide - comment utiliser le programme', 'NumberTitle', 'off', ...
              'MenuBar', 'none', 'Units', 'normalized', 'Position', [0.25 0.12 0.50 0.76], ...
              'Color', [1 1 1]);
texte = { ...
  'À QUOI SERT CE PROGRAMME', ...
  'Il simule le bras qui prend une rondelle et la dépose plus loin. Il calcule la vitesse', ...
  'la plus grande possible sans échapper la rondelle et sans abîmer le vérin, et la', ...
  'cadence obtenue (rondelles par minute).', ...
  '', ...
  'EN TROIS ÉTAPES', ...
  '1. Choisissez la rondelle (Delrin, aluminium ou acier).', ...
  '2. Choisissez la vitesse du bras :', ...
  '   - « La plus rapide permise » : le programme trouve la vitesse maximale sûre ;', ...
  '   - « Comme la machine actuelle » : les durées mesurées sur la vidéo ;', ...
  '   - « Je choisis la durée » : tapez la durée du transfert en secondes.', ...
  '3. Équipement : cochez « Ajouter des amortisseurs » pour voir ce que la machine', ...
  '   pourrait faire avec des amortisseurs ou des butées externes.', ...
  '', ...
  'Cliquez ensuite sur « Lancer » pour voir le cycle. Les graphiques de droite suivent', ...
  'l''animation : le trait rouge vertical montre l''instant affiché.', ...
  '', ...
  'COMMENT LIRE LE MESSAGE EN COULEUR', ...
  '   Vert : tout est correct.   Orange : attention, lire le message.', ...
  '   Rouge : la rondelle risque de tomber, ou une valeur tapée est invalide.', ...
  '', ...
  'PETIT LEXIQUE', ...
  '   Transfert : rotation du bras avec la rondelle. Retour : rotation à vide.', ...
  '   Facteur de sécurité (FS) : combien de fois la ventouse tient plus que l''effort', ...
  '      nécessaire. Il doit rester au-dessus de la marge exigée (2 par défaut).', ...
  '   Couple : force de rotation du vérin (2 N.m pour le vérin Festo DSR-16 actuel).', ...
  '   Chocs en fin de course : en arrivant au bout, le bras frappe les butées', ...
  '      souples du vérin. Le fabricant limite l''énergie de ce choc ; sans', ...
  '      amortisseurs, c''est souvent cette limite qui fixe la vitesse.', ...
  '', ...
  'POUR ALLER PLUS LOIN', ...
  '   « Réglages avancés » : couple du vérin et marge de sécurité exigée.', ...
  '   « Détails techniques » : toutes les valeurs calculées, les hypothèses et les tests.', ...
  '   « Sauvegarder » : écrit tous les résultats dans un fichier texte.'};
uicontrol('Parent', figA, 'Style', 'text', 'Units', 'normalized', ...
          'Position', [0.04 0.02 0.92 0.96], 'String', texte, ...
          'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1], 'FontSize', 10);
end


function montrerHypotheses(fig)
% MONTRERHYPOTHESES  Ouvre une deuxième fenêtre avec le tableau des hypothèses.

S   = guidata(fig);
tab = tableauHypotheses(S.P);           % 1re ligne = titres des colonnes

fig2 = figure('Name', 'Hypothèses, valeurs estimées et unités', ...
              'NumberTitle', 'off', 'MenuBar', 'none', ...
              'Units', 'normalized', 'Position', [0.05 0.12 0.90 0.74]);

hTab = uitable('Parent', fig2, 'Units', 'normalized', 'Position', [0.01 0.01 0.98 0.98], ...
               'ColumnName', tab(1, :), ...
               'RowName', [], ...
               'Data', tab(2:end, :));
ajusterTableau(hTab, [0.22 0.06 0.05 0.05 0.52 0.10]);

end


function lancerVerifications(fig)
% LANCERVERIFICATIONS  Exécute la matrice de tests et la vérification indépendante.
%   Les tableaux détaillés s'écrivent dans la fenêtre de commande de Matlab.

S = guidata(fig);

nEchecs = testsRED();

if S.valide
    % La vérification se fait à la durée de transfert réellement utilisée
    % pour le matériau choisi (calculée ou mesurée, selon le mode).
    verifIndependante(S.P, S.iMat, S.R{S.iMat}.T, S.FScible);
end

if nEchecs == 0
    afficherMessage(S.h, 'ok', {'Tous les tests sont réussis.', ...
        'Détails : voir la fenêtre de commande de Matlab (Command Window).'});
else
    afficherMessage(S.h, 'alerte', {sprintf('%d test(s) en échec.', nEchecs), ...
        'Détails : voir la fenêtre de commande de Matlab (Command Window).'});
end

end
