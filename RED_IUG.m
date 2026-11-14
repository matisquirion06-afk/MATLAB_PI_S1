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
%     d) Elle calcule la durée de transfert minimale qui respecte le
%        facteur de sécurité cible (bouton « Optimiser »).
%     Elle refuse les entrées invalides, signale les résultats hors du
%     domaine de validité et sauvegarde les résultats dans un fichier texte.
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
%       D. Autres boutons                  (optimiser, sauvegarder, ...)
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
S.T          = P.duree.transfert;       % [s] durée du transfert
S.FScible    = P.FScible;               % [-] facteur de sécurité cible
S.valide     = false;                   % vrai si les entrées sont valides
S.R          = cell(1, nMat);           % résultats : S.R{i} pour le matériau i
S.scene      = [];                      % poignées de l'animation
S.Tmin       = NaN(1, nMat);            % [s] durées minimales (NaN = pas calculées)
S.infoOpt    = cell(1, nMat);           % informations sur l'optimisation
S.optFScible = NaN;                     % FS cible utilisé pour l'optimisation
S.optLoi     = NaN;                     % loi utilisée pour l'optimisation
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

% --- Choix de la loi de mouvement (menu déroulant) ---

%etiquette(pan, [0.05 0.878 0.90 0.026], 'Loi de mouvement du bras', false);
%h.popLoi = uicontrol('Parent', pan, 'Style', 'popupmenu', ...
%    'Units', 'normalized', 'Position', [0.05 0.840 0.90 0.038], ...
%    'String', P.loisAffichage, 'Value', S.iLoi, ...
%    'Callback', @(~, ~) mettreAJour(fig));

% --- Durée du transfert (case à remplir) ---
etiquette(pan, [0.05 0.797 0.63 0.028], 'Durée du transfert T (s)', false);
h.editT = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0.795 0.26 0.038], ...
    'String', sprintf('%.3f', S.T), 'BackgroundColor', [1 1 1], ...
    'Callback', @(~, ~) mettreAJour(fig));

% --- Facteur de sécurité cible (case à remplir) ---
etiquette(pan, [0.05 0.752 0.63 0.028], 'Facteur de sécurité cible', false);
h.editFS = uicontrol('Parent', pan, 'Style', 'edit', ...
    'Units', 'normalized', 'Position', [0.69 0.750 0.26 0.038], ...
    'String', sprintf('%.2f', S.FScible), 'BackgroundColor', [1 1 1], ...
    'Callback', @(~, ~) mettreAJour(fig));

bouton(pan, [0.05 0.704 0.90 0.038], 'Rétablir la durée de la vidéo', ...
       @(~, ~) retablirDuree(fig));

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

% Valeurs à l'instant affiché (mises à jour pendant l'animation)
h.txtInstant = uicontrol('Parent', pan, 'Style', 'text', ...
    'Units', 'normalized', 'Position', [0.05 0.318 0.90 0.142], ...
    'String', '', 'HorizontalAlignment', 'left', 'BackgroundColor', [1 1 1]);

% --- Optimisation ---
etiquette(pan, [0.05 0.280 0.90 0.028], 'OPTIMISATION', true);
bouton(pan, [0.05 0.234 0.90 0.042], 'Optimiser : durée minimale', ...
       @(~, ~) optimiser(fig));
bouton(pan, [0.05 0.188 0.90 0.042], 'Appliquer la durée minimale', ...
       @(~, ~) appliquerDureeMinimale(fig));

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
%   l'utilisateur change le matériau, la loi, la durée ou le facteur de sécurité.

S = guidata(fig);
S.enMarche = false;                     % toute animation en cours est arrêtée

% --- 1. Lire les choix de l'utilisateur ------------------------------------------
S.iMat  = get(S.h.popMateriau, 'Value');    % numéro de la ligne choisie
T       = lireNombre(S.h.editT);
FScible = lireNombre(S.h.editFS);

% --- 2. Valider les entrées AVANT de calculer --------------------------------------
[valide, message] = validerEntrees(S.P, T, FScible);

if ~valide
    % Entrée invalide : on n'affiche AUCUN résultat (exigence de la consigne).
    S.valide = false;
    guidata(fig, S);
    effacerResultats(S);
    afficherMessage(S.h, 'erreur', {['ENTRÉE INVALIDE - ' message], ...
                    'Aucun calcul n''a été fait. Corriger la valeur.'});
    return;
end

S.valide  = true;
S.T       = T;
S.FScible = FScible;

% --- 3. Calculer le cycle pour les trois matériaux -----------------------------------
for i = 1:numel(S.P.materiaux)
    S.R{i} = calculerCycle(S.P, i, S.T);
end

% --- 4. L'optimisation précédente est-elle encore valable ? ---------------------------
% La durée minimale dépend du facteur de sécurité cible. Si il a changé, on
% efface l'ancien résultat pour ne pas afficher une valeur périmée.
if ~(S.FScible == S.optFScible)
    S.Tmin(:)    = NaN;
    S.infoOpt    = cell(1, numel(S.P.materiaux));
    S.optFScible = NaN;
end

% --- 5. Redessiner l'animation au début du cycle --------------------------------------
S.tCourant = 0;
S.scene    = creerScene(S.h.axScene, S.P, S.R{S.iMat});

% La glissière couvre maintenant toute la durée du nouveau cycle.
% (On remet d'abord sa valeur à 0 pour qu'elle reste entre Min et Max.)
set(S.h.glissiere, 'Value', 0);
set(S.h.glissiere, 'Max', S.R{S.iMat}.dureeCycle);

% --- 6. Enregistrer, puis rafraîchir tout l'affichage ----------------------------------
guidata(fig, S);

afficherTraces(S);
afficherValeurs(S);
afficherTableau(S);
afficherOptimisation(S);
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
%   Une ligne par matériau. La colonne « T min » reste vide tant que
%   l'optimisation n'a pas été lancée.

nMat    = numel(S.P.materiaux);
donnees = cell(nMat, 6);                % tableau de cellules (texte)

for i = 1:nMat
    res = S.R{i};
    donnees{i, 1} = res.nomMateriau;
    donnees{i, 2} = sprintf('%.1f', res.masse * 1000);
    donnees{i, 3} = sprintf('%.3f', res.poids);
    donnees{i, 4} = sprintf('%.3f', res.FnormeMax);
    donnees{i, 5} = sprintf('%.2f', res.FSmin);
    if isnan(S.Tmin(i))
        donnees{i, 6} = '-';            % optimisation pas encore lancée
    else
        donnees{i, 6} = sprintf('%.3f', S.Tmin(i));
    end
end

set(S.h.tableau, 'Data', donnees);

end


function afficherOptimisation(S)
% AFFICHEROPTIMISATION  Écrit le résultat de l'optimisation pour le matériau choisi.

i = S.iMat;

% Optimisation pas encore lancée (ou effacée parce qu'une entrée a changé)
if isempty(S.infoOpt{i})
    set(S.h.txtOptim, 'String', { ...
        'OPTIMISATION', ...
        'Cliquer sur « Optimiser : durée minimale » pour', ...
        'calculer la plus petite durée de transfert qui', ...
        'respecte le facteur de sécurité cible.'});
    return;
end

info = S.infoOpt{i};
Tmin = S.Tmin(i);
res  = S.R{i};

lignes = {sprintf('OPTIMISATION - %s, FS cible = %.2f', res.nomMateriau, S.optFScible)};

if strcmp(info.statut, 'impossible')
    lignes{end+1} = info.message;
else
    % Effet sur le cycle : seule la durée du transfert change.
    cycleMin = res.dureeCycle - res.T + Tmin;
    lignes{end+1} = sprintf('Durée minimale du transfert : %.3f s', Tmin);
    lignes{end+1} = sprintf('   (durée actuelle : %.3f s)', res.T);
    lignes{end+1} = sprintf('Cycle : %.2f s -> %.2f s', res.dureeCycle, cycleMin);
    lignes{end+1} = sprintf('Cadence : %.2f -> %.2f pièces/min', res.cadence, 60 / cycleMin);

    if strcmp(info.statut, 'non_limitant')
        lignes{end+1} = 'La ventouse ne limite pas la durée.';
    end

    % Le résultat est-il réaliste pour l'actionneur ?
    if S.P.actionneur.verifier
        resMin = calculerCycle(S.P, i, Tmin);
        if Tmin < S.P.actionneur.dureeMin
            lignes{end+1} = sprintf('ATTENTION : sous la limite de l''actionneur (%.3f s).', ...
                                    S.P.actionneur.dureeMin);
        end
        if resMin.coupleMax > S.P.actionneur.couple
            lignes{end+1} = sprintf('ATTENTION : couple requis %.2f N.m > %.2f N.m (actionneur).', ...
                resMin.coupleMax, S.P.actionneur.couple);
        end
    end
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
    sprintf('Accélération : %.1f rad/s²', res.alpha(k))};

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

function retablirDuree(fig)
% RETABLIRDUREE  Remet dans la case la durée du transfert mesurée dans la vidéo.
S = guidata(fig);
set(S.h.editT, 'String', sprintf('%.3f', S.P.duree.transfert));
mettreAJour(fig);
end


function optimiser(fig)
% OPTIMISER  Calcule la durée minimale du transfert pour les trois matériaux
%            (bouton « Optimiser : durée minimale »).

S = guidata(fig);
if ~S.valide
    return;                 % entrées invalides : rien à optimiser
end
S.enMarche = false;

for i = 1:numel(S.P.materiaux)
    [S.Tmin(i), S.infoOpt{i}] = dureeMinimale(S.P, i, S.FScible);
end

% On note avec quelles entrées l'optimisation a été faite (voir mettreAJour).
S.optFScible = S.FScible;
guidata(fig, S);

afficherTableau(S);
afficherOptimisation(S);

end


function appliquerDureeMinimale(fig)
% APPLIQUERDUREEMINIMALE  Utilise la durée minimale trouvée comme durée du transfert.
%   L'animation et les tracés montrent alors le cycle optimisé.

S    = guidata(fig);
Tmin = S.Tmin(S.iMat);

if isnan(Tmin)
    afficherMessage(S.h, 'avertissement', ...
        {'Aucune durée minimale à appliquer.', ...
         'Cliquer d''abord sur « Optimiser : durée minimale ».'});
    return;
end

% On arrondit VERS LE HAUT au millième de seconde (fonction ceil), pour
% rester du côté sûr : une durée un peu plus longue donne un FS un peu
% plus grand que la cible, jamais plus petit.
Tapplique = ceil(Tmin * 1000) / 1000;

set(S.h.editT, 'String', sprintf('%.3f', Tapplique));
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
reussi = sauvegarderResultats(chemin, S.P, S.R, S.iMat, S.FScible, S.Tmin, S.infoOpt);

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
    verifIndependante(S.P, S.iMat, S.T, S.FScible);
end

if nEchecs == 0
    afficherMessage(S.h, 'ok', {'Tous les tests sont réussis.', ...
        'Détails : voir la fenêtre de commande de Matlab (Command Window).'});
else
    afficherMessage(S.h, 'alerte', {sprintf('%d test(s) en échec.', nEchecs), ...
        'Détails : voir la fenêtre de commande de Matlab (Command Window).'});
end

end
