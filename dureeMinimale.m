function [Tmin, info] = dureeMinimale(P, iMat, FScible)
%% DUREEMINIMALE  Optimisation : plus petite durée de transfert qui respecte le facteur de sécurité.
%
%   [Tmin, info] = dureeMinimale(P, iMat, FScible)
%
%   ENTRÉES
%     P         structure des paramètres (voir parametres.m)
%     iMat      numéro du matériau (1 = Delrin, 2 = Aluminium, 3 = Acier)
%     FScible   facteur de sécurité exigé [-]
%
%   SORTIES
%     Tmin      durée de transfert minimale [s] (NaN s'il n'y a pas de solution)
%     info      structure d'information :
%       info.statut       'ok'            solution trouvée
%                         'impossible'    aucune durée ne respecte FScible
%                         'non_limitant'  la ventouse ne limite pas la durée
%       info.message      explication en français
%       info.iterations   nombre d'essais effectués
%       info.FSstatique   facteur de sécurité quand le bras est immobile
%       info.FSobtenu     facteur de sécurité minimal obtenu avec Tmin
%
%   LE PROBLÈME
%     Plus le transfert est rapide (T petit), plus les accélérations sont
%     grandes, donc plus la force requise est grande et plus le facteur de
%     sécurité minimal FSmin est petit. FSmin augmente toujours quand T
%     augmente. On cherche la durée T pour laquelle FSmin(T) = FScible.
%
%   LA MÉTHODE : RECHERCHE PAR DICHOTOMIE (ou bissection)
%     C'est le jeu « plus grand / plus petit » :
%       1. On part d'un intervalle [Tbas, Thaut] qui contient la solution :
%          à Tbas la prise n'est pas sûre, à Thaut elle l'est.
%       2. On essaie le milieu de l'intervalle.
%       3. Si la prise est sûre au milieu, la solution est plus bas : le
%          milieu devient la nouvelle borne haute. Sinon, il devient la
%          nouvelle borne basse.
%       4. On recommence jusqu'à ce que l'intervalle soit plus petit que la
%          précision demandée (P.recherche.tolerance).
%     L'intervalle est divisé par 2 à chaque essai : une vingtaine d'essais
%     suffisent.
%
%   SOURCE : [Claude] méthode numérique classique (dichotomie). Le résultat
%   est comparé à une formule directe dans verifIndependante.m.

info.iterations = 0;        % Le nombre d'itération est réinitialisé
info.FSobtenu   = NaN;      % Aucun facteur de sécurité minimal pour l'instant

%% --- 1. Cas sans solution : la prise n'est pas sûre même à l'arrêt ---------
% Bras immobile, la force requise est le poids m*g. Si le facteur de
% sécurité est déjà insuffisant, ralentir le bras ne changera rien.

m     = massePiece(P, iMat);            % [kg] Voir massePiece.m
Fvide = forceMaintien(P);               % [N]  Voir forceMaintient.m
info.FSstatique = Fvide / (m * P.g);    % [-]  Facteur de sécurité au repos

if info.FSstatique <= FScible       % La pièce n'est pas soutenu au repos
    Tmin = NaN;                     % Aucun temps minimale existe
    info.statut  = 'impossible';
    info.message = sprintf(['Aucune durée ne convient : même bras immobile, ' ...
        'le facteur de sécurité (%.2f) ne dépasse pas la cible (%.2f).'], ...
        info.FSstatique, FScible);
    return;         % on quitte la fonction tout de suite
end

%% --- 2. Intervalle de départ -----------------------------------------------
Tbas  = P.recherche.Tbas;       % [s] durée très courte
Thaut = P.recherche.Thaut;      % [s] durée très longue

% Prise pas sûre même avec la durée la plus longue : pas de solution dans
% l'intervalle (FScible est trop proche du facteur de sécurité statique).
if fsMinimal(P, iMat, Thaut) < FScible
    Tmin = NaN;
    info.statut  = 'impossible';
    info.message = sprintf(['Aucune durée de moins de %.0f s ne respecte ' ...
        'le facteur de sécurité cible (%.2f).'], Thaut, FScible);
    return;
end

% Prise déjà sûre avec la durée la plus courte : la ventouse ne limite pas.
if fsMinimal(P, iMat, Tbas) >= FScible
    Tmin = Tbas;
    info.statut   = 'non_limitant';
    info.FSobtenu = fsMinimal(P, iMat, Tbas);
    info.message  = sprintf(['La ventouse ne limite pas la durée : la prise ' ...
        'est sûre même pour T = %.3f s.'], Tbas);
    return;
end

%% --- 3. Dichotomie -----------------------------------------------------------
% « while » répète le bloc tant que la condition est vraie.
while (Thaut - Tbas) > P.recherche.tolerance

    Tmilieu = (Tbas + Thaut) / 2;
    info.iterations = info.iterations + 1;

    if fsMinimal(P, iMat, Tmilieu) >= FScible
        Thaut = Tmilieu;        % prise sûre : la solution est plus basse
    else
        Tbas = Tmilieu;         % prise pas sûre : la solution est plus haute
    end
end

%% --- 4. Résultat --------------------------------------------------------------
% On retient la borne HAUTE : c'est celle où la prise est sûre.
Tmin = Thaut;
info.statut   = 'ok';
info.FSobtenu = fsMinimal(P, iMat, Tmin);
info.message  = sprintf('Durée minimale trouvée en %d essais.', info.iterations);

end


% =============================================================================
function FSmin = fsMinimal(P, iMat, T)
% FSMINIMAL  Facteur de sécurité minimal pendant un transfert de durée T.
%   Petite fonction « locale » : elle n'est visible que dans ce fichier.
%   Elle refait le calcul complet du cycle et garde seulement FSmin.
res   = calculerCycle(P, iMat, T);
FSmin = res.FSmin;
end
