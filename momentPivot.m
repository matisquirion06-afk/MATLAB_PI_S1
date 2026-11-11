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
%     M.J          moment d'inertie total ramené au pivot [kg.m^2]
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
%   ÉQUATIONS (somme des moments autour du pivot = J * alpha)
%     couple = J * alpha + Mgravite
%
%     J        = Jbras + (mVentouse + mPiece) * R^2
%     Jbras    = mBras * (L^2/12 + dCM^2)
%                (barre uniforme de longueur L, théorème des axes
%                parallèles pour un centre de masse à dCM du pivot)
%     Mgravite = g * cos(theta) * (mBras*dCM + (mVentouse + mPiece)*R)
%
%     - L'ensemble ventouse et la pièce ne tournent pas sur eux-mêmes
%       (voir cinematiquePiece.m). Ils comptent donc comme des masses
%       placées à la distance R du pivot : m * R^2.
%     - Le bras de levier du poids est horizontal : distance * cos(theta).
%       Avant la verticale (theta < 90°), le poids s'oppose au mouvement ;
%       après la verticale, il l'aide (cos(theta) devient négatif).
%
%   SOURCE : [Claude] dynamique de rotation autour d'un axe fixe (matière
%   du cours de dynamique). Valeurs d'inertie PROVISOIRES : voir
%   parametres.m (à remplacer par les « Propriétés de masse » de SolidWorks).
%
%   LIMITES : frottements, tuyaux d'air et courroie négligés. Le couple de
%   2 N.m du catalogue est un couple THÉORIQUE à 6 bar.

% --- 1. Moment d'inertie du bras seul, par rapport au pivot [kg.m^2] ------
Jbras = P.bras.masse * (P.bras.longueur^2 / 12 + P.bras.distCM^2);

% --- 2. Masse placée au bout du bras [kg] ---------------------------------
masseAuBout = P.masseVentouse + masseTransportee;

% --- 3. Moment d'inertie total ramené au pivot [kg.m^2] -------------------
J = Jbras + masseAuBout * P.R^2;

% --- 4. Couple dû à la gravité [N.m] --------------------------------------
Mgravite = P.g * cos(theta) .* (P.bras.masse * P.bras.distCM + masseAuBout * P.R);

% --- 5. Couple requis de l'actionneur [N.m] --------------------------------
M.couple   = J .* alpha + Mgravite;
M.J        = J;
M.Mgravite = Mgravite;

end
