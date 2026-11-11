function [theta, omega, alpha] = loiMouvement(nomLoi, t, T, theta0, theta1)
% LOIMOUVEMENT  Position, vitesse et accélération angulaires du bras pour une rotation.
%
%   [theta, omega, alpha] = loiMouvement(nomLoi, t, T, theta0, theta1)
%
%   ENTRÉES
%     nomLoi   nom de la loi : 'cubique', 'quintique' ou 'cycloidale'
%     t        temps écoulé depuis le début de la rotation [s]
%              (un nombre ou un vecteur de valeurs entre 0 et T)
%     T        durée totale de la rotation [s] (T > 0)
%     theta0   angle de départ [rad]
%     theta1   angle d'arrivée [rad]
%
%   SORTIES (même taille que t)
%     theta    position angulaire [rad]
%     omega    vitesse angulaire [rad/s]
%     alpha    accélération angulaire [rad/s^2]
%
%   PRINCIPE
%     La consigne demande d'IMPOSER au bras une loi de mouvement
%     analytique : on ne peut pas mesurer l'accélération dans la vidéo.
%     On utilise un temps « normalisé » tau = t/T qui va de 0 (départ) à
%     1 (arrivée), et une fonction s(tau) qui va elle aussi de 0 à 1 :
%
%         theta(t) = theta0 + (theta1 - theta0) * s(tau)
%
%     La vitesse et l'accélération s'obtiennent en dérivant cette
%     équation par rapport au temps (dérivation analytique). Comme
%     tau = t/T, chaque dérivée fait apparaître un facteur 1/T :
%
%         omega(t) = (theta1 - theta0) * s'(tau)  / T
%         alpha(t) = (theta1 - theta0) * s''(tau) / T^2
%
%     CONSÉQUENCE IMPORTANTE : pour une même loi, si on divise la durée T
%     par 2, l'accélération est multipliée par 4.
%
%   LES TROIS LOIS (s, s' et s'' en fonction de tau)
%     'cubique'     s   = 3*tau^2 - 2*tau^3
%                   s'  = 6*tau - 6*tau^2
%                   s'' = 6 - 12*tau
%                   Vitesse nulle au départ et à l'arrivée. L'accélération
%                   est maximale (6) dès le départ : elle « saute » de 0 à
%                   sa valeur maximale.
%     'quintique'   s   = 10*tau^3 - 15*tau^4 + 6*tau^5
%                   s'  = 30*tau^2 - 60*tau^3 + 30*tau^4
%                   s'' = 60*tau - 180*tau^2 + 120*tau^3
%                   Vitesse ET accélération nulles au départ et à l'arrivée.
%     'cycloidale'  s   = tau - sin(2*pi*tau)/(2*pi)
%                   s'  = 1 - cos(2*pi*tau)
%                   s'' = 2*pi*sin(2*pi*tau)
%                   Vitesse ET accélération nulles au départ et à l'arrivée.
%
%   SOURCES
%     'cubique'   : [Fourni] Craig (2022), Introduction to Robotics, chap. 7
%                   (polynômes cubiques, p. 225 à 237).
%     'quintique' et 'cycloidale' : [Claude] lois classiques ; une source
%                   reste à citer par l'équipe (par exemple un manuel de
%                   conception de mécanismes à cames).
%
%   LIMITE DU MODÈLE : un vérin pneumatique réel ne suit pas exactement
%   une loi analytique (il pousse à pression à peu près constante, puis
%   frappe ses butées). C'est une hypothèse à discuter dans le rapport.

% --- 1. Vérification de la durée -----------------------------------------
if ~(T > 0)
    error('RED:duree', 'La durée de la rotation T doit être plus grande que zéro.');
end

% --- 2. Temps normalisé (sans unité), entre 0 et 1 ------------------------
tau = t / T;

% --- 3. Fonction s(tau) et ses deux dérivées, selon la loi choisie --------
% Le point devant les opérateurs ( .^ ) veut dire « élément par élément » :
% si tau est un vecteur, le calcul est fait pour chacune de ses valeurs.
switch lower(nomLoi)

    case 'cubique'
        s   = 3*tau.^2 - 2*tau.^3;
        ds  = 6*tau - 6*tau.^2;
        dds = 6 - 12*tau;

    case 'quintique'
        s   = 10*tau.^3 - 15*tau.^4 + 6*tau.^5;
        ds  = 30*tau.^2 - 60*tau.^3 + 30*tau.^4;
        dds = 60*tau - 180*tau.^2 + 120*tau.^3;

    case 'cycloidale'
        s   = tau - sin(2*pi*tau) / (2*pi);
        ds  = 1 - cos(2*pi*tau);
        dds = 2*pi * sin(2*pi*tau);

    otherwise
        error('RED:loi', 'Loi de mouvement inconnue : %s', nomLoi);
end

% --- 4. Passage aux grandeurs réelles -------------------------------------
dTheta = theta1 - theta0;           % [rad] amplitude de la rotation

theta = theta0 + dTheta * s;        % [rad]
omega = dTheta * ds  / T;           % [rad/s]
alpha = dTheta * dds / T^2;         % [rad/s^2]

end
