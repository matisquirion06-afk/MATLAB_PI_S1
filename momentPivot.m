function M = momentPivot(P, masseTransportee, theta, alpha)
% MOMENTPIVOT  Couple que l'actionneur doit fournir au pivot du bras (vérification facultative).
%
%   M = momentPivot(P, masseTransportee, theta, alpha)
%
%   ENTRÉES
%     P                  structure des paramètres (voir parametres.m)
%     masseTransportee   masse de la pièce portée par la ventouse [kg]
%                        (0 quand le bras est vide ; nombre ou vecteur)
%     theta              position angulaire du bras [rad]
%     alpha              accélération angulaire du bras [rad/s^2]
%
%   SORTIE : structure M contenant
%     M.couple     couple requis de l'actionneur [N.m] (positif dans le
%                  sens du transfert)
%     M.I          moment d'inertie total ramené au pivot [kg.m^2]
%     M.Mgravite   part du couple qui sert à vaincre la gravité [N.m]
%
%   À QUOI SERT CETTE FONCTION
%     La consigne permet d'ajouter le moment au pivot au modèle. Ici, il
%     sert de GARDE-FOU : la ventouse peut théoriquement tenir la pièce
%     pendant une rotation très rapide que l'actionneur, lui, est
%     incapable de produire. L'interface affiche donc un avertissement
%     quand le couple requis dépasse le couple de l'actionneur
%     (P.actionneur.couple).
%
%   ÉQUATIONS (somme des moments autour du pivot = I * alpha)
%       coupleActionneur - Mgravite = I*alpha
%
%               où Mgravite = Mbras + Mven
%                  Mgravite = (L/2)*(Pbras)*cos(theta) + (L)*(Pven)*cos(theta)
%               Mgravite = (L)*(g)*cos(theta)*((1/2)*(mBras) + mVentouse + mPiece)
%
%
%       Le moment d'inertie I est le moment d'inertie total.
%               I = Ibras + Iven
%                  où Ibras est le moment d'inertie du bras autour du
%                  pivot, tiré de SolidWorks (P.bras.Jpivot, voir
%                  parametres.m), et Iven est celui du système de ventouse,
%                  traité comme une masse ponctuelle à l'axe de la poulie
%                  (la courroie le garde vertical : il se déplace sans
%                  tourner sur lui-même).
%
%               Ibras = P.bras.Jpivot
%               Iven  = (mVentouse + mPiece) * (L^2)
%
%       [Claude] Avant le 19 nov. 2026, Ibras était approximé par une barre
%       uniforme : mBras * ((lBras^2)/12 + (dCM)^2). La valeur SolidWorks
%       l'a remplacé ; l'écart est de -1,2 % (test C6 de testsRED.m).
%
%       On isole alors le couple transmis par l'actionneur pneumatique
%           coupleActionneur = (Ibras + Iven)*alpha + (Mgravite)
%
% --- 1. Moment d'inertie du bras seul, par rapport au pivot [kg.m^2] -----
Ibras = P.bras.Jpivot;

% --- 2. Moment d'inertie du système ventouse [kg.m^2] --------------------
masseAuBout = P.masseVentouse + masseTransportee;
Iven = masseAuBout * P.L^2;

% --- 3. Moment d'inertie total ramené au pivot [kg.m^2] ------------------
I = Ibras + Iven;

% --- 4. Couple dû à la gravité [N.m] -------------------------------------
Mgravite = P.g * cos(theta) .* (P.bras.masse * P.bras.distCM + masseAuBout * P.L);


% --- 5. Couple requis de l'actionneur [N.m] ------------------------------
M.couple   = I .* alpha + Mgravite;
M.J        = I;
M.Mgravite = Mgravite;


end
