function K = cinematiquePiece(P, theta, omega, alpha)
% CINEMATIQUEPIECE  Position, vitesse et accélération de la pièce (et de l'axe de la poulie).
%
%   K = cinematiquePiece(P, theta, omega, alpha)
%
%   ENTRÉES
%     P        structure des paramètres (voir parametres.m)
%     theta    position angulaire du bras [rad]
%     omega    vitesse angulaire du bras [rad/s]
%     alpha    accélération angulaire du bras [rad/s^2]
%              (nombres ou vecteurs de même taille)
%
%   SORTIE : structure K contenant
%     K.xAxe, K.yAxe   position de l'axe de la poulie de ventouse [m]
%     K.vx,   K.vy     vitesse de la pièce [m/s]
%     K.ax,   K.ay     accélération de la pièce [m/s^2]
%
%   REPÈRE (vue de côté, comme dans la vidéo)
%     origine : le pivot du bras
%     x : horizontal, positif vers le DÉPÔT (vers la droite)
%     y : vertical, positif vers le HAUT
%
%   HYPOTHÈSE PRINCIPALE : LA PIÈCE NE TOURNE PAS SUR ELLE-MÊME
%     La courroie crantée relie deux poulies identiques (22 dents chacune,
%     rapport 1:1), dont une est fixe au pivot. La ventouse reste donc
%     toujours verticale et la pièce reste horizontale. [Fourni] CAD
%     MPS-12-006 et MPS-12-007 ; consigne, section 5.4.
%     Conséquence : tous les points de la pièce ont le même mouvement que
%     l'axe de la poulie. La pièce décrit un arc de cercle de rayon R,
%     simplement décalé vers le bas. Le décalage ne change ni la vitesse
%     ni l'accélération.
%
%   ÉQUATIONS (position de l'axe de la poulie, puis dérivées par rapport au temps)
%     x  = L*cos(theta)                                 [m] Position en x
%     y  = L*sin(theta)                                 [m] Position en y
%
%     vx =  -L*omega*sin(theta)                         [m/s] Vitesse en x
%     vy =   L*omega*cos(theta)                         [m/s] Vitesse en y
%
%     ax =  -L*alpha*sin(theta) - L*omega^2*cos(theta)  [m/s^2] Accélération en x
%     ay =   L*alpha*cos(theta) - L*omega^2*sin(theta)  [m/s^2] Accélération en y
%

L = P.L;        % [m] rayon de la trajectoire

% --- Position de l'axe de la poulie [m] -----------------------------------
K.xAxe = L * cos(theta);
K.yAxe = L * sin(theta);

% --- Vitesse de la pièce [m/s] --------------------------------------------
K.vx = -L * omega .* sin(theta);
K.vy =  L * omega .* cos(theta);

% --- Accélération de la pièce [m/s^2] --------------------------------------
K.ax = -L * alpha .* sin(theta) - L * omega.^2 .* cos(theta);
K.ay =  L * alpha .* cos(theta) - L * omega.^2 .* sin(theta);

end
