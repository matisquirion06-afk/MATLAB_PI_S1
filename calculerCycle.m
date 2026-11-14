function res = calculerCycle(P, iMat, T)
% CALCULERCYCLE  Calcul complet d'un cycle pour un matériau : c'est le « chef d'orchestre ».
%
%   res = calculerCycle(P, iMat, T)
%
%   ENTRÉES
%     P        structure des paramètres (voir parametres.m)
%     iMat     numéro du matériau (1 = Delrin, 2 = Aluminium, 3 = Acier)
%     T        durée du transfert avec pièce [s]
%
%   SORTIE : structure res qui réunit TOUS les résultats.
%
%   Cette fonction ne contient aucune équation de physique. Elle appelle
%   les autres fonctions dans le bon ordre, comme une recette :
%
%     construireCycle   -> mouvement du bras (theta, omega, alpha)
%     cinematiquePiece  -> accélération de la pièce (ax, ay)
%     massePiece        -> masse de la pièce (m)
%     effortVentouse    -> effort de la ventouse et force de maintien requise
%     forceMaintien     -> force de maintien théorique de la ventouse
%     facteurSecurite   -> facteur de sécurité à chaque instant
%     momentPivot       -> couple requis au pivot (vérification facultative)
%
%   TRAÇABILITÉ (exigence de la consigne) : chaque résultat important vient
%   d'une seule fonction, qui contient son équation, ses entrées et ses
%   unités :
%     res.theta, res.omega, res.alpha  -> DeplacementAngulaire.m
%     res.ax, res.ay                   -> cinematiquePiece.m
%     res.masse                        -> parametres.m
%     res.Fnorme, res.Frequis          -> effortVentouse.m
%     res.Fvide                        -> forceMaintien.m
%     res.FS, res.FSmin                -> facteurSecurite.m
%     res.couple                       -> momentPivot.m

% --- 1. Mouvement du bras sur tout le cycle ------------------------------
C = construireCycle(P, T);

% --- 2. Mouvement de la pièce --------------------------------------------
K = cinematiquePiece(P, C.theta, C.omega, C.alpha);

% --- 3. Masse de la pièce ------------------------------------------------
[m, V] = massePiece(P, iMat);
mu     = P.materiaux(iMat).mu;

% --- 4. Effort de la ventouse (2e loi de Newton) -------------------------
E = effortVentouse(m, P.g, K.ax, K.ay, mu);

% --- 5. Capacité de la ventouse et facteur de sécurité -------------------
[Fvide, aire] = forceMaintien(P);
FS = facteurSecurite(Fvide, E.Frequis);

% --- 6. Garder les efforts seulement quand la pièce est tenue ------------
% C.tenue est vrai pendant l'étape 4 (transfert). Le symbole ~ veut dire
% « non ». Aux autres instants, on met NaN (« Not a Number ») : Matlab ne
% trace pas ces points et les ignore dans les calculs de min et de max.
pasTenue = ~C.tenue;
E.Fx(pasTenue)      = NaN;
E.Fy(pasTenue)      = NaN;
E.Fnorme(pasTenue)  = NaN;
E.Frequis(pasTenue) = NaN;
FS(pasTenue)        = NaN;

% --- 7. Couple requis au pivot -------------------------------------------
% La pièce est portée seulement pendant le transfert : sa masse compte
% alors dans l'inertie. (C.tenue vaut 1 ou 0 dans la multiplication.)
masseTransportee = m * C.tenue;
Mp = momentPivot(P, masseTransportee, C.theta, C.alpha);

% --- 8. Valeurs clés -----------------------------------------------------
% [valeur, indice] = max(vecteur) donne la plus grande valeur ET sa position
% dans le vecteur. On s'en sert pour retrouver l'instant correspondant.
[FnormeMax,  iF]  = max(E.Fnorme);
[FrequisMax, iR]  = max(E.Frequis);
[FSmin,      iFS] = min(FS);
[coupleMax,  iC]  = max(abs(Mp.couple));

% --- 9. Ranger tous les résultats dans la structure de sortie ------------
% a) Rappel des entrées
res.iMat        = iMat;
res.nomMateriau = P.materiaux(iMat).nom;
res.T           = T;

% b) Cycle et mouvement du bras
res.t           = C.t;              % [s]
res.theta       = C.theta;          % [rad]
res.omega       = C.omega;          % [rad/s]
res.alpha       = C.alpha;          % [rad/s^2]
res.etape       = C.etape;          % [-] numéro d'étape (1 à 4)
res.tenue       = C.tenue;          % vrai si la pièce est tenue
res.nomsEtapes  = C.nomsEtapes;
res.tDebutEtape = C.tDebutEtape;    % [s]
res.tFinEtape   = C.tFinEtape;      % [s]
res.dureeCycle  = C.dureeCycle;     % [s]
res.cadence     = 60 / C.dureeCycle;    % [pièces/min]
res.thetaPrise  = C.thetaPrise;     % [rad]
res.thetaDepot  = C.thetaDepot;     % [rad]
res.amplitude   = C.amplitude;      % [rad]

% c) Mouvement de la pièce
res.xAxe = K.xAxe;                  % [m]
res.yAxe = K.yAxe;                  % [m]
res.ax   = K.ax;                    % [m/s^2]
res.ay   = K.ay;                    % [m/s^2]

% d) Pièce
res.masse  = m;                     % [kg]
res.volume = V;                     % [m^3]
res.poids  = m * P.g;               % [N]
res.mu     = mu;                    % [-]

% e) Efforts et facteur de sécurité
res.Fx       = E.Fx;                % [N]
res.Fy       = E.Fy;                % [N]
res.Fnorme   = E.Fnorme;            % [N]
res.Frequis  = E.Frequis;           % [N]
res.Fvide    = Fvide;               % [N]
res.aireVentouse = aire;            % [m^2]
res.FS       = FS;                  % [-]

res.FnormeMax   = FnormeMax;        % [N] plus grand effort pendant le transfert
res.tFnormeMax  = C.t(iF);          % [s] instant de cet effort
res.FrequisMax  = FrequisMax;       % [N] plus grande force de maintien requise
res.tFrequisMax = C.t(iR);          % [s]
res.FSmin       = FSmin;            % [-] plus petit facteur de sécurité
res.tFSmin      = C.t(iFS);         % [s]
res.FSstatique  = Fvide / (m * P.g);    % [-] facteur de sécurité bras immobile

% f) Couple au pivot
res.couple     = Mp.couple;         % [N.m]
res.coupleMax  = coupleMax;         % [N.m] plus grand couple (valeur absolue)
res.tCoupleMax = C.t(iC);           % [s]

end
