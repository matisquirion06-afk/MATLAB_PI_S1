function [Tmin, info] = dureeMinimale(P, iMat, FScible)
%% DUREEMINIMALE  Optimisation : plus petite durée de transfert réalisable.
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
%                         'impossible'    aucune durée ne convient
%       info.limite       'ventouse'   c'est la succion qui limite
%                         'couple'     c'est l'actionneur qui limite
%                         'frequence'  c'est la fréquence maximale qui limite
%                         'aucune'     aucune contrainte n'est active
%       info.message      explication en français
%       info.iterations   nombre d'essais effectués (ventouse + couple)
%       info.FSstatique   facteur de sécurité quand le bras est immobile
%       info.FSobtenu     facteur de sécurité minimal obtenu avec Tmin
%       info.Tventouse    durée minimale imposée par la ventouse [s]
%       info.Tcouple      durée minimale imposée par l'actionneur [s]
%       info.Tfrequence   durée minimale imposée par la fréquence max [s]
%
%   LES TROIS CONTRAINTES
%     Le transfert doit satisfaire TOUTES les limites physiques à la fois.
%     Chacune impose sa propre durée minimale, et c'est la PLUS GRANDE des
%     trois qui gouverne :
%
%       Tmin = max( T_ventouse , T_couple , T_frequence )
%
%     1. VENTOUSE (calculée ici)
%        Plus le transfert est rapide, plus les accélérations sont grandes,
%        donc plus la force de maintien requise est grande et plus le
%        facteur de sécurité FSmin est petit. FSmin augmente toujours quand
%        T augmente. On cherche la durée pour laquelle FSmin(T) = FScible.
%
%     2. ACTIONNEUR : COUPLE (calculée par dureeCouple.m)
%        Le couple requis au pivot varie comme 1/T^2. L'actionneur ne peut
%        pas fournir plus que P.actionneur.couple.
%
%     3. ACTIONNEUR : FRÉQUENCE (simple lecture de P.actionneur.dureeMin)
%        Une rotation ne peut pas durer moins d'une demi-période de la
%        fréquence maximale de l'actionneur.
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
%   ERREUR CORRIGÉE LE 14 NOV. 2026
%     [Claude] Cette fonction ne vérifiait que la ventouse. Elle retournait
%     par exemple 0,142 s pour le Delrin, une durée qui exige 6,46 N.m au
%     pivot alors que l'actionneur en fournit 2,00. L'interface affichait
%     un avertissement, mais la valeur irréalisable était quand même
%     retenue et appliquée au cycle. Les trois contraintes sont maintenant
%     combinées, ce qui explique aussi pourquoi le transfert chargé devient
%     plus lent que le retour à vide, et non l'inverse.
%
%   SOURCE : [Claude] méthode numérique classique (dichotomie). Le résultat
%   est comparé à une formule directe dans verifIndependante.m.

info.iterations = 0;        % Le nombre d'itération est réinitialisé
info.FSobtenu   = NaN;      % Aucun facteur de sécurité minimal pour l'instant
info.Tcouple    = NaN;
info.Tfrequence = NaN;

%% --- 1. Cas sans solution : la prise n'est pas sûre même à l'arrêt ---------
% Bras immobile, la force requise est le poids m*g. Si le facteur de
% sécurité est déjà insuffisant, ralentir le bras ne changera rien.

m     = massePiece(P, iMat);            % [kg] Voir massePiece.m
Fvide = forceMaintien(P);               % [N]  Voir forceMaintien.m
info.FSstatique = Fvide / (m * P.g);    % [-]  Facteur de sécurité au repos

if info.FSstatique <= FScible       % La pièce n'est pas soutenu au repos
    Tmin = NaN;                     % Aucun temps minimale existe
    info.statut  = 'impossible';
    info.limite  = 'ventouse';
    info.Tventouse = NaN;
    info.message = sprintf(['Aucune durée ne convient : même bras immobile, ' ...
        'le facteur de sécurité (%.2f) ne dépasse pas la cible (%.2f).'], ...
        info.FSstatique, FScible);
    return;         % on quitte la fonction tout de suite
end

%% --- 2. Contrainte 1 : la ventouse ----------------------------------------
Tbas  = P.recherche.Tbas;       % [s] durée très courte
Thaut = P.recherche.Thaut;      % [s] durée très longue

% Prise pas sûre même avec la durée la plus longue : pas de solution dans
% l'intervalle (FScible est trop proche du facteur de sécurité statique).
if fsMinimal(P, iMat, Thaut) < FScible
    Tmin = NaN;
    info.statut  = 'impossible';
    info.limite  = 'ventouse';
    info.Tventouse = NaN;
    info.message = sprintf(['Aucune durée de moins de %.0f s ne respecte ' ...
        'le facteur de sécurité cible (%.2f).'], Thaut, FScible);
    return;
end

if fsMinimal(P, iMat, Tbas) >= FScible
    % Prise déjà sûre avec la durée la plus courte : la ventouse ne limite pas.
    Tventouse = Tbas;
else
    % Dichotomie.
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
    % On retient la borne HAUTE : c'est celle où la prise est sûre.
    Tventouse = Thaut;
end

info.Tventouse = Tventouse;

%% --- 3. Contraintes 2 et 3 : l'actionneur ---------------------------------
% P.actionneur.verifier permet de désactiver la prise en compte de
% l'actionneur, par exemple pour étudier la ventouse seule.

if P.actionneur.verifier
    [Tcouple, infoCouple] = dureeCouple(P, m, P.thetaPrise, P.thetaDepot);
    info.iterations = info.iterations + infoCouple.iterations;

    if strcmp(infoCouple.statut, 'impossible')
        Tmin = NaN;
        info.statut  = 'impossible';
        info.limite  = 'couple';
        info.Tcouple = NaN;
        info.message = infoCouple.message;
        return;
    end

    info.Tcouple    = Tcouple;
    info.Tfrequence = P.actionneur.dureeMin;
else
    Tcouple    = 0;
    info.Tcouple    = NaN;
    info.Tfrequence = NaN;
end

%% --- 4. La plus contraignante des trois -----------------------------------
% max(...) choisit la plus grande : c'est la seule durée qui satisfait
% toutes les contraintes à la fois.

if P.actionneur.verifier
    candidats = [Tventouse, Tcouple, P.actionneur.dureeMin];
    noms      = {'ventouse', 'couple', 'frequence'};
else
    candidats = Tventouse;
    noms      = {'ventouse'};
end

[Tmin, iLimite] = max(candidats);

if Tmin <= P.recherche.Tbas
    info.limite = 'aucune';
else
    info.limite = noms{iLimite};
end

%% --- 5. Résultat --------------------------------------------------------------
info.statut   = 'ok';
info.FSobtenu = fsMinimal(P, iMat, Tmin);

switch info.limite
    case 'ventouse'
        info.message = sprintf(['Durée limitée par la VENTOUSE (%.3f s). ' ...
            'L''actionneur permettrait %.3f s.'], Tventouse, Tcouple);
    case 'couple'
        info.message = sprintf(['Durée limitée par le COUPLE de l''actionneur ' ...
            '(%.3f s). La ventouse permettrait %.3f s.'], Tcouple, Tventouse);
    case 'frequence'
        info.message = sprintf(['Durée limitée par la FRÉQUENCE maximale de ' ...
            'l''actionneur (%.3f s).'], P.actionneur.dureeMin);
    otherwise
        info.message = 'Aucune contrainte n''est active sur cette durée.';
end

end


% =============================================================================
function FSmin = fsMinimal(P, iMat, T)
% FSMINIMAL  Facteur de sécurité minimal pendant un transfert de durée T.
%   Petite fonction « locale » : elle n'est visible que dans ce fichier.
%   Elle refait le calcul complet du cycle et garde seulement FSmin.
res   = calculerCycle(P, iMat, T);
FSmin = res.FSmin;
end
