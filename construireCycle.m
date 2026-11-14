function C = construireCycle(P, T, Tretour)
%% CONSTRUIRECYCLE  Mouvement du bras pendant un cycle complet (4 étapes).
%
%   C = construireCycle(P, T)
%   C = construireCycle(P, T, Tretour)
%
%   ENTRÉES
%     P        structure des paramètres (voir parametres.m)
%     T        durée du transfert avec pièce (prise -> dépôt) [s]
%     Tretour  durée du retour à vide (dépôt -> prise) [s], FACULTATIF.
%              Si l'argument est absent ou vide, on prend P.duree.retour,
%              c'est-à-dire la valeur comptée dans la vidéo.
%
%
%   SORTIE : structure C contenant
%     C.t            temps depuis le début du cycle [s]            (vecteur)
%     C.theta        position angulaire du bras [rad]              (vecteur)
%     C.omega        vitesse angulaire du bras [rad/s]             (vecteur)
%     C.alpha        accélération angulaire du bras [rad/s^2]      (vecteur)
%     C.etape        numéro de l'étape en cours (1 à 4)            (vecteur)
%     C.tenue        vrai (true) quand la pièce est tenue par la ventouse
%     C.nomsEtapes   noms des 4 étapes
%     C.tDebutEtape  temps de début de chaque étape [s]
%     C.tFinEtape    temps de fin de chaque étape [s]
%     C.dureeCycle   durée totale du cycle [s]
%     C.thetaPrise, C.thetaDepot, C.amplitude   angles extrêmes [rad]
%
%   LES 4 ÉTAPES DU CYCLE (ordre observé dans la vidéo)
%     1. Attente au dépôt     bras immobile, position initiale
%     2. Retour à vide        rotation dépôt -> prise SANS pièce
%     3. Attente à la prise   bras immobile au-dessus de la pièce (aspiration)
%     4. Transfert            rotation prise -> dépôt AVEC la pièce (durée T)
%
%   Les durées des étapes 2 et 4 sont celles que l'optimisation cherche à
%   réduire : ce sont les deux rotations. Les deux attentes (étapes 1 et 3)
%   viennent de la vidéo (parametres.m).
%
%   [Claude] Avant le 14 nov. 2026, seule l'étape 4 était optimisable :
%   l'étape 2 gardait toujours sa durée vidéo. On comparait donc une durée
%   optimisée à une durée mesurée, ce qui donnait l'impression que le bras
%   allait plus vite chargé qu'à vide.
%
%   HYPOTHÈSE : la pièce est portée par la ventouse seulement pendant
%   l'étape 4. Aux autres étapes, elle repose sur son support.



%% --- 0. Argument facultatif ---------------------------------------------
% nargin = « number of arguments in » : combien d'arguments ont été passés.
% Si le troisième manque, on prend la durée de retour de parametres.m.
if nargin < 3 || isempty(Tretour)
    Tretour = P.duree.retour;       % [s] valeur comptée dans la vidéo
end

%% --- 1. Angles extrêmes du bras -----------------------------------------
thetaPrise = P.thetaPrise;
thetaDepot = P.thetaDepot;
amplitude = abs(thetaDepot-thetaPrise);



%% --- 2. Description des 4 étapes ----------------------------------------
nomsEtapes = {'1. Attente au dépôt', ...
    '2. Retour à vide', ...
    '3. Attente à la prise', ...
    '4. Transfert'};

%                    étape 1              étape 2               étape 3           étape 4
durees     = [P.duree.attenteDepot,     Tretour,        P.duree.attentePrise,       T     ];
angleDebut = [     thetaDepot,          thetaDepot,          thetaPrise,        thetaPrise];
angleFin   = [     thetaDepot,          thetaPrise,          thetaPrise,        thetaDepot];



nEtapes = 4;                        % nombre d'étapes
n       = P.nPts;                   % nombre de points de calcul par étape

%% --- 3. Réserver la mémoire des vecteurs résultats ----------------------
% zeros(1, N) crée un vecteur ligne de N zéros qu'on remplit ensuite.
t     = zeros(1, nEtapes*n);
theta = zeros(1, nEtapes*n);
omega = zeros(1, nEtapes*n);
alpha = zeros(1, nEtapes*n);
etape = zeros(1, nEtapes*n);

tDebutEtape = zeros(1, nEtapes);
tFinEtape   = zeros(1, nEtapes);


%% --- 4. Calculer chaque étape et la placer à la suite des autres --------
tDepart = 0;                        % [s] temps au début de l'étape en cours

for k = 1:nEtapes

    % Temps « local » : il repart de 0 au début de chaque étape.
    % linspace(a, b, n) crée n valeurs également espacées entre a et b.
    tLocal = linspace(0, durees(k), n);

    if angleDebut(k) == angleFin(k)
        % Étape d'attente : le bras ne bouge pas.
        thetaK = angleDebut(k) * ones(1, n);
        omegaK = zeros(1, n);
        alphaK = zeros(1, n);
    else
        % Étape de rotation : on applique la loi de mouvement.
        [thetaK, omegaK, alphaK] = DeplacementAngulaire(tLocal, durees(k), ...
            angleDebut(k), angleFin(k));
    end

    % Positions (indices) de cette étape dans les grands vecteurs.
    % Exemple avec n = 400 : étape 1 -> 1 à 400, étape 2 -> 401 à 800, etc.
    indices = (k-1)*n + (1:n);

    t(indices)     = tDepart + tLocal;
    theta(indices) = thetaK;
    omega(indices) = omegaK;
    alpha(indices) = alphaK;
    etape(indices) = k;

    tDebutEtape(k) = tDepart;
    tFinEtape(k)   = tDepart + durees(k);

    tDepart = tDepart + durees(k);  % l'étape suivante commence ici
end

%% --- 5. Ranger les résultats dans la structure de sortie ----------------
C.t           = t;
C.theta       = theta;
C.omega       = omega;
C.alpha       = alpha;
C.etape       = etape;
C.tenue       = (etape == 4);       % la pièce est tenue pendant l'étape 4
C.nomsEtapes  = nomsEtapes;
C.tDebutEtape = tDebutEtape;
C.tFinEtape   = tFinEtape;
C.dureeCycle  = tDepart;
C.thetaPrise  = thetaPrise;
C.thetaDepot  = thetaDepot;
C.amplitude   = amplitude;

end











