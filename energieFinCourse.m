function E = energieFinCourse(P, masseTransportee, T, thetaI, thetaF)
% ENERGIEFINCOURSE  Énergie cinétique à absorber en fin de rotation, au sens de Festo.
%
%   E = energieFinCourse(P, masseTransportee, T, thetaI, thetaF)
%
%   ENTRÉES
%     P                  structure des paramètres (voir parametres.m)
%     masseTransportee   masse de la pièce portée [kg] (0 à vide)
%     T                  durée de la rotation [s]
%     thetaI, thetaF     angles de départ et d'arrivée [rad]
%
%   SORTIE
%     E    énergie [J] : E = 1/2 * J * (Dtheta / T)^2, avec la vitesse
%          moyenne, comme dans le graphique de la fiche Festo (p. 5).
%          À comparer à P.actionneur.festo.energieMax.
%
%   [Claude] Fonction ajoutée le 19 nov. 2026 (voir dureeFesto.m).

masseAuBout = P.masseVentouse + masseTransportee;                % [kg]
J = P.bras.Jpivot + masseAuBout * P.L^2;                         % [kg.m^2]
E = 0.5 * J * (abs(thetaF - thetaI) / T)^2;                      % [J]

end
