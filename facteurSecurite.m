function FS = facteurSecurite(Fvide, Frequis)
% FACTEURSECURITE  Facteur de sécurité de la prise à chaque instant.
%
%   FS = facteurSecurite(Fvide, Frequis)
%
%   ENTRÉES
%     Fvide     force de maintien théorique de la ventouse [N] (forceMaintien.m)
%     Frequis   force de maintien requise [N] (effortVentouse.m)
%               (un nombre ou un vecteur : une valeur par instant)
%
%   SORTIE
%     FS        facteur de sécurité [-], même taille que Frequis
%
%   ÉQUATION
%     FS = Fvide / Frequis
%
%   GLISSEMENT OU ARRACHEMENT ?
%     Les deux. Frequis (effortVentouse.m) contient déjà le glissement :
%     Frequis = Fy + |Fx| / mu. Un seul FS couvre donc l'arrachement
%     vertical et le glissement horizontal. C'est un facteur de sécurité
%     au sens usuel : capacité divisée par demande.
%
%   COMMENT LIRE LE RÉSULTAT
%     FS > 1 : la ventouse peut fournir plus que la force requise.
%     FS = 1 : la prise est à sa limite théorique.
%     FS < 1 : la pièce se détache ou glisse.
%     On exige en pratique FS >= FS cible (par exemple 2), pour couvrir ce
%     que le modèle ne connaît pas : fuites, état de surface, chocs.
%
%   CAS PARTICULIER : si Frequis = 0 (la pièce est poussée contre la
%   ventouse), aucune force de vide n'est nécessaire. Le facteur de
%   sécurité est alors infini (Inf dans Matlab), et on évite une division
%   par zéro.

% On commence par un vecteur rempli de « infini », de la bonne taille.
FS = Inf(size(Frequis));

% positif est un vecteur de vrai/faux : vrai là où une force est requise.
positif = (Frequis > 0);

% On calcule le rapport seulement aux endroits où Frequis > 0.
FS(positif) = Fvide ./ Frequis(positif);

% Si Frequis contient des NaN (« pas une valeur » : instants où la pièce
% n'est pas tenue), on garde NaN pour que rien ne soit tracé à ces instants.
FS(isnan(Frequis)) = NaN;

end
