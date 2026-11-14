function E = effortVentouse(m, g, ax, ay, mu)
% EFFORTVENTOUSE  Effort que la ventouse doit exercer sur la pièce (2e loi de Newton).
%
%   E = effortVentouse(m, g, ax, ay, mu)
%
%   ENTRÉES
%     m    masse de la pièce [kg]
%     g    accélération gravitationnelle [m/s^2]
%     ax   accélération horizontale de la pièce [m/s^2]  (nombre ou vecteur)
%     ay   accélération verticale de la pièce [m/s^2]    (nombre ou vecteur)
%     mu   coefficient de frottement ventouse-pièce [-]
%
%   SORTIE : structure E contenant
%     E.Fx        composante horizontale de l'effort de la ventouse [N]
%     E.Fy        composante verticale de l'effort de la ventouse [N]
%     E.Fnorme    grandeur de l'effort total [N]
%     E.Frequis   force de maintien que le vide doit fournir [N]
%
%   ÉTAPE 1 - 2e LOI DE NEWTON APPLIQUÉE À LA PIÈCE
%     Deux forces agissent sur la pièce : son poids (vers le bas) et
%     l'effort de la ventouse F = (Fx, Fy).
%
%         somme des forces = m * accélération
%         en x :  Fx         = m * ax
%         en y :  Fy - m*g   = m * ay
%
%     Donc :
%         Fx = m * ax
%         Fy = m * (g + ay)
%         Fnorme = racine(Fx^2 + Fy^2)
%
%     VÉRIFICATION PHYSIQUE : si le bras est immobile (ax = ay = 0), on
%     obtient Fx = 0 et Fy = m*g : l'effort est égal au poids de la pièce.
%
%   ÉTAPE 2 - FORCE DE MAINTIEN REQUISE
%     La ventouse est posée SUR la pièce et reste verticale. Elle retient
%     la pièce de deux façons :
%       a) ARRACHEMENT (direction verticale) : le vide doit fournir au
%          moins Fy pour que la pièce ne décolle pas.
%       b) GLISSEMENT (direction horizontale) : Fx est transmis par
%          frottement. La force qui presse la pièce contre la lèvre vaut
%          N = F_vide - Fy, et le frottement maximal vaut mu*N.
%          Pas de glissement si |Fx| <= mu * (F_vide - Fy), c'est-à-dire :
%
%              F_vide >= Fy + |Fx| / mu
%
%     La force de maintien requise est donc :
%
%         Frequis = Fy + |Fx| / mu
%
%     Cette condition couvre aussi l'arrachement, car |Fx|/mu >= 0.
%
%   SOURCES
%     [Web] Schmalz, « Theoretical Holding Force of a Suction Cup » :
%       cas I  (ventouse horizontale, force verticale)   F = m*(g + a)*S
%       cas II (ventouse horizontale, force horizontale) F = m*(g + a/mu)*S
%     [Claude] L'équation ci-dessus combine ces deux cas, parce que notre
%     pièce a en même temps une accélération verticale (ay) et une
%     accélération horizontale (ax). Le facteur de sécurité S n'est pas
%     inclus ici : il est calculé à part dans facteurSecurite.m.
%     À valider par l'équipe.

% --- Étape 1 : 2e loi de Newton --------------------------------------------
E.Fx = m .* ax;                         % [N]
E.Fy = m .* (g + ay);                   % [N]
E.Fnorme = sqrt(E.Fx.^2 + E.Fy.^2);     % [N]

% --- Étape 2 : force de maintien requise ------------------------------------
E.Frequis = E.Fy + abs(E.Fx) ./ mu;     % [N]

% Si le résultat est négatif, la pièce est poussée CONTRE la ventouse
% (cela arrive quand la pièce « tombe » plus vite que la gravité, tout en
% haut d'une rotation très rapide). Aucune force de vide n'est alors
% nécessaire : on met 0 plutôt qu'une valeur négative.
E.Frequis(E.Frequis < 0) = 0;

end
