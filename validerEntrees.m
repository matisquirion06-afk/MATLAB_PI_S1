function [valide, message] = validerEntrees(P, couple, FScible)
% VALIDERENTREES  Vérifie les valeurs tapées par l'utilisateur AVANT tout calcul.
%
%   [valide, message] = validerEntrees(P, couple, FScible)
%
%   ENTRÉES
%     P         structure des paramètres (voir parametres.m)
%     couple    couple de l'actionneur demandé [N.m]
%     FScible   facteur de sécurité cible demandé [-]
%
%   SORTIES
%     valide    true si les deux valeurs sont acceptables, false sinon
%     message   explication de l'erreur (texte vide si tout est correct)
%
%   EXIGENCE DE LA CONSIGNE
%     « L'interface doit signaler clairement toute entrée invalide ou hors
%     du domaine de validité (ex. : durée de transfert nulle ou négative,
%     facteur de sécurité inférieur à 1), plutôt que d'afficher un
%     résultat trompeur. »
%     Si cette fonction retourne valide = false, l'interface n'effectue
%     AUCUN calcul et affiche le message en rouge.
%
%   POURQUOI LE COUPLE ET NON LA DURÉE
%     [Claude] Depuis le 18 nov. 2026, la durée du transfert n'est plus
%     tapée par l'utilisateur : c'est un RÉSULTAT, calculé à partir du
%     couple de l'actionneur. L'exemple de la consigne (« durée nulle ou
%     négative ») devient donc « couple nul ou négatif » : c'est la même
%     vérification, appliquée à la nouvelle entrée.
%
%   CE QUE CETTE FONCTION NE VÉRIFIE PAS
%     Un couple positif peut quand même être trop faible pour soulever la
%     pièce. Ce n'est pas une ERREUR DE SAISIE mais un RÉSULTAT physique :
%     il dépend du matériau, et c'est dureeCouple.m qui le détecte.
%
%   REMARQUE : quand l'utilisateur tape du texte qui n'est pas un nombre
%   (par exemple « abc »), la conversion en nombre donne NaN (« Not a
%   Number »). On détecte ce cas avec la fonction isnan.

valide  = false;        % on suppose une erreur tant que tout n'est pas vérifié
message = '';

% --- 1. Le couple de l'actionneur ----------------------------------------------
if ~isnumeric(couple) || ~isscalar(couple) || isnan(couple)
    message = 'Couple de l''actionneur invalide : entrer un nombre (exemple : 2).';
    return;
end
if isinf(couple)
    message = 'Couple de l''actionneur invalide : la valeur doit être finie.';
    return;
end
if couple <= 0
    message = sprintf(['Couple de l''actionneur invalide (%g N.m) : il doit être ' ...
                       'plus grand que zéro.'], couple);
    return;
end
if couple > P.saisie.coupleMax
    message = sprintf(['Couple de l''actionneur hors limites (%g N.m) : la valeur ' ...
                       'maximale acceptée est %g N.m.'], couple, P.saisie.coupleMax);
    return;
end

% --- 2. Le facteur de sécurité cible ----------------------------------------
if ~isnumeric(FScible) || ~isscalar(FScible) || isnan(FScible)
    message = 'Facteur de sécurité invalide : entrer un nombre (exemple : 2).';
    return;
end
if FScible < 1
    % En dessous de 1, la force de maintien est plus petite que la force
    % requise : la pièce se détache.
    message = sprintf('Facteur de sécurité invalide (%g) : il doit être d''au moins 1.', ...
                      FScible);
    return;
end
if FScible > P.saisie.FSmax
    message = sprintf(['Facteur de sécurité hors limites (%g) : la valeur ' ...
                       'maximale acceptée est %g.'], FScible, P.saisie.FSmax);
    return;
end

% --- 3. Tout est correct -----------------------------------------------------
valide = true;

end
