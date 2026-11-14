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
%     L  cas limites         durée minimale, bras immobile, mouvement très lent
%     I  entrées invalides   durée nulle ou négative, texte, FS inférieur à 1
%     C  cohérence physique  comportements attendus par la consigne
%     V  vérifications       lois de mouvement et calcul indépendant
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

% L1 : à la durée minimale, le FS minimal doit être égal à la cible.
[Tmin, info] = dureeMinimale(P, iDense, FS);
if strcmp(info.statut, 'ok')
    res    = calculerCycle(P, iDense, Tmin);
    ecart  = 100 * abs(res.FSmin - FS) / FS;
    reussi = (ecart < 0.5);
    obtenu = sprintf('T min = %.4f s ; FS min = %.4f (écart %.3f %%)', Tmin, res.FSmin, ecart);
else
    reussi = false;
    obtenu = ['Pas de solution : ' info.message];
end
tab = ajouter(tab, 'L1', ['Limite - transfert à la durée minimale (' nomDense ')'], ...
    sprintf('T = T min ; FS cible = %.2f', FS), ...
    'FS min = FS cible (écart < 0,5 %)', obtenu, reussi);

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
hFausse = 1.0;                          % [m] 1 metre : valeur volontairement absurde
hauteurFausse = hFausse + P.piece.H + P.dLevre - P.hPivot;
if abs(hauteurFausse) > P.L
    reussi = true;
    obtenu = sprintf(['Detecte : hauteur demandee %.0f mm > longueur du bras ' ...
                      '%.0f mm'], hauteurFausse * 1000, P.L * 1000);
else
    reussi = false;
    obtenu = 'Non detecte';
end
tab = ajouter(tab, 'L4', 'Limite - geometrie impossible', ...
    'Hauteur d''appui a la prise = 1 m', 'Geometrie refusee, aucun calcul', ...
    obtenu, reussi);

% =====================================================================================
%  I - ENTRÉES INVALIDES : elles doivent toutes être refusées
% =====================================================================================
casInvalides = { ...
    'I1', 'Durée de transfert nulle',            0,    FS ; ...
    'I2', 'Durée de transfert négative',         -0.5, FS ; ...
    'I3', 'Durée non numérique (texte « abc »)', NaN,  FS ; ...
    'I4', 'Facteur de sécurité inférieur à 1',   T,    0.5 ; ...
    'I5', 'Facteur de sécurité non numérique',   T,    NaN };

for k = 1:size(casInvalides, 1)
    Tk  = casInvalides{k, 3};
    FSk = casInvalides{k, 4};
    [valide, message] = validerEntrees(P, Tk, FSk);
    if valide
        obtenu = 'Entrée acceptée';
    else
        obtenu = ['Refusée : ' message];
    end
    tab = ajouter(tab, casInvalides{k, 1}, ['Invalide - ' casInvalides{k, 2}], ...
        sprintf('T = %g s ; FS cible = %g', Tk, FSk), ...
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
