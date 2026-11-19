function reussi = sauvegarderResultats(chemin, P, R, iMat, FScible, Tmin, infoOpt, ...
                                       modeDurees, TretourMin)
% SAUVEGARDERRESULTATS  Écrit les résultats dans un fichier texte.
%
%   reussi = sauvegarderResultats(chemin, P, R, iMat, FScible, Tmin, infoOpt)
%   reussi = sauvegarderResultats(..., modeDurees, TretourMin)
%
%   ENTRÉES
%     chemin      nom complet du fichier à créer (exemple : 'C:\...\resultats.txt')
%     P           structure des paramètres (voir parametres.m) ; le couple
%                 de l'actionneur utilisé est P.actionneur.couple
%     R           résultats des trois matériaux : R{i} = sortie de calculerCycle.m
%                 ([] si le couple ne suffit pas pour ce matériau)
%     iMat        numéro du matériau choisi dans l'interface
%     FScible     facteur de sécurité cible [-]
%     Tmin        durées minimales du transfert [s], une par matériau (NaN si impossible)
%     infoOpt     informations sur ces durées (sorties de dureeMinimale.m)
%     modeDurees  FACULTATIF : 1 = durées calculées au couple (par défaut),
%                              2 = durées mesurées sur la vidéo,
%                              3 = transfert imposé par l'utilisateur
%     TretourMin  FACULTATIF : durée minimale du retour à vide [s]
%
%   SORTIE
%     reussi    true si le fichier a été écrit, false sinon
%
%   EXIGENCE DE LA CONSIGNE : « sauvegarde des résultats dans un fichier texte ».
%
%   CONTENU DU FICHIER
%     1. Entrées choisies              5. État de la prise et domaine de validité
%     2. Résultats du matériau choisi  6. Tableau des hypothèses
%     3. Comparaison des matériaux     7. Traçabilité (résultat -> équation -> fonction)
%     4. Optimisation                  8. Valeurs calculées pendant le transfert
%
%   COMMENT ÉCRIRE DANS UN FICHIER
%     fid = fopen(nom, 'w')    ouvre le fichier en écriture ('w' = write) et
%                              retourne un numéro (fid) ; -1 si échec
%     fprintf(fid, ...)        écrit du texte dans le fichier ; '\n' = retour
%                              à la ligne ; %s = texte ; %.2f = nombre à 2 décimales
%     fclose(fid)              ferme le fichier (obligatoire à la fin)

reussi = false;
res    = R{iMat};                       % résultats du matériau choisi
deg    = 180 / pi;                      % conversion rad -> degrés

% Arguments facultatifs (nargin = nombre d'arguments reçus)
if nargin < 8 || isempty(modeDurees)
    modeDurees = 1;
end
if nargin < 9
    TretourMin = NaN;
end

% --- Ouvrir le fichier (encodage UTF-8 pour conserver les accents) -------------------
fid = fopen(chemin, 'w', 'n', 'UTF-8');
if fid == -1
    return;                             % échec : dossier protégé, nom invalide, etc.
end

trait = repmat('=', 1, 100);            % une ligne de 100 signes « = »

% --- En-tête ---------------------------------------------------------------------------
fprintf(fid, '%s\n', trait);
fprintf(fid, ' SYSTÈME RAMASSE-DÉPOSE (RED) - RÉSULTATS DU PROGRAMME MATLAB - ÉQUIPE 14\n');
fprintf(fid, '%s\n', trait);
fprintf(fid, 'Date et heure : %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, 'Unités : SI (m, kg, s, N, Pa), angles en degrés sauf indication contraire.\n');
fprintf(fid, 'ATTENTION : version préliminaire. Les valeurs marquées « Provisoire » dans le\n');
fprintf(fid, 'tableau des hypothèses (section 6) restent à confirmer.\n\n');

% --- 1. Entrées --------------------------------------------------------------------------
if abs(P.actionneur.couple - P.actionneur.coupleCatalogue) < 1e-9
    origineCouple = 'catalogue Festo, DSR-16 à 6 bar';
else
    origineCouple = sprintf('MODIFIÉ (catalogue : %.2f N.m)', P.actionneur.coupleCatalogue);
end
switch modeDurees
    case 1
        origineDurees = 'calculées à ce couple (vitesse maximale)';
    case 2
        origineDurees = 'mesurées sur la vidéo';
    otherwise
        origineDurees = 'transfert imposé par l''utilisateur, retour mesuré sur la vidéo';
end

fprintf(fid, '1. ENTRÉES CHOISIES DANS L''INTERFACE\n');
fprintf(fid, '   Matériau de la pièce        : %s\n', res.nomMateriau);
fprintf(fid, '   Couple de l''actionneur      : %.3f N.m (%s)\n', P.actionneur.couple, origineCouple);
fprintf(fid, '   Facteur de sécurité cible   : %.2f\n', FScible);
fprintf(fid, '   Durées des rotations        : %s\n', origineDurees);
fprintf(fid, '   Loi de mouvement            : polynomiale cubique (degre 3)\n\n');

fprintf(fid, '   DURÉES QUI EN DÉCOULENT (résultats, pas des entrées)\n');
fprintf(fid, '   Transfert avec pièce (étape 4) : %.3f s\n', res.T);
fprintf(fid, '   Retour à vide (étape 2)        : %.3f s\n\n', res.Tretour);

% --- 2. Résultats du matériau choisi ---------------------------------------------------------
fprintf(fid, '2. RÉSULTATS POUR LE MATÉRIAU CHOISI (%s)\n', res.nomMateriau);
fprintf(fid, '   Masse de la pièce                 : %.2f g\n', res.masse * 1000);
fprintf(fid, '   Poids de la pièce                 : %.4f N\n', res.poids);
fprintf(fid, '   Force de maintien de la ventouse  : %.3f N\n', res.Fvide);
fprintf(fid, '   Effort total maximal (Newton)     : %.4f N  à t = %.3f s\n', res.FnormeMax, res.tFnormeMax);
fprintf(fid, '   Force de maintien requise max     : %.4f N  à t = %.3f s\n', res.FrequisMax, res.tFrequisMax);
fprintf(fid, '   Facteur de sécurité minimal       : %.3f    à t = %.3f s\n', res.FSmin, res.tFSmin);
fprintf(fid, '   Facteur de sécurité bras immobile : %.3f\n', res.FSstatique);
fprintf(fid, '   Angle du bras à la prise          : %.2f°\n', res.thetaPrise * deg);
fprintf(fid, '   Angle du bras au dépôt            : %.2f°\n', res.thetaDepot * deg);
fprintf(fid, '   Amplitude de rotation             : %.2f°\n', res.amplitude * deg);
fprintf(fid, '   Vitesse angulaire maximale        : %.3f rad/s\n', max(abs(res.omega(res.tenue))));
fprintf(fid, '   Accélération angulaire maximale   : %.3f rad/s^2\n', max(abs(res.alpha(res.tenue))));
fprintf(fid, '   Couple maximal requis au pivot    : %.3f N.m (actionneur : %.2f N.m)\n', ...
        res.coupleMax, P.actionneur.couple);
fprintf(fid, '   Durée du cycle complet            : %.3f s\n', res.dureeCycle);
fprintf(fid, '   Cadence                           : %.3f pièces/min\n\n', res.cadence);

fprintf(fid, '   Étapes du cycle :\n');
for k = 1:numel(res.nomsEtapes)
    fprintf(fid, '      %-28s de %.3f s à %.3f s (durée %.3f s)\n', res.nomsEtapes{k}, ...
            res.tDebutEtape(k), res.tFinEtape(k), res.tFinEtape(k) - res.tDebutEtape(k));
end
fprintf(fid, '\n');

% --- 3. Comparaison des matériaux ----------------------------------------------------------------
if modeDurees == 1
    fprintf(fid, '3. COMPARAISON DES MATÉRIAUX (chacun à SA durée minimale, couple %.2f N.m)\n', ...
            P.actionneur.couple);
else
    fprintf(fid, '3. COMPARAISON DES MATÉRIAUX (même durée T = %.3f s pour les trois)\n', res.T);
end
fprintf(fid, '   %-12s %10s %10s %10s %16s %10s %12s %12s %14s %13s\n', ...
        'Matériau', 'Masse (g)', 'Poids (N)', 'T (s)', 'Effort max (N)', 'FS min', 'Cycle (s)', ...
        'T FS (s)', 'T couple (s)', 'T Festo (s)');
for i = 1:numel(R)
    nom = P.materiaux(i).nom;
    m   = massePiece(P, i);
    if isempty(R{i})
        fprintf(fid, '   %-12s %10.2f %10.4f   impossible : couple insuffisant\n', ...
                nom, m * 1000, m * P.g);
    else
        fprintf(fid, '   %-12s %10.2f %10.4f %10.3f %16.4f %10.3f %12.3f %12.4f %14.4f %13.4f\n', nom, ...
                m * 1000, m * P.g, R{i}.T, R{i}.FnormeMax, R{i}.FSmin, R{i}.dureeCycle, ...
                infoOpt{i}.Tventouse, infoOpt{i}.Tcouple, infoOpt{i}.Tfesto);
    end
end
fprintf(fid, '\n');

% --- 4. Durées minimales permises par le couple --------------------------------------------------------
fprintf(fid, '4. DURÉES MINIMALES AU COUPLE DE %.2f N.m ET POUR FS >= %.2f\n', ...
        P.actionneur.couple, FScible);
fprintf(fid, '   La durée d''une rotation est un RÉSULTAT : la plus courte qui respecte à la\n');
fprintf(fid, '   fois le couple de l''actionneur, la ventouse et la fréquence maximale.\n');
fprintf(fid, '   Point d) de la consigne : la durée minimale compatible avec le FS cible est\n');
fprintf(fid, '   la durée « ventouse » ci-dessous (T FS). La durée retenue est la plus longue\n');
fprintf(fid, '   des quatre limites : ventouse, couple, fréquence et énergie en fin de course\n');
fprintf(fid, '   (fiche Festo DSR, p. 5, sans butées externes : Emax = %.4f J).\n', ...
        P.actionneur.festo.energieMax);
for i = 1:numel(R)
    info = infoOpt{i};
    nom  = P.materiaux(i).nom;
    if strcmp(info.statut, 'impossible')
        fprintf(fid, '   %-12s : %s\n', nom, info.message);
    else
        fprintf(fid, '   %-12s : transfert T min = %.4f s ; contrainte active : %s\n', ...
                nom, Tmin(i), upper(info.limite));
        fprintf(fid, '                  (ventouse %.4f s ; couple %.4f s ; fréquence %.4f s ; Festo %.4f s)\n', ...
                info.Tventouse, info.Tcouple, info.Tfrequence, info.Tfesto);
    end
end
if isnan(TretourMin)
    fprintf(fid, '   Retour à vide : impossible ou non calculé\n');
else
    fprintf(fid, '   Retour à vide : T min = %.4f s (plus longue des limites de l''actionneur)\n', TretourMin);
end
fprintf(fid, '   Méthode : dichotomie pour la ventouse et le couple (dureeMinimale.m et\n');
fprintf(fid, '             dureeCouple.m, précision de %g s) ; formule directe pour la\n', P.recherche.tolerance);
fprintf(fid, '             limite Festo (dureeFesto.m).\n');
fprintf(fid, '   Comparaison : cycle mesuré sur la vidéo = %.2f s (%.2f pièces/min).\n\n', ...
        P.dureeCycle, 60 / P.dureeCycle);

% --- 5. État de la prise et domaine de validité --------------------------------------------------------------
fprintf(fid, '5. ÉTAT DE LA PRISE ET DOMAINE DE VALIDITÉ (matériau choisi)\n');
[niveau, lignes] = verifierDomaine(P, res, FScible);
fprintf(fid, '   Niveau : %s\n', niveau);
for k = 1:numel(lignes)
    fprintf(fid, '   - %s\n', lignes{k});
end
fprintf(fid, '\n');

% --- 6. Tableau des hypothèses -----------------------------------------------------------------------------------
fprintf(fid, '6. HYPOTHÈSES, VALEURS ESTIMÉES ET UNITÉS\n');
tab = tableauHypotheses(P);
for i = 1:size(tab, 1)
    fprintf(fid, '   %-62s | %-12s | %9s | %-7s | %-26s | %s\n', ...
            tab{i, 1}, tab{i, 2}, tab{i, 3}, tab{i, 4}, tab{i, 6}, tab{i, 5});
end
fprintf(fid, '\n');

% --- 7. Traçabilité -----------------------------------------------------------------------------------------------------
fprintf(fid, '7. TRAÇABILITÉ : RÉSULTAT -> ÉQUATION -> FONCTION MATLAB\n');
fprintf(fid, '   Angles extrêmes       : sin(phi) = (h + H + d_levre - h_pivot) / L       -> hauteurAxePoulie.m\n');
fprintf(fid, '   theta, omega, alpha   : theta = theta_i + delta_theta * s(t/T), dérivées  -> DeplacementAngulaire.m\n');
fprintf(fid, '   Accélération pièce    : ax = -L*alpha*sin - L*omega^2*cos ; ay = L*alpha*cos - L*omega^2*sin -> cinematiquePiece.m\n');
fprintf(fid, '   Masse                 : m = rho * V                                         -> massePiece.m\n');
fprintf(fid, '   Effort de la ventouse : Fx = m*ax ; Fy = m*(g + ay) (2e loi de Newton)      -> effortVentouse.m\n');
fprintf(fid, '   Maintien requis       : F_requis = Fy + |Fx| / mu                           -> effortVentouse.m\n');
fprintf(fid, '   Force de maintien     : F_vide = delta_p * pi * d^2 / 4                     -> forceMaintien.m\n');
fprintf(fid, '   Facteur de sécurité   : FS = F_vide / F_requis                              -> facteurSecurite.m\n');
fprintf(fid, '   Durée minimale        : T_min = max(T_ventouse, T_couple, T_frequence, T_festo) -> dureeMinimale.m\n');
fprintf(fid, '     dont ventouse       : FS_min(T) = FS_cible, résolue par dichotomie        -> dureeMinimale.m\n');
fprintf(fid, '     dont couple         : max|M(T)| = M_actionneur, résolue par dichotomie    -> dureeCouple.m\n');
fprintf(fid, '     dont Festo          : T = Dtheta * racine(J / (2 Emax)), formule directe  -> dureeFesto.m\n');
fprintf(fid, '       contre-verification : T = racine(6*J*Dtheta / (M_actionneur - M_gravite)) -> verifIndependante.m\n');
fprintf(fid, '   Couple au pivot       : M = J*alpha + g*cos(theta)*(somme des m*d)          -> momentPivot.m\n\n');

% --- 8. Valeurs calculées pendant le transfert ---------------------------------------------------------------------------------
fprintf(fid, '8. VALEURS CALCULÉES PENDANT LE TRANSFERT (un point sur 8)\n');
fprintf(fid, '   %8s %9s %9s %10s %9s %9s %9s %9s %9s %9s %9s\n', ...
        't (s)', 'theta(°)', 'omega', 'alpha', 'ax', 'ay', 'Fx (N)', 'Fy (N)', '|F| (N)', 'Freq (N)', 'FS');
fprintf(fid, '   %8s %9s %9s %10s %9s %9s\n', '', '', '(rad/s)', '(rad/s^2)', '(m/s^2)', '(m/s^2)');

indices = find(res.tenue);              % numéros des points où la pièce est tenue
for k = indices(1:8:end)                % « 1:8:end » = un point sur 8
    fprintf(fid, '   %8.3f %9.2f %9.3f %10.2f %9.3f %9.3f %9.4f %9.4f %9.4f %9.4f %9.2f\n', ...
            res.t(k), res.theta(k) * deg, res.omega(k), res.alpha(k), res.ax(k), res.ay(k), ...
            res.Fx(k), res.Fy(k), res.Fnorme(k), res.Frequis(k), res.FS(k));
end

fprintf(fid, '\n%s\nFin du fichier.\n', trait);

% --- Fermer le fichier ----------------------------------------------------------------------------------------------------------------
fclose(fid);
reussi = true;

end
