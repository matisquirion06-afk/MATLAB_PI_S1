function [m, V] = massePiece(P, iMat)
% MASSEPIECE  Volume et masse de la rondelle pour un matériau donné.
%
%   [m, V] = massePiece(P, iMat)
%
%   ENTRÉES
%     P     structure des paramètres (voir parametres.m)
%     iMat  numéro du matériau (1 = Delrin, 2 = Aluminium, 3 = Acier)
%
%   SORTIES
%     m     masse de la pièce [kg]
%     V     volume de la pièce [m^3]
%
%   ÉQUATIONS
%     V = V_cylindre - (V_trou + V_cone)
%         V_cylindre = pi * (D/2)^2 * H         rondelle pleine
%         V_trou     = pi * (d/2)^2 * l         partie droite du trou
%         V_cone     = pi * (k/2)^2 * h / 3     zone conique du trou
%     m = rho * V
%
%   SOURCE DES ÉQUATIONS
%     [Fourni] Même formule que la feuille DONNÉES de « Rapport bras
%     rotatif.xlsx » (ligne « Volume rondelle minimal »).
%
%   REMARQUE : le volume ne dépend pas du matériau (volume constant imposé
%   par la consigne). Seule la masse volumique rho change.

% --- 1. Dimensions de la pièce (on leur donne des noms courts) -----------
D = P.piece.D;          % [m] diamètre extérieur
H = P.piece.H;          % [m] hauteur
l = P.piece.profTrou;   % [m] profondeur du trou
d = P.piece.diamTrou;   % [m] diamètre du trou
k = P.piece.diamCone;   % [m] diamètre de la zone conique
h = P.piece.profCone;   % [m] profondeur de la zone conique

% --- 2. Volume [m^3] ------------------------------------------------------
V_cylindre = pi * (D/2)^2 * H;
V_trou     = pi * (d/2)^2 * l;
V_cone     = pi * (k/2)^2 * h / 3;

V = V_cylindre - (V_trou + V_cone);

% --- 3. Masse [kg] = masse volumique [kg/m^3] x volume [m^3] --------------
rho = P.materiaux(iMat).rho;
m   = rho * V;

end
