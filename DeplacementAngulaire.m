%% DeplacementAngulaire.m
% Ce programme calcule l'angle, la vitesse angulaire ainsi que 
% l'accélération angulaire selon le temps.
%
% Les paramètres d'entrées sont l'angle initiale, l'angle finale ainsi que
% le temps de fin du cycle en cours.


%% PARAMÈTRES UTILISÉS

%   ENTRÉES
%     t        temps écoulé depuis le début de la rotation [s]
%     temps_f  temps final du cycle [s]
%     theta_i  angle de départ [rad]
%     theta_f  angle d'arrivée [rad]
%
%   SORTIES (même taille que t)
%     theta    position angulaire [rad]
%     omega    vitesse angulaire [rad/s]
%     alpha    accélération angulaire [rad/s^2]

function [theta, omega, alpha] = DeplacementAngulaire(t, temps_f, theta_i, theta_f)
%% HYPOTHÈSES POUR LE PROGRAMME
% 1 - La vitesse angulaire initiale est nulle
% 2 - La vitesse angulaire finale est nulle
% 3 - On connait la position angulaire initiale et finale

% Avec ces hypothèses, la loi de mouvement décrivant le mieux la rotation
% du bras est la loi polynomiale cubique (Craig, p.227)

%% LOI POLYNOMIALE
%
% Par définition de la loi polynomiale cubique, l'angle est modèlisé ainsi
%       theta(t) = a0 + a1*(t) + a2*(t^2) + a3*(t^3)
%
% Par dérivation, on peut obtenir relations de vitesse et accélération
% angulaires suivantes :
%       omega(t) = a1 + 2*a2*(t) + 3*a3*(t^2)
%       alpha(t) = 2*a2 + 6*a3*(t)
%
% Selon les hypothèses posées, on obtient les relations suivantes:
%       theta(0) = theta_i          [rad]   Angle de départ
%       theta(temps_f) = theta_f    [rad]   Angle d'arrivée
%       omega(0) = 0                [rad/s] Vitesse initiale nulle
%       omega(temps_f) = 0          [rad/s] Vitesse finale nulle
%
% En remplaçant ces relations dans les fonctions décrites plus tôt on 
% obtient les fonctions résolues suivantes :

theta = theta_i + ((3*(theta_f-theta_i))/(temps_f^2))*(t.^2) - ((2*(theta_f-theta_i))/(temps_f^3))*(t.^3);  % [rad] 
omega = ((6*(theta_f-theta_i))/(temps_f^2))*(t) - ((6*(theta_f-theta_i))/(temps_f^3))*(t.^2);               % [rad/s]
alpha = ((6*(theta_f-theta_i))/(temps_f^2)) - ((12*(theta_f-theta_i))/(temps_f^3))*(t);                     % [rad/s^2] 
end

