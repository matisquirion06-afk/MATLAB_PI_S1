function [Fvide, aire] = forceMaintien(P)
% FORCEMAINTIEN  Force de maintien théorique de la ventouse (capacité de la prise).
%
%   [Fvide, aire] = forceMaintien(P)
%
%   ENTRÉE
%     P       structure des paramètres (voir parametres.m)
%             On utilise P.vide [Pa] et P.ventouse.diametre [m].
%
%   SORTIES
%     Fvide   force de maintien théorique de la ventouse [N]
%     aire    aire de la ventouse [m^2]
%
%   ÉQUATIONS
%     aire  = pi * d^2 / 4          d = diamètre de la ventouse
%     Fvide = vide * aire           vide = niveau de vide (différence de pression)
%
%   EXEMPLE DE VÉRIFICATION À LA MAIN (d = 20 mm et vide = 60 kPa)
%     aire  = pi * 0,020^2 / 4 = 3,14 x 10^-4 m^2 = 3,14 cm^2
%     Fvide = 60 000 Pa * 3,14 x 10^-4 m^2 = 18,8 N
%
%   SOURCES
%     [Web] Schmalz, « Design of the suction cup » : F = delta_p x A
%           (force de maintien statique, sans facteur de sécurité).
%     [Web] SMC, guide de sélection des ventouses : force théorique
%           = P x S x 0,1 (P en kPa, S en cm^2). Pour 60 kPa et 3,14 cm^2 :
%           60 x 3,14 x 0,1 = 18,8 N. C'est la même équation.
%
%   LIMITE DU MODÈLE : c'est une valeur THÉORIQUE. La force réelle est plus
%   faible (fuites, déformation de la lèvre, surface de la pièce). C'est
%   une des raisons d'être du facteur de sécurité.

aire  = pi * P.ventouse.diametre^2 / 4;     % [m^2]
Fvide = P.vide * aire;                      % [N] = [Pa] x [m^2]

end
