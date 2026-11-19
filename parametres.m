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
% rho : masse volumique. Une fiche technique par matériau (18 nov. 2026) :
%   Delrin    : [Web] DuPont, fiche technique Delrin 900P, « Density
%               ISO 1183 : 1420 kg/m3 (1.42 g/cm3) ». Delrin est une marque
%               de DuPont : c'est la source la plus directe.
%   Aluminium : [Web] ASM Material Data Sheet, aluminium 6061-T6, « Density
%               2.7 g/cc ». L'alliage exact des rondelles du Cégep n'est pas
%               identifié : 2700 kg/m^3 est la valeur typique du 6061 (le
%               6063 donne aussi 2,70 g/cc).
%   Acier     : [Web] MatWeb, AISI 1020 Steel, cold rolled, « Density
%               7.87 g/cc ». Nuance demandée par le client : « Acier standard
%               (1020) » ([Fourni] Infos visite Cégep.docx, 24 juin).
%               Décision de Matis du 18 nov. 2026 : 7870 au lieu des 7850 du
%               tableur. À CHANGER AUSSI dans le rapport et dans « Rapport
%               bras rotatif.xlsx » (feuille DONNÉES, cellule G25).
%   Statut : CONFIRMÉ (fiches) pour les trois valeurs.
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
P.materiaux(3).rho     = 7870;              % [kg/m^3] AISI 1020 (MatWeb)
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
% [Fourni] L'éjecteur monté est un SMC ZU07S (Infos visite Cégep.docx,
% 24 juin) ; [Web] son vide maximal est de -85 kPa à 0,45 MPa, sans fuite
% (catalogue SMC série ZU). Les notes de visite donnent « 10 à 12 psi »
% (69 à 83 kPa), valeur que son auteur doit reconfirmer.
% Statut : JUSTIFIÉ (décision d'équipe du 18 nov. 2026) : 60 kPa, sous ces
% deux valeurs, pour rester prudent face aux fuites.
P.vide = 60e3;                  % [Pa]  (60e3 veut dire 60 x 10^3 = 60 000)

% Facteur de sécurité visé pour la prise (valeur affichée à l'ouverture).
% [Web] Schmalz : au moins 1,5 pour des pièces lisses et étanches ; 2,0 ou
% plus pour des pièces critiques, poreuses, rugueuses ou huilées.
% Statut : JUSTIFIÉ (décision d'équipe du 18 nov. 2026). C'est une ENTRÉE
% de l'utilisateur ; 2,0 n'est que la valeur affichée à l'ouverture :
% rondelle lisse, mais vide supposé constant et frottement non mesuré.
% Même valeur que le facteur de sécurité du rapport (section 5.2.2).
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

% Les deux ROTATIONS gardent la duree comptee dans la video : ce sont des
% evenements visuellement nets, et elles sont les seules a entrer dans la
% physique (le transfert fixe les efforts et le facteur de securite).
P.duree.transfert = P.images.transfert / P.imagesParSeconde;  % [s]
P.duree.retour    = P.images.retour    / P.imagesParSeconde;  % [s]

% Duree totale du cycle imposee par le client.
% [Fourni] « Infos visite Cegep.docx », mandats : « raccourcir le cycle
% (6 s actuellement) ». Decision d'equipe du 14 nov. 2026 : on retient
% cette valeur plutot que les 8,0 s du decompte d'images, parce que les
% ATTENTES varient beaucoup d'un cycle a l'autre dans la video (3,5 s puis
% 8,5 s pour l'attente a la prise), alors que les deux rotations, elles,
% sont stables. Les attentes dependent du reste de la ligne, pas du bras.
% Statut : CONFIRME (valeur du client), repartition PROVISOIRE.
P.dureeCycle = 6.0;         % [s]

% Les deux ATTENTES se partagent ce qui reste du cycle, dans la proportion
% observee dans la video (105 images a la prise contre 84 au depot).
attentes = P.dureeCycle - P.duree.transfert - P.duree.retour;
if attentes <= 0
    error('RED:cycle', ...
        ['Cycle de %.2f s trop court : les deux rotations en occupent ' ...
         'deja %.2f s.'], P.dureeCycle, P.duree.transfert + P.duree.retour);
end
partPrise = P.images.attentePrise / (P.images.attentePrise + P.images.attenteDepot);
P.duree.attentePrise = attentes * partPrise;          % [s]
P.duree.attenteDepot = attentes * (1 - partPrise);    % [s]

%% ------------------------------------------------------------------------
%  7. ACTIONNEUR ET MASSES EN ROTATION
% -------------------------------------------------------------------------
% La consigne permet d'ajouter « le moment au pivot ». Le couple de
% l'actionneur sert à deux choses :
%   1. il FIXE la durée minimale de chaque rotation (dureeCouple.m) ;
%   2. il borne le domaine de validité : si le couple requis le dépasse,
%      l'interface l'indique (verifierDomaine.m).
% Mettre verifier = false désactive les deux : le couple tapé dans
% l'interface n'aurait alors plus aucun effet. À laisser à true.
P.actionneur.verifier = true;

% [Fourni] Catalogue Festo « Semi-rotary drive, metric DSR » (2025/03),
% p. 4, taille 16 : couple théorique de 2 N.m à 6 bar ; fréquence maximale
% d'oscillation de 3 Hz à 6 bar. Statut : CONFIRMÉ (catalogue).
P.actionneur.coupleCatalogue = 2.0; % [N.m] valeur du constructeur
P.actionneur.frequenceMax    = 3;   % [Hz]

% Couple UTILISÉ par le calcul. Depuis le 18 nov. 2026, c'est l'ENTRÉE
% principale de l'interface : la durée de chaque rotation en découle.
% Par défaut, on prend le couple du constructeur directement :
%   - le réseau est à 6 bar (Infos visite Cégep.docx, 24 juin), soit la
%     pression de référence du catalogue, donc aucune conversion ;
%   - on ne modélise PAS le couple en fonction de la pression : pour un
%     vérin rotatif, il n'existe pas de formule géométrique normalisée
%     (Techniques de l'Ingénieur BM 6 100, section 6.2.1) ;
%   - rendement de 100 % : aucune donnée de pertes n'est publiée pour le
%     DSR-16 (décision d'équipe du 18 nov. 2026).
% Voir le document « Limites du modèle ».
P.actionneur.couple = P.actionneur.coupleCatalogue;     % [N.m]

% Durée minimale d'une rotation que l'actionneur peut réaliser.
% La fiche Festo ne dit pas si « 3 Hz » compte des allers ou des
% allers-retours. Décision d'équipe du 19 nov. 2026 : 3 ALLERS (3
% pivotements) par seconde, donc une rotation dure au moins 1/3 = 0,333 s.
% C'est l'interprétation PRUDENTE : celle des allers-retours donnerait
% 0,167 s. [Claude] Avant le 19 nov. 2026, le programme utilisait 0,167 s.
% Statut : PROVISOIRE (interprétation prudente, la fiche est ambiguë).
P.actionneur.dureeMin = 1 / P.actionneur.frequenceMax;         % [s]

% --- Limite d'énergie en fin de course (sans butées externes) ---
% [Fourni] Fiche Festo DSR (2025/03), p. 5 : graphique « Mass moment of
% inertia as a function of swivel time t and swivel angle for DSR-16 ».
% Pour un temps de pivotement t, il donne le moment d'inertie MAXIMAL que
% le vérin peut entraîner sans butées externes. P. 4 : « If the specified
% maximum permissible mass moments of inertia are exceeded, external stops
% must be used » (taille 16 : rayon d'au moins 17 mm, effort d'au plus 160 N).
%
% [Claude] Ce que représente ce graphique : en fin de course, les tampons
% élastiques doivent absorber l'énergie cinétique du bras. Les points lus
% sur la courbe à 180° donnent tous la même énergie, calculée avec la
% vitesse moyenne pi/t :
%       E = 1/2 * J * (pi/t)^2  ~  0,011 J
% Les courbes à 90° et à 120° donnent la même valeur. On applique donc
% cette énergie à notre amplitude de 165,5° :
%       1/2 * J * (Dtheta/T)^2 <= Emax   =>   T >= Dtheta * racine(J/(2*Emax))
% (voir dureeFesto.m). Points lus sur la courbe [3] (180°), en [s] et en
% [1e-4 kg.m^2] ; lecture à environ 5 % près :
P.actionneur.festo.pointsCourbe180 = [0.192 0.78;  0.303 1.97;  0.495 5.4; ...
                                      0.748 12.4;  1.000 23.0;  1.500 52];
pts = P.actionneur.festo.pointsCourbe180;
energiesLues = 0.5 * pts(:, 2) * 1e-4 .* (pi ./ pts(:, 1)).^2;            % [J]
P.actionneur.festo.energieMax = mean(energiesLues);                        % [J] 0,0109 J
% Plus grand J lu sur le graphique (à t = 1,5 s). Au-delà, la durée
% calculée est une EXTRAPOLATION : Festo ne publie aucune valeur.
P.actionneur.festo.Jgraphique = max(pts(:, 2)) * 1e-4;                     % [kg.m^2]
% Configuration actuelle : AUCUNE butée externe ni amortisseur ([Fourni]
% Infos visite Cégep.docx, 24 juin : « Pas d'amortisseurs »). La limite
% est donc une contrainte stricte. Mettre false pour simuler un montage
% avec butées externes ou amortisseurs.
P.actionneur.festo.actif = true;
% [Fourni] Fiche p. 4 : sous 180°/s (vérin étranglé), il faut au moins
% 6 bar, et Festo annonce une variation des temps de ±30 %.
P.actionneur.festo.vitesseEtranglement = 180;                              % [deg/s]

% Bras + pont (pièces MPS-12-005 et MPS-12-002).
% [Fourni] SolidWorks, « Propriétés de masse » de chaque pièce, mesurées
% par Matis le 19 nov. 2026 (acier, 0,284 lb/po^3, unités livres et
% pouces). Pour chaque pièce :
%   m    = masse ;
%   Lyy  = moment d'inertie au centre de gravité, autour de l'axe Y du
%          repère par défaut, perpendiculaire à la grande face de la pièce,
%          donc parallèle à l'axe du pivot ;
%   d    = distance entre le point « Centre de masse » et l'axe du pivot
%          (outil Mesurer ; pivot = trou de l'Axe1, au bout du bras).
%
%   Pièce        m (lb)   Lyy (lb.po^2)   d (po)
%   MPS-12-002   0,278    1,704           3,428
%   MPS-12-005   0,402    1,851           3,492
%
% Le moment d'inertie de chaque pièce autour du pivot vient du théorème
% des axes parallèles : J = Lyy + m*d^2. Le bras est la somme des deux.
% Ces valeurs REMPLACENT l'hypothèse d'une barre uniforme de 200 mm
% (0,311 kg, centre de masse à 88,5 mm), qui donnait J = 3,47e-3 kg.m^2 :
% l'écart est de -1,2 % sur J (test C6 de testsRED.m).
% Statut : CONFIRMÉ (CAD, mesure de l'équipe).
lb = 0.45359237;            % [kg] une livre
po = 0.0254;                % [m]  un pouce
m002 = 0.278 * lb;   Lyy002 = 1.704 * lb * po^2;   d002 = 3.428 * po;
m005 = 0.402 * lb;   Lyy005 = 1.851 * lb * po^2;   d005 = 3.492 * po;

P.bras.masse  = m002 + m005;                                   % [kg]  0,308 kg
P.bras.distCM = (m002 * d002 + m005 * d005) / P.bras.masse;    % [m]   88,0 mm
P.bras.Jpivot = (Lyy002 + m002 * d002^2) + (Lyy005 + m005 * d005^2);   % [kg.m^2] 3,43e-3

% Longueur du bras : [Fourni] CAD MPS-12-005 (200 mm). Ne sert plus au
% calcul de J ; elle sert seulement au test C6 (comparaison avec l'ancien
% modèle de barre uniforme).
P.bras.longueur = 0.200;    % [m]

% Ancienne hypothèse, gardée pour la comparaison du test C6 :
% masse de l'assemblage MPS-12-000 (0,686 lb) et barre uniforme.
P.bras.ancienModele.masse  = 0.311;    % [kg]
P.bras.ancienModele.distCM = 0.0885;   % [m]

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
% La borne du couple est celui du plus gros DSR du catalogue (taille 40),
% pour permettre d'étudier un actionneur plus gros que le DSR-16.
P.saisie.coupleMax = 20;    % [N.m] couple maximal accepté
P.saisie.Tmax      = 20;    % [s] durée de transfert imposée maximale acceptée
P.saisie.FSmax     = 100;   % [-] facteur de sécurité maximal accepté

end
