function [valide, message] = validerEntrees(P, T, FScible)
% VALIDERENTREES  Vérifie les valeurs tapées par l'utilisateur AVANT tout calcul.
%
%   [valide, message] = validerEntrees(P, T, FScible)
%
%   ENTRÉES
%     P         structure des paramètres (voir parametres.m)
%     T         durée du transfert demandée [s]
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
%   REMARQUE : quand l'utilisateur tape du texte qui n'est pas un nombre
%   (par exemple « abc »), la conversion en nombre donne NaN (« Not a
%   Number »). On détecte ce cas avec la fonction isnan.

valide  = false;        % on suppose une erreur tant que tout n'est pas vérifié
message = '';

% --- 1. La durée du transfert T ---------------------------------------------
if ~isnumeric(T) || ~isscalar(T) || isnan(T)
    message = 'Durée du transfert invalide : entrer un nombre (exemple : 0.9).';
    return;
end
if isinf(T)
    message = 'Durée du transfert invalide : la valeur doit être finie.';
    return;
end
if T <= 0
    message = sprintf(['Durée du transfert invalide (%g s) : elle doit être ' ...
                       'plus grande que zéro.'], T);
    return;
end
if T > P.saisie.Tmax
    message = sprintf(['Durée du transfert hors limites (%g s) : la valeur ' ...
                       'maximale acceptée est %g s.'], T, P.saisie.Tmax);
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
