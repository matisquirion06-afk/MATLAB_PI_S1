function majScene(hs, P, res, k)
% MAJSCENE  Met à jour l'animation : place les objets mobiles à l'instant numéro k.
%
%   majScene(hs, P, res, k)
%
%   ENTRÉES
%     hs    poignées des objets mobiles (sortie de creerScene.m)
%     P     structure des paramètres (voir parametres.m)
%     res   résultats d'un cycle (sortie de calculerCycle.m)
%     k     numéro du point de calcul à afficher (indice dans res.t)
%
%   PRINCIPE
%     Les objets existent déjà. On change seulement leurs coordonnées avec
%     la commande set(poignée, 'Propriété', valeur). C'est beaucoup plus
%     rapide que de tout redessiner, et c'est ce qui donne une animation
%     fluide et synchronisée avec les tracés.
%
%   OÙ EST LA PIÈCE ?
%     Étape 1 (attente à la prise)   posée sur le support de prise
%     Étape 2 (transfert)            collée sous la ventouse
%     Étapes 3 et 4                  posée sur le support de dépôt
%
%   LIMITE DE L'ANIMATION
%     L'animation montre le mouvement COMMANDÉ. Si le facteur de sécurité
%     passe sous 1, la pièce réelle se détacherait ; ici, elle reste dessinée
%     sous la ventouse, mais en rouge, avec la mention « PRISE PERDUE ».

mm = 1000;                              % facteur de conversion m -> mm

% --- 1. État du bras à cet instant ---------------------------------------------
theta = res.theta(k);                   % [rad] angle du bras
xA    = res.xAxe(k) * mm;               % [mm] axe de la poulie mobile
yA    = res.yAxe(k) * mm;
etape = res.etape(k);                   % numéro de l'étape (1 à 4)

% --- 2. Cotes utiles, en millimètres ---------------------------------------------
dLevre = P.dLevre * mm;                 % axe de la poulie -> lèvre de la ventouse
hV     = P.ventouse.hauteur * mm;       % hauteur de la ventouse
rV     = P.ventouse.diametre * mm / 2;  % rayon de la ventouse
D      = P.piece.D * mm;                % diamètre de la pièce
H      = P.piece.H * mm;                % hauteur de la pièce
yTable = -P.hPivot * mm;
r      = hs.rPoulie;                    % rayon dessiné des poulies

% --- 3. Le bras -------------------------------------------------------------------
set(hs.bras, 'XData', [0, xA], 'YData', [0, yA]);

% --- 4. La courroie : deux brins parallèles au bras -------------------------------
% (nx, ny) est un vecteur de longueur 1 perpendiculaire au bras. Chaque brin
% est décalé du rayon de la poulie, d'un côté ou de l'autre du bras.
nx = sin(theta);
ny = cos(theta);
set(hs.courroie1, 'XData', [0, xA] + r*nx, 'YData', [0, yA] + r*ny);
set(hs.courroie2, 'XData', [0, xA] - r*nx, 'YData', [0, yA] - r*ny);

% --- 5. La poulie mobile -----------------------------------------------------------
% Le cercle de la poulie est recentré sur l'axe (xA, yA).
set(hs.poulie, 'XData', xA + hs.cercleX, 'YData', yA + hs.cercleY);

% --- 6. La tige et la ventouse (toujours verticales grâce à la courroie) ----------
yLevre     = yA - dLevre;               % hauteur de la lèvre de la ventouse
yHautVent  = yLevre + hV;               % hauteur du dessus de la ventouse

set(hs.tige, 'XData', [xA, xA], 'YData', [yA, yHautVent]);

% Trapèze : étroit en haut (30 % du rayon), large en bas (le rayon complet)
set(hs.ventouse, ...
    'XData', xA + [-0.3*rV, 0.3*rV, rV, -rV], ...
    'YData', [yHautVent, yHautVent, yLevre, yLevre]);

% --- 7. La pièce -------------------------------------------------------------------
% (xP, yP) est le CENTRE de la pièce.
if etape == 3
    % Posée sur le support de prise
    xP = P.L * mm * cos(res.thetaPrise);
    yP = yTable + P.hAppuiPrise * mm + H/2;
elseif etape == 4
    % Tenue par la ventouse : son dessus touche la lèvre
    xP = xA;
    yP = yLevre - H/2;
else
    % Posée sur le support de dépôt (étapes 1 et 2)
    xP = P.L * mm * cos(res.thetaDepot);
    yP = yTable + P.hAppuiDepot * mm + H/2;
end

% Couleur de la pièce : celle du matériau. Exception : si la pièce est tenue
% et que le facteur de sécurité est inférieur à 1 à cet instant, la ventouse
% ne peut plus la retenir. On la dessine en ROUGE pour le signaler.
couleur     = P.materiaux(res.iMat).couleur;
prisePerdue = (etape == 4) && (res.FS(k) < 1);
if prisePerdue
    couleur = [0.90 0.10 0.10];
end

set(hs.piece, ...
    'XData', xP + [-1, 1, 1, -1] * D/2, ...
    'YData', yP + [-1, -1, 1, 1] * H/2, ...
    'FaceColor', couleur);

% --- 8. Le texte : temps et étape en cours ------------------------------------------
message = sprintf('t = %.2f s     %s', res.t(k), res.nomsEtapes{etape});
if prisePerdue
    message = [message '  -  PRISE PERDUE (FS < 1)'];
end
set(hs.texte, 'String', message);

end
