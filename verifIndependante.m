function V = verifIndependante(P, iMat, T, FScible, afficher)
% VERIFINDEPENDANTE  Vérifie les résultats importants par un calcul indépendant.
%
%   V = verifIndependante(P, iMat, T, FScible)
%   V = verifIndependante(P, iMat, T, FScible, false)   sans affichage
%
%   ENTRÉES
%     P         structure des paramètres (voir parametres.m)
%     iMat      numéro du matériau (1 = Delrin, 2 = Aluminium, 3 = Acier)
%     T         durée du transfert [s]
%     FScible   facteur de sécurité cible [-]
%     afficher  (facultatif) true pour écrire le tableau à l'écran (par défaut)
%
%   SORTIE : structure V
%     V.noms        noms des résultats comparés
%     V.programme   valeurs calculées par le programme principal
%     V.independant valeurs du calcul indépendant
%     V.ecart       écart relatif entre les deux [%]
%     V.reussi      true si tous les écarts sont sous la tolérance (1 %)
%
%   EXIGENCE DE LA CONSIGNE
%     « Les résultats importants doivent être vérifiés par un calcul
%     indépendant (calcul manuel, tableur ou fonction Matlab simple et
%     distincte). » Le document d'accompagnement doit comparer au moins
%     deux résultats, par exemple l'effort maximal et le FS minimal.
%
%   EN QUOI CE CALCUL EST-IL INDÉPENDANT ?
%     Le programme principal obtient l'accélération par DÉRIVATION
%     ANALYTIQUE (formules de DeplacementAngulaire.m et de cinematiquePiece.m).
%     Ici, on n'utilise AUCUNE de ces formules de vitesse ou d'accélération :
%       1. on calcule seulement la POSITION de la pièce à des instants
%          très rapprochés ;
%       2. on obtient l'accélération par DIFFÉRENCES FINIES, c'est-à-dire
%          en comparant trois positions voisines :
%              a(c) = ( x(c+1) - 2*x(c) + x(c-1) ) / dt^2
%       3. on refait les calculs de masse, de force et de facteur de
%          sécurité avec des lignes de code écrites séparément.
%     Si une formule du programme principal contenait une erreur de signe
%     ou de dérivation, les deux calculs ne donneraient pas le même résultat.
%
%     (La consigne interdit de dériver les mesures de la VIDÉO, parce
%     qu'elles sont trop imprécises. Ici, on dérive une position calculée
%     exactement : la méthode est fiable.)
%
%   VÉRIFICATION DE LA DURÉE MINIMALE PAR UNE FORMULE DIRECTE
%     Pour une loi donnée, toutes les accélérations sont proportionnelles
%     à 1/T^2. La force de maintien requise maximale s'écrit donc :
%         F_requis_max = m * (g + K / T^2)
%     où K [m] est une constante qu'on mesure sur le mouvement calculé.
%     En posant F_vide / F_requis_max = FS_cible, on isole T :
%         T_min = racine( K / ( F_vide / (m * FS_cible) - g ) )
%     Cette formule est comparée au résultat de la dichotomie.

if nargin < 5
    afficher = true;        % nargin = nombre d'entrées fournies à la fonction
end

tolerance = 1.0;            % [%] écart relatif maximal accepté

% =====================================================================================
%  A. RÉSULTATS DU PROGRAMME PRINCIPAL
% =====================================================================================
res  = calculerCycle(P, iMat, T);
[~, infoMin] = dureeMinimale(P, iMat, FScible);

% [Claude] On compare la durée imposée par la VENTOUSE, pas la durée finale
% retenue : depuis le 14 nov. 2026, dureeMinimale.m combine la ventouse,
% le couple et la fréquence, et la formule directe ci-dessous ne décrit que
% la ventouse. Comparer la durée finale à cette formule reviendrait à
% comparer deux grandeurs différentes.
Tventouse = infoMin.Tventouse;

% =====================================================================================
%  B. CALCUL INDÉPENDANT
% =====================================================================================

% --- B1. Masse et force de maintien, recalculées directement ----------------------------
D = P.piece.D;   H = P.piece.H;
volume = pi * D^2 * H / 4 ...
       - pi * P.piece.diamTrou^2 * P.piece.profTrou / 4 ...
       - pi * P.piece.diamCone^2 * P.piece.profCone / 12;
masse  = P.materiaux(iMat).rho * volume;                    % [kg]
mu     = P.materiaux(iMat).mu;
Fvide  = P.vide * pi * P.ventouse.diametre^2 / 4;           % [N]

% --- B2. Position de la pièce à 20 001 instants très rapprochés --------------------------
N  = 20001;
t  = linspace(0, T, N);
dt = t(2) - t(1);                                           % [s] pas de temps

thetaPrise = P.thetaPrise;
thetaDepot = P.thetaDepot;
theta = DeplacementAngulaire(t, T, thetaPrise, thetaDepot);

x =  P.L * cos(theta);                                      % [m]
y =  P.L * sin(theta);                                      % [m]

% --- B3. Accélération par différences finies ----------------------------------------------
% On calcule pour les points 2 à N-1 (il faut un voisin de chaque côté).
c  = 2:(N-1);                                               % points « du centre »
ax = (x(c+1) - 2*x(c) + x(c-1)) / dt^2;                     % [m/s^2]
ay = (y(c+1) - 2*y(c) + y(c-1)) / dt^2;                     % [m/s^2]

% --- B4. Efforts et facteur de sécurité -----------------------------------------------------
Fx = masse * ax;
Fy = masse * (P.g + ay);
effortTotal   = sqrt(Fx.^2 + Fy.^2);
maintienRequis = Fy + abs(Fx) / mu;
maintienRequis(maintienRequis < 0) = 0;

effortMax_ind = max(effortTotal);
FSmin_ind     = Fvide / max(maintienRequis);

% --- B5. Durée minimale par la formule directe ----------------------------------------------
% K : valeur maximale de (ay + |ax|/mu), ramenée à une durée de 1 s (x T^2).
K = max(ay + abs(ax) / mu) * T^2;                           % [m]
denominateur = Fvide / (masse * FScible) - P.g;
if denominateur > 0
    Tmin_ind = sqrt(K / denominateur);
else
    Tmin_ind = NaN;         % pas de solution : prise insuffisante même à l'arrêt
end

% --- B6. Bras immobile : l'effort doit être égal au poids --------------------------------------
E0 = effortVentouse(masse, P.g, 0, 0, mu);
poids_ind = masse * P.g;

% --- B7. Durée minimale imposée par le couple de l'actionneur ---------------------------------
% [Claude] Vérification ajoutée le 14 nov. 2026 pour dureeCouple.m.
% À la durée que la fonction annonce comme minimale, le couple maximal
% requis doit valoir exactement la capacité de l'actionneur. On le
% recalcule ici par un chemin complètement différent : l'accélération
% angulaire vient de DIFFÉRENCES FINIES sur theta(t), et l'inertie est
% réécrite à la main, sans passer par momentPivot.m.
Tcouple = dureeCouple(P, masse, thetaPrise, thetaDepot);

if isnan(Tcouple)
    coupleMax_ind = NaN;
    coupleVise    = NaN;
else
    tc  = linspace(0, Tcouple, N);
    dtc = tc(2) - tc(1);                                    % [s]
    thc = DeplacementAngulaire(tc, Tcouple, thetaPrise, thetaDepot);

    alphaC = (thc(c+1) - 2*thc(c) + thc(c-1)) / dtc^2;      % [rad/s^2]

    masseAuBout = P.masseVentouse + masse;                  % [kg]
    Jind = P.bras.Jpivot + masseAuBout * P.L^2;             % [kg.m^2]
    Mgrav = P.g * cos(thc(c)) * (P.bras.masse * P.bras.distCM ...
          + masseAuBout * P.L);                             % [N.m]

    coupleMax_ind = max(abs(Jind * alphaC + Mgrav));        % [N.m]
    coupleVise    = P.actionneur.couple;                    % [N.m]
end

% --- B8. La même durée minimale, par une FORMULE DIRECTE sans itération ----------------------
% [Claude] Vérification ajoutée le 18 nov. 2026.
%
%   dureeCouple.m trouve la durée par dichotomie : il essaie des valeurs
%   jusqu'à tomber sur la bonne. La même durée s'obtient d'un seul coup,
%   sans aucun essai, et c'est ce que l'on fait ici.
%
%   L'accélération angulaire de la loi cubique vaut Dtheta*s''/T^2, et
%   |s''| ne dépasse jamais 6. L'accélération maximale est donc
%
%       alpha_max = 6*Dtheta / T^2
%
%   Elle est atteinte aux deux extrémités du mouvement, c'est-à-dire là où
%   le bras est le plus proche de l'horizontale et où le couple de gravité
%   est lui aussi le plus grand : les deux termes s'additionnent. En
%   écrivant que leur somme égale la capacité de l'actionneur,
%
%       J * 6*Dtheta/T^2  +  M_gravite  =  C_max
%
%   puis en isolant T :
%
%       T = racine( 6*J*Dtheta / (C_max - M_gravite) )
%
%   Aucune itération, aucun appel à momentPivot.m ni à DeplacementAngulaire.m :
%   c'est un chemin entièrement distinct de celui du programme.
%
%   Cette formule n'a pas remplacé la dichotomie dans le programme, parce
%   que la dichotomie traite aussi le critère de la ventouse, qui n'a pas
%   de forme aussi simple. Elle sert ici de contrôle.

if isnan(Tcouple)
    Tcouple_ind = NaN;
else
    masseBout = P.masseVentouse + masse;                    % [kg]
    Jdirect = P.bras.Jpivot + masseBout * P.L^2;            % [kg.m^2]

    % Couple de gravité à l'angle d'arrivée (le plus défavorable des deux
    % extrémités : c'est celle dont |cos(theta)| est le plus grand).
    MgravDepot = P.g * abs(cos(thetaDepot)) ...
               * (P.bras.masse * P.bras.distCM + masseBout * P.L);     % [N.m]
    MgravPrise = P.g * abs(cos(thetaPrise)) ...
               * (P.bras.masse * P.bras.distCM + masseBout * P.L);     % [N.m]
    MgravMax = max(MgravDepot, MgravPrise);                 % [N.m]

    coupleDisponible = P.actionneur.couple - MgravMax;      % [N.m]

    if coupleDisponible <= 0
        Tcouple_ind = NaN;      % la gravité consomme déjà tout le couple
    else
        Tcouple_ind = sqrt(6 * Jdirect * abs(thetaDepot - thetaPrise) ...
                           / coupleDisponible);             % [s]
    end
end

% =====================================================================================
%  C. COMPARAISON
% =====================================================================================
V.noms        = {'Effort total maximal (N)', 'FS minimal (-)', ...
                 'Durée min. imposée par la ventouse (s)', ...
                 'Effort bras immobile = poids (N)', ...
                 'Couple max à la durée min. couple (N.m)', ...
                 'Durée min. imposée par le couple (s)'};
V.programme   = [res.FnormeMax, res.FSmin, Tventouse, E0.Fnorme, coupleVise,    Tcouple];
V.independant = [effortMax_ind, FSmin_ind, Tmin_ind,  poids_ind, coupleMax_ind, Tcouple_ind];
V.ecart       = 100 * abs(V.programme - V.independant) ./ abs(V.independant);    % [%]

% Une comparaison avec NaN (pas de solution) n'est pas un échec si les DEUX
% calculs concluent qu'il n'y a pas de solution.
sansSolution = isnan(V.programme) & isnan(V.independant);
V.ecart(sansSolution) = 0;

V.reussi = all(V.ecart < tolerance);

% =====================================================================================
%  D. AFFICHAGE
% =====================================================================================
if afficher
    fprintf('\nVÉRIFICATION PAR UN CALCUL INDÉPENDANT\n');
    fprintf('Matériau : %s ; T = %.3f s ; FS cible = %.2f\n\n', ...
            P.materiaux(iMat).nom, T, FScible);
    fprintf('%-36s | %12s | %12s | %9s | %s\n', ...
            'Résultat', 'Programme', 'Indépendant', 'Écart (%)', 'Verdict');
    fprintf('%s\n', repmat('-', 1, 88));
    for k = 1:numel(V.noms)
        if V.ecart(k) < tolerance
            verdict = 'Conforme';
        else
            verdict = 'ÉCART';
        end
        fprintf('%-36s | %12.5f | %12.5f | %9.4f | %s\n', ...
                V.noms{k}, V.programme(k), V.independant(k), V.ecart(k), verdict);
    end
    fprintf('\nTolérance : écart relatif inférieur à %.1f %%.\n\n', tolerance);
end

end
