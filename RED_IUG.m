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
%     d) Elle calcule la durée de chaque rotation à partir du COUPLE de
%        l'actionneur : la durée est un résultat, pas une entrée. C'est la
%        plus courte qui respecte à la fois le couple disponible et le
%        facteur de sécurité cible.
%     Elle refuse les entrées invalides, signale les résultats hors du
%     domaine de validité et sauvegarde les résultats dans un fichier texte.
%
%   LES ENTRÉES (colonne de gauche)
%     - le matériau de la pièce ;
%     - le couple de l'actionneur, 2,00 N.m par défaut (catalogue Festo) ;
%     - le facteur de sécurité cible ;
%     - l'origine des durées des rotations :
%         « calculée à ce couple »  : la plus courte possible (par défaut) ;
%         « mesurée sur la vidéo »  : le montage réel, ralenti par ses
%                                     limiteurs de débit.
%     [Claude] Avant le 18 nov. 2026, la durée du transfert se tapait dans
%     une case et un bouton « Optimiser » calculait la durée minimale. On a
%     inversé la relation : le couple est la variable indépendante, la
%     durée en découle. Le calcul de la durée minimale est donc permanent.
%
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
%       D. Autres boutons                  (retablirCouple, sauvegarder, ...)
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
%     gauche  : panneau de commandes
%     centre  : animation, message d'état, valeurs clés et tableau comparatif
%     droite  : les cinq tracés en fonction du temps

P    = S.P;
fond = [0.94 0.94 0.94];                % couleur de fond (gris pâle)

% ---------------------------------------------------------------------------------
%  COLONNE DE GAUCHE : PANNEAU DE COMMANDES
% ---------------------------------------------------------------------------------
% Dans un panneau, les positions sont des fractions DU PANNEAU.
pan = uipanel('Parent', fig, 'Title', 'Commandes', 'FontWeight', 'bold', ...
              'BackgroundColor', fond, ...
              'Units', 'normalized', 'Position', [0.006 0.015 0.208 0.975]);

% --- Choix du matériau (menu déroulant) ---
etiquette(pan, [0.05 0.955 0.90 0.026], 'Matériau de la pièce', false);
h.popMateriau = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
    'Units', 'normalized', 'Position', [0.05 0.917 0.90 0.038], ...
    'String', {P.materiaux.nom}, 'Value', S.iMat, ...
    'Callback', @(~, ~) mettreAJour(fig));

% --- Couple de l'actionneur (case à remplir) : l'ENTRÉE principale ---
% La durée des rotations n'est plus tapée : elle découle de ce couple.
etiquette(pan, [0.05 0.874 0.63 0.028], 'Couple de l''actionneur (N.m)', false);
h.editCouple = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0.872 0.26 0.038], ...
    'String', sprintf('%.2f', P.actionneur.couple), 'BackgroundColor', [1 1 1], ...
    'Callback', @(~, ~) mettreAJour(fig));

% --- Facteur de sécurité cible (case à remplir) ---
etiquette(pan, [0.05 0.829 0.63 0.028], 'Facteur de sécurité cible', false);
h.editFS = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0.827 0.26 0.038], ...
    'String', sprintf('%.2f', S.FScible), 'BackgroundColor', [1 1 1], ...
    'Callback', @(~, ~) mettreAJour(fig));

% --- D'où viennent les durées des rotations (menu déroulant) ---
% 1. Calculée : la plus courte que permettent le couple et la ventouse.
% 2. Vidéo    : les durées mesurées sur le montage réel, qui est ralenti
%               par ses limiteurs de débit. Sert à comparer au montage.
etiquette(pan, [0.05 0.789 0.90 0.026], 'Durée des rotations', false);
h.popMode = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
    'Units', 'normalized', 'Position', [0.05 0.751 0.90 0.038], ...
    'String', {'Calculée à ce couple (vitesse maximale)', ...
               sprintf('Mesurée sur la vidéo (%.3f s et %.3f s)', ...
                       P.duree.transfert, P.duree.retour)}, ...
    'Value', S.modeDurees, ...
    'Callback', @(~, ~) mettreAJour(fig));

bouton(pan, [0.05 0.704 0.90 0.038], ...
       sprintf('Couple du catalogue Festo (%.2f N.m)', P.actionneur.coupleCatalogue), ...
       @(~, ~) retablirCouple(fig));

% --- Animation ---
etiquette(pan, [0.05 0.662 0.90 0.028], 'ANIMATION DU CYCLE', true);
bouton(pan, [0.050 0.618 0.29 0.040], 'Lancer',  @(~, ~) lancerAnimation(fig));
bouton(pan, [0.355 0.618 0.29 0.040], 'Pause',   @(~, ~) mettreEnPause(fig));
bouton(pan, [0.660 0.618 0.29 0.040], 'Arrêter', @(~, ~) arreterAnimation(fig));

etiquette(pan, [0.05 0.574 0.56 0.028], 'Vitesse de l''animation', false);
h.popVitesse = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
    'Units', 'normalized', 'Position', [0.62 0.572 0.33 0.038], ...
    'String', {'0,1 x', '0,25 x', '0,5 x', '1 x', '2 x'}, 'Value', 4, ...
    'Callback', @(~, ~) changerVitesse(fig));

% Glissière : permet de se déplacer à la main dans le cycle
etiquette(pan, [0.05 0.538 0.90 0.026], 'Position dans le cycle (glissière)', false);
h.glissiere = uicontrol('Parent', pan, 'Style', 'slider', ...
    'Units', 'normalized', 'Position', [0.05 0.508 0.90 0.028], ...
    'Min', 0, 'Max', 1, 'Value', 0, 'SliderStep', [0.005 0.05], ...
    'Callback', @(~, ~) deplacerGlissiere(fig));

% Case à cocher : agrandir les tracés sur l'étape du transfert
h.caseZoom = uicontrol('Parent', pan, 'Style', 'checkbox', ...
    'Units', 'normalized', 'Position', [0.05 0.466 0.90 0.034], ...
    'String', 'Tracés : zoom sur le transfert', 'Value', 0, ...
    'BackgroundColor', fond, ...
    'Callback', @(~, ~) changerZoom(fig));

% Valeurs à l'instant affiché (mises à jour pendant l'animation).
% [Claude] La zone est plus haute qu'avant le 18 nov. 2026 : les boutons
% « Optimiser » et « Appliquer » ont disparu (le calcul de la durée est
% maintenant permanent) et le couple instantané a été ajouté.
etiquette(pan, [0.05 0.428 0.90 0.028], 'VALEURS À L''INSTANT AFFICHÉ', true);
h.txtInstant = uicontrol('Parent', pan, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.05 0.196 0.90 0.228], ...
    'String', '', 'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

% --- Résultats et vérification ---
etiquette(pan, [0.05 0.148 0.90 0.028], 'RÉSULTATS ET VÉRIFICATION', true);
bouton(pan, [0.05 0.100 0.90 0.042], 'Sauvegarder les résultats (.txt)', ...
       @(~, ~) sauvegarder(fig));
bouton(pan, [0.05 0.054 0.90 0.042], 'Tableau des hypothèses', ...
       @(~, ~) montrerHypotheses(fig));
bouton(pan, [0.05 0.008 0.90 0.042], 'Tests et vérification', ...
       @(~, ~) lancerVerifications(fig));

% ---------------------------------------------------------------------------------
%  COLONNE DU CENTRE : ANIMATION, MESSAGE, VALEURS CLÉS
% ---------------------------------------------------------------------------------
% Zone de dessin de l'animation (remplie par creerScene.m)
h.axScene = axes('Parent', fig, 'Units', 'normalized', ...
                 'Position', [0.255 0.525 0.410 0.415]);

% Bandeau de message : vert, orange ou rouge selon la situation
h.txtMessage = uicontrol('Parent', fig, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.222 0.375 0.455 0.085], ...
    'String', '', 'FontWeight', 'bold', 'HorizontalAlignment', 'left');

% Panneau des valeurs clés
panV = uipanel('Parent', fig, 'Title', 'Valeurs clés et comparaison des matériaux', ...
               'FontWeight', 'bold', 'BackgroundColor', fond, ...
               'Units', 'normalized', 'Position', [0.222 0.015 0.455 0.350]);

% a) Valeurs du matériau choisi (texte sur plusieurs lignes)
h.txtValeurs = uicontrol('Parent', panV, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.012 0.02 0.345 0.96], ...
    'String', '', 'HorizontalAlignment', 'left', 'BackgroundColor', fond);

% b) Tableau comparatif des trois matériaux (une ligne par matériau).
% La largeur des colonnes est réglée plus bas par ajusterTableau.
h.tableau = uitable('Parent', panV, ...
    'Units', 'normalized', 'Position', [0.365 0.52 0.627 0.46], ...
    'ColumnName', {'Matériau', 'Masse (g)', 'Poids (N)', 'Effort max (N)', 'FS min', 'T min (s)'}, ...
    'RowName', [], ...
    'FontSize', 9, ...
    'Data', cell(numel(P.materiaux), 6));
ajusterTableau(h.tableau, [0.21 0.16 0.15 0.22 0.12 0.14]);

% c) Résultat de l'optimisation (texte sur plusieurs lignes)
h.txtOptim = uicontrol('Parent', panV, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.365 0.02 0.627 0.48], ...
    'String', '', 'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

% ---------------------------------------------------------------------------------
%  COLONNE DE DROITE : LES CINQ TRACÉS
% ---------------------------------------------------------------------------------
titres = {'Position angulaire du bras (°)', ...
          'Vitesse angulaire du bras (rad/s)', ...
          'Accélération angulaire du bras (rad/s^2)', ...
          'Effort de la ventouse sur la pièce (N)', ...
          'Facteur de sécurité de la prise (-)'};

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
       {'Maintien requis', 'Effort total', 'Poids'}, ...
       'Location', 'north', 'Orientation', 'horizontal', 'FontSize', 7);

% Tracé 5 : petite étiquette « FS cible » posée sur la ligne pointillée
% (sa position est fixée dans afficherTraces).
h.texteFScible = text(0, 0, 'FS cible', 'Parent', h.ax(5), 'Color', rouge, ...
                      'FontSize', 8, 'VerticalAlignment', 'bottom');

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
%   l'utilisateur change le matériau, le couple, le facteur de sécurité ou
%   l'origine des durées.
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
S.modeDurees = get(S.h.popMode, 'Value');       % 1 = calculée, 2 = vidéo
couple       = lireNombre(S.h.editCouple);
FScible      = lireNombre(S.h.editFS);

% --- 2. Valider les entrées AVANT de calculer --------------------------------------
[valide, message] = validerEntrees(S.P, couple, FScible);

if ~valide
    % Entrée invalide : on n'affiche AUCUN résultat (exigence de la consigne).
    S.valide = false;
    guidata(fig, S);
    effacerResultats(S);
    afficherMessage(S.h, 'erreur', {['ENTRÉE INVALIDE - ' message], ...
                    'Aucun calcul n''a été fait. Corriger la valeur.'});
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
[S.TretourMin, S.infoRetour] = dureeCouple(S.P, 0, S.P.thetaDepot, S.P.thetaPrise);
if S.P.actionneur.verifier && ~isnan(S.TretourMin)
    S.TretourMin = max(S.TretourMin, S.P.actionneur.dureeMin);
end

% --- 4. Durées réellement utilisées pour le cycle -----------------------------------------
% On arrondit VERS LE HAUT au millième de seconde (fonction ceil) pour
% rester du côté sûr : une durée un peu plus longue donne un FS un peu
% plus grand que la cible, jamais plus petit, et un couple requis un peu
% plus petit que celui de l'actionneur, jamais plus grand.
if S.modeDurees == 1
    Ttransfert = ceil(S.Tmin * 1000) / 1000;          % un par matériau
    Tretour    = ceil(S.TretourMin * 1000) / 1000;
else
    Ttransfert = S.P.duree.transfert * ones(1, nMat); % mesures de la vidéo
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
    afficherMessage(S.h, 'alerte', {sprintf(['COUPLE INSUFFISANT (%.2f N.m) ' ...
        'pour le matériau %s.'], couple, S.P.materiaux(S.iMat).nom), explication});
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
afficherValeurs(S);
afficherTableau(S);
afficherDurees(S);
afficherInstant(S);

[niveau, lignes] = verifierDomaine(S.P, S.R{S.iMat}, S.FScible);
afficherMessage(S.h, niveau, lignes);

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


function afficherValeurs(S)
% AFFICHERVALEURS  Écrit les valeurs clés du matériau choisi (panneau du centre).

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

set(S.h.txtValeurs, 'String', lignes);

end


function afficherTableau(S)
% AFFICHERTABLEAU  Remplit le tableau comparatif des trois matériaux.
%   Une ligne par matériau. En mode « durée calculée », chaque matériau
%   tourne à SA propre durée minimale : le tableau compare donc les trois
%   matériaux chacun à sa vitesse maximale. La colonne « T min » donne
%   cette durée minimale du transfert, au couple choisi.
%
%   Si le couple ne suffit pas à soulever un matériau, sa ligne indique
%   « impossible » au lieu des résultats.

nMat    = numel(S.P.materiaux);
donnees = cell(nMat, 6);                % tableau de cellules (texte)

for i = 1:nMat
    m = massePiece(S.P, i);             % la masse ne dépend pas du couple
    donnees{i, 1} = S.P.materiaux(i).nom;
    donnees{i, 2} = sprintf('%.1f', m * 1000);
    donnees{i, 3} = sprintf('%.3f', m * S.P.g);

    if isempty(S.R{i})
        % Couple insuffisant pour ce matériau : aucun cycle possible
        donnees{i, 4} = '-';
        donnees{i, 5} = '-';
    else
        donnees{i, 4} = sprintf('%.3f', S.R{i}.FnormeMax);
        donnees{i, 5} = sprintf('%.2f', S.R{i}.FSmin);
    end

    % En mode vidéo, le cycle est calculé avec les durées mesurées même si
    % le couple choisi ne permettrait pas de les atteindre : la durée
    % minimale peut donc être impossible alors que le cycle existe.
    if isnan(S.Tmin(i))
        donnees{i, 6} = 'impossible';
    else
        donnees{i, 6} = sprintf('%.3f', S.Tmin(i));
    end
end

set(S.h.tableau, 'Data', donnees);

end


function afficherDurees(S)
% AFFICHERDUREES  Explique d'où viennent les durées des deux rotations
%   du matériau choisi, et ce qu'elles donnent sur le cycle complet.
%
%   [Claude] Remplace depuis le 18 nov. 2026 l'affichage du bouton
%   « Optimiser » : le calcul de la durée minimale est maintenant fait à
%   chaque mise à jour, puisque la durée découle du couple.

i     = S.iMat;
res   = S.R{i};
info  = S.infoOpt{i};
P     = S.P;
cVid  = P.dureeCycle;                   % [s] cycle mesuré sur la vidéo

if S.modeDurees == 1
    % ---------- Durées CALCULÉES à partir du couple ----------
    lignes = {sprintf('DURÉES DES ROTATIONS - %s, couple %.2f N.m', ...
                      res.nomMateriau, P.actionneur.couple)};

    % Étape 4 : le transfert, et la contrainte qui l'a fixé
    lignes{end+1} = sprintf('Transfert (étape 4) : %.3f s', res.T);
    lignes{end+1} = sprintf('   Limite active : %s', upper(info.limite));
    if ~isnan(info.Tcouple)
        lignes{end+1} = sprintf('   ventouse %.3f s | couple %.3f s | fréq. %.3f s', ...
                                info.Tventouse, info.Tcouple, info.Tfrequence);
    end

    % Étape 2 : le retour à vide. Sans rondelle, aucun critère de succion :
    % seul l'actionneur limite cette rotation.
    lignes{end+1} = sprintf('Retour à vide (étape 2) : %.3f s', res.Tretour);
    lignes{end+1} = '   Limite active : COUPLE (aucune rondelle portée)';

    % Le cycle complet, comparé au montage actuel
    lignes{end+1} = sprintf('Cycle : %.2f s, soit %.2f pièces/min', ...
                            res.dureeCycle, res.cadence);
    lignes{end+1} = sprintf('   (vidéo : %.2f s, soit %.2f pièces/min)', cVid, 60 / cVid);

else
    % ---------- Durées MESURÉES sur la vidéo ----------
    lignes = {sprintf('DURÉES DES ROTATIONS - %s, mesurées sur la vidéo', res.nomMateriau)};

    lignes{end+1} = sprintf('Transfert (étape 4) : %.3f s', res.T);
    if isnan(S.Tmin(i))
        lignes{end+1} = sprintf('   minimum à %.2f N.m : impossible (couple insuffisant)', ...
                                P.actionneur.couple);
    else
        lignes{end+1} = sprintf('   minimum à %.2f N.m : %.3f s', P.actionneur.couple, S.Tmin(i));
    end

    lignes{end+1} = sprintf('Retour à vide (étape 2) : %.3f s', res.Tretour);
    if isnan(S.TretourMin)
        lignes{end+1} = sprintf('   minimum à %.2f N.m : impossible (couple insuffisant)', ...
                                P.actionneur.couple);
    else
        lignes{end+1} = sprintf('   minimum à %.2f N.m : %.3f s', P.actionneur.couple, S.TretourMin);
    end

    lignes{end+1} = sprintf('Cycle : %.2f s, soit %.2f pièces/min', ...
                            res.dureeCycle, res.cadence);
    lignes{end+1} = 'Le montage réel est ralenti par ses limiteurs de débit.';
end

set(S.h.txtOptim, 'String', lignes);

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
lignes = { ...
    sprintf('t = %.2f s  (étape %d de 4)', t, res.etape(k)), ...
    sprintf('Angle : %.1f°', res.theta(k) * 180/pi), ...
    sprintf('Vitesse : %.2f rad/s', res.omega(k)), ...
    sprintf('Accélération : %.1f rad/s²', res.alpha(k)), ...
    sprintf('Couple au pivot : %.2f N.m (sur %.2f)', abs(res.couple(k)), S.P.actionneur.couple)};

if res.tenue(k)
    lignes{end+1} = sprintf('Maintien requis : %.3f N', res.Frequis(k));
    lignes{end+1} = sprintf('FS : %.2f', res.FS(k));
else
    lignes{end+1} = 'Pièce non tenue par la ventouse';
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
set(h.txtValeurs, 'String', 'Aucun résultat : entrée invalide.');
set(h.txtInstant, 'String', '');
set(h.txtOptim,   'String', '');
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

function retablirCouple(fig)
% RETABLIRCOUPLE  Remet dans la case le couple du catalogue Festo.
%
%   [Claude] Remplace depuis le 18 nov. 2026 les boutons « Rétablir la
%   durée de la vidéo », « Optimiser » et « Appliquer la durée minimale ».
%   La durée n'étant plus une entrée, il n'y a plus de durée à rétablir ni
%   à appliquer : c'est le couple qu'on remet à sa valeur de référence.
S = guidata(fig);
set(S.h.editCouple, 'String', sprintf('%.2f', S.P.actionneur.coupleCatalogue));
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
    [niveau, lignes] = verifierDomaine(S.P, S.R{S.iMat}, S.FScible);
    lignes{end+1} = ['Résultats sauvegardés dans : ' chemin];
    afficherMessage(S.h, niveau, lignes);
else
    afficherMessage(S.h, 'erreur', {['Impossible d''écrire le fichier : ' chemin]});
end

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
