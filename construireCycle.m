function C = construireCycle(P, T, nomLoi)
% CONSTRUIRECYCLE  Mouvement du bras pendant un cycle complet (4 étapes).
%
%   C = construireCycle(P, T, nomLoi)
%
%   ENTRÉES
%     P        structure des paramètres (voir parametres.m)
%     T        durée du transfert avec pièce (prise -> dépôt) [s]
%     nomLoi   loi de mouvement : 'cubique', 'quintique' ou 'cycloidale'
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
%     1. Attente à la prise   bras immobile au-dessus de la pièce (aspiration)
%     2. Transfert            rotation prise -> dépôt AVEC la pièce (durée T)
%     3. Attente au dépôt     bras immobile, la pièce est relâchée
%     4. Retour à vide        rotation dépôt -> prise SANS pièce
%
%   La durée T de l'étape 2 est celle que l'optimisation cherche à
%   réduire. Les trois autres durées viennent de la vidéo (parametres.m).
%
%   HYPOTHÈSE : la pièce est portée par la ventouse seulement pendant
%   l'étape 2. Aux étapes 1 et 3, elle repose sur son support.

% --- 1. Angles extrêmes du bras ------------------------------------------
[thetaPrise, thetaDepot, amplitude] = anglesExtremes(P);

% --- 2. Description des 4 étapes ------------------------------------------
nomsEtapes = {'1. Attente à la prise', ...
              '2. Transfert avec la pièce', ...
              '3. Attente au dépôt', ...
              '4. Retour à vide'};

%            étape 1                étape 2      étape 3                étape 4
durees     = [P.duree.attentePrise, T,           P.duree.attenteDepot,  P.duree.retour];
angleDebut = [thetaPrise,           thetaPrise,  thetaDepot,            thetaDepot];
angleFin   = [thetaPrise,           thetaDepot,  thetaDepot,            thetaPrise];

nEtapes = 4;
n       = P.nPts;                   % nombre de points de calcul par étape

% --- 3. Réserver la mémoire des vecteurs résultats ------------------------
% zeros(1, N) crée un vecteur ligne de N zéros qu'on remplit ensuite.
t     = zeros(1, nEtapes*n);
theta = zeros(1, nEtapes*n);
omega = zeros(1, nEtapes*n);
alpha = zeros(1, nEtapes*n);
etape = zeros(1, nEtapes*n);

tDebutEtape = zeros(1, nEtapes);
tFinEtape   = zeros(1, nEtapes);

% --- 4. Calculer chaque étape et la placer à la suite des autres ----------
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
        [thetaK, omegaK, alphaK] = loiMouvement(nomLoi, tLocal, durees(k), ...
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

% --- 5. Ranger les résultats dans la structure de sortie ------------------
C.t           = t;
C.theta       = theta;
C.omega       = omega;
C.alpha       = alpha;
C.etape       = etape;
C.tenue       = (etape == 2);       % la pièce est tenue pendant l'étape 2
C.nomsEtapes  = nomsEtapes;
C.tDebutEtape = tDebutEtape;
C.tFinEtape   = tFinEtape;
C.dureeCycle  = tDepart;
C.thetaPrise  = thetaPrise;
C.thetaDepot  = thetaDepot;
C.amplitude   = amplitude;

end
