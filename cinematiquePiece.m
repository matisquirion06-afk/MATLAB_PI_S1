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
%     x  = -R*cos(theta)
%     y  =  R*sin(theta)
%
%     vx =  R*omega*sin(theta)
%     vy =  R*omega*cos(theta)
%
%     ax =  R*alpha*sin(theta) + R*omega^2*cos(theta)
%     ay =  R*alpha*cos(theta) - R*omega^2*sin(theta)
%
%     Dans ax et ay, le terme en alpha est l'accélération TANGENTIELLE
%     (R*alpha, le long de la trajectoire) et le terme en omega^2 est
%     l'accélération NORMALE ou centripète (R*omega^2, dirigée vers le pivot).
%
%   SOURCE : [Claude] cinématique du mouvement circulaire (matière du cours
%   de dynamique). À vérifier par l'équipe avec le manuel du cours.

R = P.R;        % [m] rayon de la trajectoire

% --- Position de l'axe de la poulie [m] -----------------------------------
K.xAxe = -R * cos(theta);
K.yAxe =  R * sin(theta);

% --- Vitesse de la pièce [m/s] --------------------------------------------
K.vx = R * omega .* sin(theta);
K.vy = R * omega .* cos(theta);

% --- Accélération de la pièce [m/s^2] --------------------------------------
K.ax = R * alpha .* sin(theta) + R * omega.^2 .* cos(theta);
K.ay = R * alpha .* cos(theta) - R * omega.^2 .* sin(theta);

end
