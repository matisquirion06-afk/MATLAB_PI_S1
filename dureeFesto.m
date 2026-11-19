function [T, info] = dureeFesto(P, masseTransportee, thetaI, thetaF)
% DUREEFESTO  Durée minimale d'une rotation selon la limite d'énergie Festo.
%
%   [T, info] = dureeFesto(P, masseTransportee, thetaI, thetaF)
%
%   ENTRÉES
%     P                  structure des paramètres (voir parametres.m)
%     masseTransportee   masse de la pièce portée [kg] (0 pour le retour à vide)
%     thetaI, thetaF     angles de départ et d'arrivée du bras [rad]
%
%   SORTIES
%     T      durée minimale de la rotation [s]
%     info   structure :
%       info.J           moment d'inertie total ramené au pivot [kg.m^2]
%       info.energieMax  énergie admissible en fin de course [J]
%       info.vitesseMoy  vitesse angulaire moyenne à cette durée [deg/s]
%       info.extrapole   true si J dépasse le plus grand J du graphique
%                        Festo : la durée est alors une extrapolation
%       info.etrangle    true si la vitesse moyenne est sous 180°/s : le
%                        vérin doit être étranglé (au moins 6 bar, ±30 %)
%
%   LE PRINCIPE (voir parametres.m, « Limite d'énergie en fin de course »)
%     Sans butées externes, les tampons élastiques du vérin doivent
%     absorber l'énergie cinétique du bras en fin de course. Le graphique
%     de la fiche Festo (p. 5) correspond à une énergie admissible Emax,
%     calculée avec la vitesse moyenne de la rotation :
%
%         1/2 * J * (Dtheta / T)^2 <= Emax
%
%     d'où la durée minimale :
%
%         T = Dtheta * racine( J / (2 * Emax) )
%
%     Le vérin réel n'est pas freiné en douceur : il frappe ses tampons.
%     C'est pourquoi on utilise la vitesse moyenne, comme Festo, et non la
%     vitesse nulle d'arrivée de la loi cubique du programme.
%
%   SOURCE : [Fourni] fiche Festo DSR (2025/03), p. 4 et 5 ; [Claude]
%   interprétation du graphique comme une énergie constante (voir le test
%   F2 de testsRED.m, qui la compare aux points lus).
%
%   [Claude] Fonction ajoutée le 19 nov. 2026.

masseAuBout = P.masseVentouse + masseTransportee;                % [kg]
J      = P.bras.Jpivot + masseAuBout * P.L^2;                    % [kg.m^2]
Dtheta = abs(thetaF - thetaI);                                   % [rad]
Emax   = P.actionneur.festo.energieMax;                          % [J]

T = Dtheta * sqrt(J / (2 * Emax));                               % [s]

info.J          = J;
info.energieMax = Emax;
info.vitesseMoy = Dtheta / T * 180 / pi;                         % [deg/s]
info.extrapole  = (J > P.actionneur.festo.Jgraphique);
info.etrangle   = (info.vitesseMoy < P.actionneur.festo.vitesseEtranglement);

end
