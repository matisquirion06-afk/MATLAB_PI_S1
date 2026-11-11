function [thetaPrise, thetaDepot, amplitude] = anglesExtremes(P)
% ANGLESEXTREMES  Angles du bras à la prise et au dépôt, et amplitude du mouvement.
%
%   [thetaPrise, thetaDepot, amplitude] = anglesExtremes(P)
%
%   ENTRÉE
%     P            structure des paramètres (voir parametres.m)
%
%   SORTIES
%     thetaPrise   angle du bras quand la ventouse touche la pièce à la prise [rad]
%     thetaDepot   angle du bras quand la pièce est posée au dépôt [rad]
%     amplitude    rotation totale du bras pendant le transfert [rad]
%
%   CONVENTION D'ANGLE (utilisée dans TOUT le programme)
%     theta est l'angle du bras mesuré à partir de l'horizontale DU CÔTÉ
%     DE LA PRISE. Il augmente pendant le transfert (prise -> dépôt, en
%     passant par le haut) :
%
%                       theta = 90° (bras vertical)
%                              |
%            sens du           |
%            transfert  --->   |
%                              |
%     PRISE  ------------------O------------------  DÉPÔT
%     theta = 0°             pivot              theta = 180°
%
%   SCHÉMA (vue de côté, à la prise)
%
%          axe de la poulie  o
%                           /|
%                      R   / |  y = R*sin(phi)
%                         /  |
%                        /phi|
%              pivot    O----+-----  horizontale passant par le pivot
%                       |
%                       | hPivot
%          =============+===========  table
%
%     Quand la lèvre de la ventouse touche le dessus de la rondelle, l'axe
%     de la poulie est à la hauteur suivante au-dessus de la table :
%         hAppui (surface d'appui) + H (rondelle) + dLevre (ventouse)
%     Par rapport au pivot, sa hauteur est donc :
%         y = hAppui + H + dLevre - hPivot
%
%   ÉQUATIONS
%     sin(phi) = y / R            phi = angle au-dessus de l'horizontale
%     thetaPrise = phiPrise
%     thetaDepot = pi - phiDepot  (le dépôt est de l'autre côté du pivot)
%     amplitude  = thetaDepot - thetaPrise
%
%   SOURCE : [Claude] trigonométrie appliquée aux cotes du CAD et aux
%   hauteurs des notes de visite (voir parametres.m). À valider par l'équipe.

% --- 1. Hauteur de l'axe de la poulie par rapport au pivot [m] -----------
yPrise = P.hAppuiPrise + P.piece.H + P.dLevre - P.hPivot;
yDepot = P.hAppuiDepot + P.piece.H + P.dLevre - P.hPivot;

% --- 2. Vérification : le bras doit pouvoir atteindre ces hauteurs -------
% Le sinus d'un angle est toujours entre -1 et 1. Si |y| > R, la géométrie
% entrée dans parametres.m est impossible : on arrête avec un message clair.
if abs(yPrise) > P.R || abs(yDepot) > P.R
    error('RED:geometrie', ...
          ['Géométrie impossible : la ventouse ne peut pas atteindre la ' ...
           'hauteur de prise ou de dépôt. Vérifier les cotes dans parametres.m.']);
end

% --- 3. Angles au-dessus de l'horizontale [rad] ---------------------------
% asin est la fonction « arc sinus » : elle retourne l'angle en radians.
phiPrise = asin(yPrise / P.R);
phiDepot = asin(yDepot / P.R);

% --- 4. Angles dans la convention du programme [rad] ----------------------
thetaPrise = phiPrise;
thetaDepot = pi - phiDepot;

% --- 5. Amplitude du mouvement [rad] --------------------------------------
amplitude = thetaDepot - thetaPrise;

end
