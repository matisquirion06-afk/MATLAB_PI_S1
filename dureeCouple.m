function [Tmin, info] = dureeCouple(P, masseTransportee, thetaI, thetaF)
%% DUREECOUPLE  Plus petite durée de rotation que l'actionneur peut fournir.
%
%   [Tmin, info] = dureeCouple(P, masseTransportee, thetaI, thetaF)
%
%   ENTRÉES
%     P                  structure des paramètres (voir parametres.m)
%     masseTransportee   masse portée au bout du bras [kg]
%                        (0 pour le retour à vide, m pour le transfert)
%     thetaI, thetaF     angles de départ et d'arrivée [rad]
%
%   SORTIES
%     Tmin      durée minimale admissible [s] (NaN si aucune solution)
%     info      structure d'information :
%       info.statut       'ok'            solution trouvée
%                         'impossible'    le couple statique dépasse déjà
%                                         la capacité de l'actionneur
%                         'non_limitant'  le couple ne limite pas la durée
%       info.message      explication en français
%       info.iterations   nombre d'essais effectués
%       info.coupleStatique  couple requis bras immobile [N.m]
%       info.coupleObtenu    couple requis avec Tmin [N.m]
%
%   LE PROBLÈME
%     L'actionneur ne peut pas fournir plus que P.actionneur.couple. Le
%     couple requis au pivot vaut (voir momentPivot.m) :
%
%         M = J * alpha + g * cos(theta) * (m_bras*d_CM + m_bout*L)
%             \_______/   \_____________________________________/
%              inertie                  gravité
%
%     L'accélération angulaire alpha varie comme 1/T^2 : diviser la durée
%     par 2 multiplie le terme d'inertie par 4. Le terme de gravité, lui,
%     ne dépend pas de T. Donc quand T augmente, le couple maximal requis
%     diminue toujours, et tend vers le couple de gravité seul.
%
%     On cherche la durée T pour laquelle le couple maximal requis pendant
%     la rotation égale exactement la capacité de l'actionneur.
%
%   LA MÉTHODE : RECHERCHE PAR DICHOTOMIE
%     Même principe que dans dureeMinimale.m : on coupe en deux un
%     intervalle qui contient la solution, jusqu'à la précision voulue.
%     La décroissance du couple avec T garantit qu'il n'y a qu'une seule
%     solution, donc que la dichotomie converge vers la bonne valeur.
%
%   POURQUOI CE FICHIER EXISTE
%     [Claude] Avant la correction du 14 nov. 2026, l'optimisation ne
%     tenait compte que de la ventouse. Elle proposait des durées de
%     transfert que l'actionneur ne peut pas réaliser : 0,142 s pour le
%     Delrin exigeait 6,46 N.m, soit plus de trois fois les 2,00 N.m
%     disponibles. Le programme affichait bien un avertissement, mais
%     retenait quand même la valeur irréalisable.
%
%   SOURCE : [Claude] dichotomie appliquée à l'équation de momentPivot.m.
%   La valeur de P.actionneur.couple vient de la fiche de l'actionneur
%   (voir parametres.m, section 9).

info.iterations      = 0;
info.coupleObtenu    = NaN;

Cmax = P.actionneur.couple;         % [N.m] capacité de l'actionneur

%% --- 1. Cas sans solution : la gravité seule dépasse déjà la capacité ------
% Bras immobile (alpha = 0), il ne reste que le couple de gravité. Si
% l'actionneur ne peut même pas tenir le bras en place, ralentir la
% rotation ne changera rien.

info.coupleStatique = coupleMaximal(P, masseTransportee, thetaI, thetaF, Inf);

if info.coupleStatique >= Cmax
    Tmin = NaN;
    info.statut  = 'impossible';
    info.message = sprintf(['Aucune durée ne convient : même bras immobile, ' ...
        'le couple de gravité (%.2f N.m) atteint la capacité de ' ...
        'l''actionneur (%.2f N.m).'], info.coupleStatique, Cmax);
    return;
end

%% --- 2. Intervalle de départ -----------------------------------------------
Tbas  = P.recherche.Tbas;           % [s] durée très courte
Thaut = P.recherche.Thaut;          % [s] durée très longue

% Rotation déjà réalisable avec la durée la plus courte : le couple ne
% limite pas.
if coupleMaximal(P, masseTransportee, thetaI, thetaF, Tbas) <= Cmax
    Tmin = Tbas;
    info.statut        = 'non_limitant';
    info.coupleObtenu  = coupleMaximal(P, masseTransportee, thetaI, thetaF, Tbas);
    info.message       = sprintf(['Le couple ne limite pas la durée : la ' ...
        'rotation passe même en T = %.3f s.'], Tbas);
    return;
end

%% --- 3. Dichotomie ----------------------------------------------------------
while (Thaut - Tbas) > P.recherche.tolerance

    Tmilieu = (Tbas + Thaut) / 2;
    info.iterations = info.iterations + 1;

    if coupleMaximal(P, masseTransportee, thetaI, thetaF, Tmilieu) <= Cmax
        Thaut = Tmilieu;        % rotation réalisable : la solution est plus bas
    else
        Tbas = Tmilieu;         % couple dépassé : la solution est plus haut
    end
end

%% --- 4. Résultat -------------------------------------------------------------
% On retient la borne HAUTE : c'est celle où la rotation est réalisable.
Tmin = Thaut;
info.statut       = 'ok';
info.coupleObtenu = coupleMaximal(P, masseTransportee, thetaI, thetaF, Tmin);
info.message      = sprintf('Durée minimale trouvée en %d essais.', info.iterations);

end


% =============================================================================
function c = coupleMaximal(P, masseTransportee, thetaI, thetaF, T)
% COUPLEMAXIMAL  Plus grand couple requis (en valeur absolue) pendant une
%                rotation de durée T.
%   Petite fonction « locale » : elle n'est visible que dans ce fichier.
%
%   T = Inf correspond au bras immobile : il ne reste que la gravité. On
%   parcourt quand même tous les angles, parce que le couple de gravité
%   dépend de theta (il est maximal quand le bras est horizontal).

if isinf(T)
    theta = linspace(thetaI, thetaF, P.nPts);
    alpha = zeros(1, P.nPts);
else
    tLocal = linspace(0, T, P.nPts);
    [theta, ~, alpha] = DeplacementAngulaire(tLocal, T, thetaI, thetaF);
end

M = momentPivot(P, masseTransportee, theta, alpha);
c = max(abs(M.couple));

end
