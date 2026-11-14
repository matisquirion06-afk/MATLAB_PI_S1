function hauteur = hauteurAxePoulie(P, hAppui)
% HAUTEURAXEPOULIE  Hauteur de l'axe de la poulie de ventouse au-dessus du pivot.
%
%   hauteur = hauteurAxePoulie(P, hAppui)
%
%   ENTREES
%     P        structure des parametres (au moins P.piece.H, P.dLevre,
%              P.hPivot et P.L doivent deja exister)
%     hAppui   hauteur de la surface ou repose la rondelle, mesuree a
%              partir de la table, jusqu'au DESSOUS de la rondelle [m]
%
%   SORTIE
%     hauteur  hauteur de l'axe de la poulie au-dessus du pivot [m]
%              (negative si l'axe est sous le pivot)
%
%   EQUATION
%     La levre de la ventouse se pose sur le DESSUS de la rondelle, et
%     l'axe de la poulie est d_levre plus haut que la levre :
%         y_axe = h_appui + H + d_levre - h_pivot
%
%   POURQUOI UNE FONCTION PLUTOT QUE DEUX LIGNES DANS parametres.m
%     Le test L4 de testsRED.m doit verifier que le programme refuse une
%     geometrie impossible. S'il recopiait la formule, il testerait sa
%     propre copie et non le code reellement utilise. En appelant cette
%     fonction, il teste le vrai chemin.

hauteur = hAppui + P.piece.H + P.dLevre - P.hPivot;

% Le bras ne peut pas atteindre une hauteur plus grande que sa longueur.
% Sans ce controle, asin() d'une valeur superieure a 1 retourne un nombre
% COMPLEXE sans aucun message, et tout le programme donne des resultats faux.
if abs(hauteur) > P.L
    error('RED:geometrie', ...
        ['Geometrie impossible : le bras (L = %.1f mm) ne peut pas atteindre ' ...
         'une hauteur de %.1f mm au-dessus du pivot.'], P.L * 1000, hauteur * 1000);
end

end
