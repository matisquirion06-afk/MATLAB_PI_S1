function P = parametres()
% PARAMETRES  Toutes les données d'entrée du programme RED, réunies au même endroit.
%
%   P = parametres() retourne une STRUCTURE nommée P.
%   Une structure est une « boîte » qui contient plusieurs valeurs nommées.
%   Exemple : P.R est la longueur du bras, P.g est la gravité.
%   On peut aussi ranger une structure dans une autre : P.piece.D est le
%   diamètre de la pièce.
%
%   RÈGLE D'OR DU PROGRAMME
%   Aucune valeur numérique n'est écrite ailleurs que dans ce fichier.
%   Pour changer une dimension, un angle, une durée ou un matériau, on
%   modifie UNIQUEMENT ce fichier, puis on relance RED_IUG.
%
%   UNITÉS
%   Tout le programme calcule en unités SI de base :
%       longueur [m], masse [kg], temps [s], force [N], pression [Pa],
%       angle [rad].
%   Les conversions (mm, degrés, kPa, g) se font seulement à l'affichage.
%
%   LÉGENDE DES SOURCES (même convention que dans les documents du projet)
%       [Fourni]  valeur tirée d'un document de l'équipe (CAD, notes, tableur)
%       [Web]     valeur trouvée en ligne (fiche ou guide de fabricant)
%       [Claude]  hypothèse ou estimation proposée par l'assistant IA
%   STATUT
%       CONFIRMÉ    valeur mesurée ou vérifiée par l'équipe
%       PROVISOIRE  valeur de départ, À CONFIRMER OU À REMPLACER
%
%   Le même contenu, sous forme de tableau, est produit par la fonction
%   tableauHypotheses.m (exigence de la consigne : hypothèses, valeurs
%   estimées et unités réunies dans un tableau et justifiées).
%
%   Version préliminaire du 11 novembre 2026 - Équipe 14.

%% ------------------------------------------------------------------------
%  1. CONSTANTE PHYSIQUE
% -------------------------------------------------------------------------
P.g = 9.81;     % [m/s^2] accélération gravitationnelle (valeur usuelle)

%% ------------------------------------------------------------------------
%  2. GÉOMÉTRIE DU BRAS (vue de côté, voir le schéma dans anglesExtremes.m)
% -------------------------------------------------------------------------

% Distance entre le pivot du bras et l'axe de la poulie qui porte la ventouse.
% [Fourni] CAD MPS-12-005, esquisse « Positions trous », cote D3 ; mesurée
% dans SolidWorks par Matis le 8 nov. 2026 (« Entraxe » = 177 mm).
% Statut : CONFIRMÉ.
P.L = 0.177;                % [m]






% ------------------------À VÉRIFIER---------------------------------------
% Hauteur du pivot au-dessus de la table.
% [Fourni] Mesurée dans SolidWorks par Matis le 8 nov. 2026 (arbre de
% l'actionneur -> dessous du pied du support MPS-12-900).
% Statut : CONFIRMÉ (CAD).
P.hPivot = 0.056;           % [m]

% Distance VERTICALE entre l'axe de la poulie et la lèvre de la ventouse
% (la lèvre est le bord de la ventouse qui touche la pièce).
% [Fourni] Mesurée dans SolidWorks (MPS-12-200) par Matis le 8 nov. 2026.
% Statut : CONFIRMÉ (CAD). Limite connue : la vidéo montre une ventouse à
% soufflet plus longue que celle du CAD.
P.dLevre = 0.0265;          % [m]

% Hauteur de la surface où repose la rondelle, mesurée à partir de la table
% (table -> dessous de la rondelle), à la prise et au dépôt.
% [Fourni] « Infos visite Cégep.docx », section « Dimensions et
% spécifications du bras rotatif » (hauteur du départ et de l'arrivée) ;
% précision de Manuel transmise le 8 nov. 2026.
% Statut : PROVISOIRE (à valider avec la vidéo).
P.hAppuiPrise = 0.03335;    % [m]
P.hAppuiDepot = 0.02625;    % [m]
% -------------------------------------------------------------------------





% Les angles extremes du bras sont calcules plus bas (section 3b) : ils
% dependent de la hauteur de la rondelle, definie a la section 3.



%% ------------------------------------------------------------------------
%  3. PIÈCE TRANSPORTÉE (rondelle)
% -------------------------------------------------------------------------
% [Fourni] « Rapport bras rotatif.xlsx », feuille DONNÉES (valeurs de base).
% Statut : PROVISOIRE (valeurs nominales à fixer par l'équipe ; le diamètre
% du trou de 1 mm semble provisoire).
% La consigne impose un VOLUME CONSTANT : les trois matériaux utilisent
% donc exactement ces mêmes dimensions.
P.piece.D        = 0.038;   % [m] diamètre extérieur de la rondelle
P.piece.H        = 0.022;   % [m] hauteur (épaisseur) de la rondelle
P.piece.profTrou = 0.0105;  % [m] profondeur totale du trou sur le dessus
P.piece.diamTrou = 0.001;   % [m] diamètre de la partie droite du trou
P.piece.diamCone = 0.0126;  % [m] diamètre de la zone conique
P.piece.profCone = 0.0029;  % [m] profondeur de la zone conique

%% ------------------------------------------------------------------------
%  3b. ANGLES EXTREMES DU BRAS
% -------------------------------------------------------------------------
% La LEVRE de la ventouse se pose sur le DESSUS de la rondelle, et l'axe de
% la poulie est d_levre plus haut que la levre :
%     y_axe = h_appui + H + d_levre - h_pivot
% Le calcul et le controle de domaine sont dans hauteurAxePoulie.m, pour que
% le test L4 de testsRED.m verifie le vrai code et non une copie.
P.hauteurPrise = hauteurAxePoulie(P, P.hAppuiPrise);   % [m]
P.hauteurDepot = hauteurAxePoulie(P, P.hAppuiDepot);   % [m]

% Le depot est a DROITE (angle petit, positif), la prise est a GAUCHE.
P.thetaDepot = asin(P.hauteurDepot / P.L);          % [rad]
P.thetaPrise = pi - asin(P.hauteurPrise / P.L);     % [rad]

%% ------------------------------------------------------------------------
%  4. MATÉRIAUX DE LA PIÈCE
% -------------------------------------------------------------------------
% P.materiaux est un « tableau de structures » : P.materiaux(1) est le
% premier matériau, P.materiaux(2) le deuxième, etc.
%
% rho : masse volumique.
%   [Fourni] « Rapport bras rotatif.xlsx », feuille DONNÉES (1420, 2700 et
%   7850 kg/m^3). Statut : PROVISOIRE (aucune source n'est indiquée dans le
%   tableur : une fiche technique reste à citer pour chaque matériau).
%
% mu : coefficient de frottement entre la ventouse et la pièce.
%   [Web] Schmalz, « Theoretical Holding Force of a Suction Cup » : valeur
%   de référence de 0,5 pour bois, métal, verre, pierre. Schmalz précise
%   qu'il faut un essai pour obtenir la vraie valeur.
%   Statut : PROVISOIRE (même valeur pour les trois matériaux pour l'instant).
%
% couleur : couleur [rouge vert bleu] (entre 0 et 1) pour l'animation.
P.materiaux(1).nom     = 'Delrin';
P.materiaux(1).rho     = 1420;              % [kg/m^3]
P.materiaux(1).mu      = 0.5;               % [-]
P.materiaux(1).couleur = [0.20 0.20 0.22];

P.materiaux(2).nom     = 'Aluminium';
P.materiaux(2).rho     = 2700;              % [kg/m^3]
P.materiaux(2).mu      = 0.5;               % [-]
P.materiaux(2).couleur = [0.78 0.80 0.83];

P.materiaux(3).nom     = 'Acier';
P.materiaux(3).rho     = 7850;              % [kg/m^3]
P.materiaux(3).mu      = 0.5;               % [-]
P.materiaux(3).couleur = [0.42 0.48 0.56];

P.materiauDefaut = 3;       % matériau choisi à l'ouverture (3 = Acier)

%% ------------------------------------------------------------------------
%  5. VENTOUSE, VIDE ET FACTEUR DE SÉCURITÉ
% -------------------------------------------------------------------------

% Diamètre et hauteur de la ventouse.
% [Fourni] CAD SMC-ZP20UN (Esquisse1, cote D2 = 20 mm ; hauteur 14 mm).
% Statut : CONFIRMÉ (CAD). Décision de Matis du 9 nov. 2026 : on se fie au
% CAD. Limite connue : le dessin du Cégep indique une ventouse de 30 mm, les
% notes de visite environ 38,1 mm et la vidéo une ventouse à soufflet.
P.ventouse.diametre = 0.020;    % [m]
P.ventouse.hauteur  = 0.014;    % [m] (sert seulement au dessin)

% Niveau de vide : différence entre la pression atmosphérique et la
% pression dans la ventouse.
% [Web] 60 kPa est la valeur de travail de l'exemple de sélection de SMC
% (« Working vacuum pressure -60 kPa », guide de sélection des ventouses
% ZP/ZPT) et la base du calcul de Schmalz (-0,6 bar). Elle est inférieure
% au vide maximal d'un éjecteur SMC ZU07S (-85 kPa à 0,45 MPa).
% Statut : PROVISOIRE. À remplacer par la valeur de la fiche du générateur
% de vide retenu. Les notes de visite donnent « 10 à 12 psi » (69 à 83 kPa),
% mais leur auteur n'est pas certain de ce que cette valeur représente.
P.vide = 60e3;                  % [Pa]  (60e3 veut dire 60 x 10^3 = 60 000)

% Facteur de sécurité visé pour la prise (valeur affichée à l'ouverture).
% [Web] Schmalz : au moins 1,5 pour des pièces lisses et étanches ; 2,0 ou
% plus pour des pièces critiques, poreuses, rugueuses ou huilées.
% Statut : PROVISOIRE. La consigne demande à l'équipe de fixer ET de
% justifier cette valeur.
P.FScible = 2.0;                % [-]

%% ------------------------------------------------------------------------
%  6. DURÉES DES ÉTAPES DU CYCLE (tirées de la vidéo)
% -------------------------------------------------------------------------
% La vidéo est filmée à 30 images par seconde. On compte les images de
% chaque étape, puis : durée [s] = nombre d'images / 30.
% [Claude] Relevé préliminaire dans la vidéo officielle
% « mini_usine_en_fonction.mp4 » (précision d'environ +/- 2 images) :
%   attente à la prise : images 690 -> 795            = 105 images
%   transfert          : 795 -> 821 et 1185 -> 1213   = 26 et 28 (moyenne 27)
%   attente au dépôt   : images 821 -> 905            =  84 images
%   retour à vide      : 666 -> 690 et 905 -> 930     = 24 et 25 (moyenne 24,5)
% Statut : PROVISOIRE (à refaire et à valider par l'équipe).
P.imagesParSeconde = 30;                    % [images/s]

P.images.attentePrise = 105;                % [images]
P.images.transfert    = 27;                 % [images]
P.images.attenteDepot = 84;                 % [images]
P.images.retour       = 24.5;               % [images]

P.duree.attentePrise = P.images.attentePrise / P.imagesParSeconde;  % [s]
P.duree.transfert    = P.images.transfert    / P.imagesParSeconde;  % [s]
P.duree.attenteDepot = P.images.attenteDepot / P.imagesParSeconde;  % [s]
P.duree.retour       = P.images.retour       / P.imagesParSeconde;  % [s]

%% ------------------------------------------------------------------------
%  7. ACTIONNEUR ET MASSES EN ROTATION (vérification facultative)
% -------------------------------------------------------------------------
% La consigne permet d'ajouter « le moment au pivot ». On s'en sert ici
% comme LIMITE DU DOMAINE DE VALIDITÉ : si le couple demandé dépasse celui
% de l'actionneur, l'interface l'indique (voir momentPivot.m).
P.actionneur.verifier = true;   % true = faire la vérification ; false = non

% [Fourni] Catalogue Festo « Semi-rotary drive, metric DSR » (2025/03),
% p. 4, taille 16 : couple théorique de 2 N.m à 6 bar ; fréquence maximale
% d'oscillation de 3 Hz à 6 bar. Statut : CONFIRMÉ (catalogue).
P.actionneur.couple       = 2.0;    % [N.m]
P.actionneur.frequenceMax = 3;      % [Hz]

% Durée minimale d'une rotation que l'actionneur peut réaliser.
% [Claude] Interprétation : 3 Hz = 3 allers-retours par seconde, donc un
% aller simple dure au moins 1/(2 x 3) = 0,167 s.
% Statut : PROVISOIRE (interprétation à confirmer).
P.actionneur.dureeMin = 1 / (2 * P.actionneur.frequenceMax);   % [s]

% Bras + pont (pièces MPS-12-005 et MPS-12-002).
% [Fourni] Masse : propriété « Mass » de l'assemblage MPS-12-000 dans le
% CAD (0,686 lb = 0,311 kg). Longueur : CAD MPS-12-005 (200 mm).
% [Claude] Position du centre de masse : on suppose une barre uniforme de
% 200 mm dont le pivot est à 11,5 mm d'un bout, donc un centre de masse à
% 100 - 11,5 = 88,5 mm du pivot.
% Statut : PROVISOIRE (à remplacer par les « Propriétés de masse » de
% SolidWorks calculées par rapport à l'axe du pivot).
P.bras.masse    = 0.311;    % [kg]
P.bras.longueur = 0.200;    % [m]
P.bras.distCM   = 0.0885;   % [m] distance pivot -> centre de masse

% Ensemble ventouse (support en laiton, poulie, adaptateur, ventouse).
% [Fourni] Propriété « Mass » de l'assemblage MPS-12-200 dans le CAD
% (0,168 lb = 0,076 kg). Statut : CONFIRMÉ (CAD).
P.masseVentouse = 0.076;    % [kg]

%% ------------------------------------------------------------------------
%  8. RÉGLAGES NUMÉRIQUES (sans effet sur la physique)
% -------------------------------------------------------------------------
P.nPts = 400;               % nombre de points de calcul par étape du cycle

% Recherche de la durée minimale (voir dureeMinimale.m) : bornes de la
% recherche et précision demandée sur le résultat.
P.recherche.Tbas       = 0.01;      % [s] plus petite durée essayée
P.recherche.Thaut      = 20;        % [s] plus grande durée essayée
P.recherche.tolerance  = 1e-5;      % [s] précision sur T_min (0,01 ms)

% Limites acceptées pour les valeurs tapées dans l'interface
% (voir validerEntrees.m). [Claude] Bornes de saisie pour éviter les
% fautes de frappe ; elles ne sont pas des limites physiques.
P.saisie.Tmax  = 20;        % [s] durée de transfert maximale acceptée
P.saisie.FSmax = 100;       % [-] facteur de sécurité maximal accepté

end
