function nEchecs = testsRED()
% TESTSRED  Matrice de tests du programme RED : exécute tous les tests et affiche le tableau.
%
%   nEchecs = testsRED()
%
%   SORTIE
%     nEchecs   nombre de tests en échec (0 = tout est conforme)
%
%   POUR LANCER LES TESTS : taper  testsRED  dans la fenêtre de commande.
%
%   EXIGENCE DE LA CONSIGNE
%     La matrice de tests doit contenir « au minimum un cas nominal par
%     matériau, un cas limite et un cas d'entrée invalide », au format :
%         ID | Cas testé | Entrées | Résultat attendu | Résultat obtenu | Verdict
%     Le tableau affiché ici suit ce format. Il peut être copié dans le
%     document d'accompagnement (après vérification par l'équipe).
%
%   LES FAMILLES DE TESTS
%     N  cas nominaux        un par matériau, avec les valeurs de la vidéo
%     L  cas limites         durée minimale, bras immobile, mouvement très lent,
%                            couple insuffisant
%     I  entrées invalides   couple nul ou négatif, texte, FS inférieur à 1,
%                            durée imposée nulle, négative ou non numérique
%     C  cohérence physique  comportements attendus par la consigne
%     V  vérifications       lois de mouvement et calcul indépendant
%
%   [Claude] Depuis le 18 nov. 2026, l'entrée de l'interface est le couple de
%   l'actionneur. Les tests I1 à I3 portent sur le couple ; I6 à I8 sur la
%   durée du transfert, que l'utilisateur peut encore imposer (mode
%   « durée imposée »). Les tests L6 et C4 vérifient le lien entre le
%   couple et la durée.
%
%   COMMENT UN TEST EST ÉCRIT
%     Chaque test calcule une valeur « obtenue », la compare à ce qui est
%     « attendu », puis ajoute une ligne au tableau avec la fonction
%     locale ajouter (définie au bas de ce fichier).

P      = parametres();
T      = P.duree.transfert;             % durée nominale (vidéo)
FS     = P.FScible;                     % facteur de sécurité cible
nMat   = numel(P.materiaux);

tab = {};                               % le tableau des tests (vide au départ)

% =====================================================================================
%  N - CAS NOMINAUX : un par matériau
% =====================================================================================
% Attendu : le calcul se fait, l'effort maximal est au moins égal au poids
% et le FS minimal ne dépasse pas le FS bras immobile.
for i = 1:nMat
    res = calculerCycle(P, i, T);
    reussi = (res.FnormeMax >= res.poids) && (res.FSmin <= res.FSstatique) && (res.FSmin > 0);
    tab = ajouter(tab, sprintf('N%d', i), ...
        ['Cas nominal - ' res.nomMateriau], ...
        sprintf('T = %.2f s', T), ...
        'Effort max >= poids ; 0 < FS min <= FS immobile', ...
        sprintf('Effort max = %.3f N (poids %.3f N) ; FS min = %.2f (immobile %.2f)', ...
                res.FnormeMax, res.poids, res.FSmin, res.FSstatique), ...
        reussi);
end

% =====================================================================================
%  L - CAS LIMITES
% =====================================================================================
% On fait ces tests avec le matériau le plus dense (le cas le plus exigeant).
% [~, iDense] = max(...) donne le NUMÉRO du matériau qui a la plus grande masse volumique.
[~, iDense] = max([P.materiaux.rho]);
nomDense    = P.materiaux(iDense).nom;

% L1 : à la durée minimale, les DEUX contraintes doivent être respectées et
%      la contrainte annoncée comme active doit être atteinte exactement.
%      [Claude] Avant le 14 nov. 2026, ce test exigeait FS min = FS cible.
%      C'était juste tant que la ventouse était la seule contrainte. Depuis
%      que le couple de l'actionneur est pris en compte, la contrainte
%      active peut être l'une ou l'autre : le test vérifie maintenant la
%      bonne propriété, soit qu'aucune limite n'est dépassée et que celle
%      qui gouverne est serrée.
[Tmin, info] = dureeMinimale(P, iDense, FS);
if strcmp(info.statut, 'ok')
    res = calculerCycle(P, iDense, Tmin);

    % Aucune limite dépassée (petite tolérance pour l'arrondi numérique).
    FSok     = (res.FSmin    >= FS * 0.999);
    coupleOk = (res.coupleMax <= P.actionneur.couple * 1.001);

    % La contrainte annoncée active est-elle réellement atteinte ?
    switch info.limite
        case 'ventouse'
            ecart = 100 * abs(res.FSmin - FS) / FS;
        case 'couple'
            ecart = 100 * abs(res.coupleMax - P.actionneur.couple) / P.actionneur.couple;
        otherwise
            ecart = 0;      % limite de fréquence : rien à serrer
    end

    reussi = FSok && coupleOk && (ecart < 0.5);
    obtenu = sprintf(['T min = %.4f s ; limite %s serrée à %.3f %% ; ' ...
        'FS min = %.3f ; couple max = %.3f N.m'], ...
        Tmin, info.limite, ecart, res.FSmin, res.coupleMax);
else
    reussi = false;
    obtenu = ['Pas de solution : ' info.message];
end
tab = ajouter(tab, 'L1', ['Limite - transfert à la durée minimale (' nomDense ')'], ...
    sprintf('T = T min ; FS cible = %.2f ; couple max = %.2f N.m', FS, P.actionneur.couple), ...
    'FS >= cible ET couple <= limite ; contrainte active serrée (< 0,5 %)', obtenu, reussi);

% L5 : le retour à vide doit être PLUS RAPIDE que le transfert chargé.
%      [Claude] Test ajouté le 14 nov. 2026. C'est le symptôme qui a révélé
%      l'erreur : le retour affichait 0,817 s (valeur vidéo jamais
%      optimisée) contre 0,366 s pour le transfert, ce qui est
%      physiquement impossible à couple égal, le bras à vide ayant moins
%      d'inertie et moins de moment de gravité à vaincre.
[TretourMin, infoR] = dureeCouple(P, 0, P.thetaDepot, P.thetaPrise);
if strcmp(infoR.statut, 'ok')
    reussi = (TretourMin < Tmin);
    obtenu = sprintf('Retour à vide = %.4f s < transfert chargé = %.4f s', ...
                     TretourMin, Tmin);
else
    reussi = false;
    obtenu = ['Pas de solution : ' infoR.message];
end
tab = ajouter(tab, 'L5', 'Limite - le retour à vide est plus rapide que le transfert', ...
    sprintf('masse portée = 0 kg, puis %s ; couple max = %.2f N.m', nomDense, P.actionneur.couple), ...
    'Durée minimale du retour < durée minimale du transfert', obtenu, reussi);

% L2 : bras immobile, l'effort de la ventouse est égal au poids.
m  = massePiece(P, iDense);
E  = effortVentouse(m, P.g, 0, 0, P.materiaux(iDense).mu);
reussi = abs(E.Fnorme - m * P.g) < 1e-12 && abs(E.Frequis - m * P.g) < 1e-12;
tab = ajouter(tab, 'L2', ['Limite - bras immobile (' nomDense ')'], ...
    'ax = 0 ; ay = 0', 'Effort = poids = m x g', ...
    sprintf('Effort = %.6f N ; poids = %.6f N', E.Fnorme, m * P.g), reussi);

% L3 : mouvement très lent, le FS minimal tend vers le FS bras immobile.
res    = calculerCycle(P, iDense, 20);
ecart  = 100 * abs(res.FSmin - res.FSstatique) / res.FSstatique;
reussi = (ecart < 1);
tab = ajouter(tab, 'L3', ['Limite - transfert très lent (' nomDense ')'], ...
    'T = 20 s', 'FS min proche du FS immobile (écart < 1 %)', ...
    sprintf('FS min = %.3f ; FS immobile = %.3f (écart %.3f %%)', res.FSmin, res.FSstatique, ecart), ...
    reussi);

% L4 : géométrie impossible (support plus haut que ce que le bras peut atteindre).
try
    hauteurAxePoulie(P, 1.0);           % 1 m : valeur volontairement absurde
    reussi = false;                     % aucune erreur signalée : le test échoue
    obtenu = 'Aucune erreur signalée';
catch erreur
    reussi = true;
    obtenu = ['Erreur signalée : ' erreur.message];
end
tab = ajouter(tab, 'L4', 'Limite - géométrie impossible', ...
    'Hauteur d''appui à la prise = 1 m', 'Erreur signalée, aucun calcul', obtenu, reussi);

% L6 : couple trop faible pour soulever la pièce.
%      [Claude] Test ajouté le 18 nov. 2026, quand le couple est devenu
%      l'entrée de l'interface. Un couple positif (donc une saisie valide)
%      peut quand même être plus petit que le couple de gravité de la
%      pièce au pivot. Aucune durée ne convient alors : le programme doit
%      le dire, et non retourner une durée.
Pfaible = P;
Pfaible.actionneur.couple = 0.5;        % [N.m] sous le couple de gravité de l'acier
[Tfaible, infoFaible] = dureeMinimale(Pfaible, iDense, FS);
reussi = isnan(Tfaible) && strcmp(infoFaible.statut, 'impossible');
if reussi
    obtenu = ['Impossible : ' infoFaible.message];
else
    obtenu = sprintf('Durée retournée : %.4f s', Tfaible);
end
tab = ajouter(tab, 'L6', ['Limite - couple insuffisant pour soulever la pièce (' nomDense ')'], ...
    sprintf('couple = %.2f N.m ; FS cible = %.2f', Pfaible.actionneur.couple, FS), ...
    'Aucune durée possible, statut « impossible »', obtenu, reussi);

% =====================================================================================
%  I - ENTRÉES INVALIDES : elles doivent toutes être refusées
% =====================================================================================
Mcat = P.actionneur.coupleCatalogue;   % couple valide de référence
casInvalides = { ...
    'I1', 'Couple de l''actionneur nul',           0,    FS ; ...
    'I2', 'Couple de l''actionneur négatif',       -1,   FS ; ...
    'I3', 'Couple non numérique (texte « abc »)', NaN,  FS ; ...
    'I4', 'Facteur de sécurité inférieur à 1',    Mcat, 0.5 ; ...
    'I5', 'Facteur de sécurité non numérique',    Mcat, NaN };

for k = 1:size(casInvalides, 1)
    Mk  = casInvalides{k, 3};
    FSk = casInvalides{k, 4};
    [valide, message] = validerEntrees(P, Mk, FSk);
    if valide
        obtenu = 'Entrée acceptée';
    else
        obtenu = ['Refusée : ' message];
    end
    tab = ajouter(tab, casInvalides{k, 1}, ['Invalide - ' casInvalides{k, 2}], ...
        sprintf('couple = %g N.m ; FS cible = %g', Mk, FSk), ...
        'Entrée refusée avec un message', obtenu, ~valide);
end

% I6 à I8 : durée du transfert imposée par l'utilisateur (mode 3).
% C'est l'exemple même de la consigne : « durée de transfert nulle ou négative ».
casDurees = { ...
    'I6', 'Durée de transfert imposée nulle',            0 ; ...
    'I7', 'Durée de transfert imposée négative',         -0.5 ; ...
    'I8', 'Durée imposée non numérique (texte « abc »)', NaN };

for k = 1:size(casDurees, 1)
    Tk = casDurees{k, 3};
    [valide, message] = validerEntrees(P, Mcat, FS, Tk);
    if valide
        obtenu = 'Entrée acceptée';
    else
        obtenu = ['Refusée : ' message];
    end
    tab = ajouter(tab, casDurees{k, 1}, ['Invalide - ' casDurees{k, 2}], ...
        sprintf('T = %g s ; couple = %g N.m ; FS cible = %g', Tk, Mcat, FS), ...
        'Entrée refusée avec un message', obtenu, ~valide);
end

% =====================================================================================
%  C - COHÉRENCE PHYSIQUE (comportements attendus par la consigne)
% =====================================================================================
% On calcule les trois matériaux une fois pour toutes.
effortMax = zeros(1, nMat);
masses    = zeros(1, nMat);
dureesMin = zeros(1, nMat);
for i = 1:nMat
    res          = calculerCycle(P, i, T);
    effortMax(i) = res.FnormeMax;
    masses(i)    = res.masse;
    dureesMin(i) = dureeMinimale(P, i, FS);
end

% Ordre des matériaux du plus léger au plus lourd.
% [~, ordre] = sort(masses) donne les numéros des matériaux en ordre croissant de masse.
[~, ordre] = sort(masses);

% C1 : l'effort augmente avec la masse.
% diff calcule les différences entre valeurs voisines : toutes positives = ordre croissant.
reussi = all(diff(effortMax(ordre)) > 0);
tab = ajouter(tab, 'C1', 'Cohérence - l''effort augmente avec la masse', ...
    sprintf('T = %.2f s ; les %d matériaux', T, nMat), ...
    'Effort max croissant du plus léger au plus lourd', ...
    sprintf('%.3f N < %.3f N < %.3f N', effortMax(ordre)), reussi);

% C2 : l'effort augmente avec l'accélération (transfert deux fois plus court).
resLent   = calculerCycle(P, iDense, T);
resRapide = calculerCycle(P, iDense, T / 2);
reussi = (resRapide.FnormeMax > resLent.FnormeMax);
tab = ajouter(tab, 'C2', ['Cohérence - l''effort augmente avec l''accélération (' nomDense ')'], ...
    sprintf('T = %.2f s, puis T = %.2f s', T, T / 2), ...
    'Effort max plus grand quand T est plus court', ...
    sprintf('%.3f N (T) < %.3f N (T/2)', resLent.FnormeMax, resRapide.FnormeMax), reussi);

% C3 : la durée minimale est la plus longue pour le matériau le plus dense.
reussi = all(diff(dureesMin(ordre)) > 0);
tab = ajouter(tab, 'C3', 'Cohérence - durée minimale la plus longue pour le plus dense', ...
    sprintf('FS cible = %.2f ; les %d matériaux', FS, nMat), ...
    'T min croissant du plus léger au plus lourd', ...
    sprintf('%.4f s < %.4f s < %.4f s', dureesMin(ordre)), reussi);

% C4 : un couple plus grand donne une durée plus courte.
%      [Claude] Test ajouté le 18 nov. 2026. C'est le comportement de base
%      de la nouvelle architecture : le couple est la cause, la durée
%      l'effet. On compare deux couples pour lesquels c'est le couple, et
%      non la ventouse, qui limite le transfert de l'acier.
Pmoins = P;  Pmoins.actionneur.couple = 1.5;    % [N.m]
Pplus  = P;  Pplus.actionneur.couple  = 2.0;    % [N.m]
[Tmoins, ~] = dureeMinimale(Pmoins, iDense, FS);
[Tplus,  ~] = dureeMinimale(Pplus,  iDense, FS);
reussi = (Tplus < Tmoins);
tab = ajouter(tab, 'C4', ['Cohérence - un couple plus grand raccourcit la rotation (' nomDense ')'], ...
    sprintf('couple = %.1f N.m, puis %.1f N.m', Pmoins.actionneur.couple, Pplus.actionneur.couple), ...
    'T min plus court avec le plus grand couple', ...
    sprintf('%.4f s (%.1f N.m) > %.4f s (%.1f N.m)', Tmoins, Pmoins.actionneur.couple, ...
            Tplus, Pplus.actionneur.couple), reussi);


% =====================================================================================
%  AFFICHAGE DE LA MATRICE DE TESTS
% =====================================================================================
fprintf('\nMATRICE DE TESTS DU PROGRAMME RED\n\n');
fprintf('%-4s| %-58s| %-40s| %-48s| %-9s| %s\n', ...
        'ID', 'Cas testé', 'Entrées', 'Résultat attendu', 'Verdict', 'Résultat obtenu');
fprintf('%s\n', repmat('-', 1, 230));

nEchecs = 0;
for k = 1:size(tab, 1)
    if tab{k, 6}
        verdict = 'Conforme';
    else
        verdict = 'ÉCHEC';
        nEchecs = nEchecs + 1;
    end
    fprintf('%-4s| %-58s| %-40s| %-48s| %-9s| %s\n', ...
            tab{k, 1}, tab{k, 2}, tab{k, 3}, tab{k, 4}, verdict, tab{k, 5});
end

fprintf('\nBilan : %d test(s) sur %d conforme(s).\n\n', size(tab, 1) - nEchecs, size(tab, 1));

end


% =====================================================================================
function tab = ajouter(tab, id, cas, entrees, attendu, obtenu, reussi)
% AJOUTER  Ajoute une ligne à la matrice de tests.
%   Colonnes : ID | Cas testé | Entrées | Résultat attendu | Résultat obtenu | Réussi (vrai/faux)
tab(end+1, :) = {id, cas, entrees, attendu, obtenu, reussi};
end
