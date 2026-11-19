function [niveau, lignes] = verifierDomaine(P, res, FScible)
% VERIFIERDOMAINE  Juge les résultats : prise sûre ou non, domaine de validité respecté ou non.
%
%   [niveau, lignes] = verifierDomaine(P, res, FScible)
%
%   ENTRÉES
%     P         structure des paramètres (voir parametres.m)
%     res       résultats d'un cycle (sortie de calculerCycle.m)
%     FScible   facteur de sécurité cible [-]
%
%   SORTIES
%     niveau    'ok'             tout est correct               (affiché en vert)
%               'avertissement'  résultat hors du domaine de
%                                validité du modèle             (affiché en orange)
%               'alerte'         la prise n'est pas sûre        (affiché en rouge)
%     lignes    liste de phrases à afficher (tableau de cellules)
%
%   DIFFÉRENCE AVEC validerEntrees.m
%     validerEntrees refuse une ENTRÉE impossible (avant le calcul).
%     verifierDomaine commente un RÉSULTAT (après le calcul) : le calcul
%     est valable mathématiquement, mais il faut dire clairement s'il
%     décrit une situation sûre et réaliste.
%
%   VÉRIFICATIONS EFFECTUÉES
%     1. Prise : comparer FSmin à 1, puis à FScible.
%     2. Actionneur (si P.actionneur.verifier est vrai) :
%        a) durée T plus courte que ce que l'actionneur peut réaliser ;
%        b) couple requis au pivot plus grand que le couple de l'actionneur ;
%        c) couple choisi plus grand que celui du catalogue : le calcul
%           suppose alors un actionneur plus gros que le DSR-16 monté ;
%        d) énergie en fin de course au-delà de la limite Festo (sans
%           butées externes), pour le transfert ET pour le retour ;
%           rappel quand la durée Festo est extrapolée hors du graphique,
%           ou quand le vérin doit être étranglé (moins de 180°/s).
%
%   [Claude] Depuis que le couple est l'entrée de l'interface (18 nov. 2026),
%   les vérifications a) et b) ne devraient plus se déclencher en mode
%   « durée calculée » : la durée est justement choisie pour les respecter.
%   Elles restent en place comme garde-fou.

lignes = {};            % liste vide au départ ; on y ajoute des phrases
niveau = 'ok';

% --- 1. La prise ---------------------------------------------------------------
if res.FSmin < 1
    niveau = 'alerte';
    lignes{end+1} = sprintf(['PRISE PERDUE : FS minimal = %.2f (inférieur à 1). ' ...
                             'La pièce se détache à t = %.2f s.'], res.FSmin, res.tFSmin);
elseif res.FSmin < FScible
    niveau = 'alerte';
    lignes{end+1} = sprintf('PRISE NON SÛRE : FS minimal = %.2f, sous la cible de %.2f.', ...
                            res.FSmin, FScible);
else
    lignes{end+1} = sprintf('Prise sûre : FS minimal = %.2f (cible : %.2f).', ...
                            res.FSmin, FScible);
end

% --- 2. L'actionneur -------------------------------------------------------------
if P.actionneur.verifier

    % a) Durée plus courte que la capacité de l'actionneur
    if res.T < P.actionneur.dureeMin
        if strcmp(niveau, 'ok')
            niveau = 'avertissement';
        end
        lignes{end+1} = sprintf(['Hors domaine : T = %.3f s est plus court que la ' ...
            'rotation la plus rapide de l''actionneur (%.3f s).'], ...
            res.T, P.actionneur.dureeMin);
    end

    % b) Couple requis plus grand que le couple disponible
    if res.coupleMax > P.actionneur.couple
        if strcmp(niveau, 'ok')
            niveau = 'avertissement';
        end
        lignes{end+1} = sprintf(['Hors domaine : couple requis au pivot (%.2f N.m) ' ...
            'supérieur à celui de l''actionneur (%.2f N.m).'], ...
            res.coupleMax, P.actionneur.couple);
    end

    % c) Couple choisi au-delà du catalogue du DSR-16
    % La petite marge (1e-9) évite qu'un arrondi déclenche le message
    % quand le couple tapé vaut exactement la valeur du catalogue.
    if P.actionneur.couple > P.actionneur.coupleCatalogue + 1e-9
        if strcmp(niveau, 'ok')
            niveau = 'avertissement';
        end
        lignes{end+1} = sprintf(['Hors domaine : couple de %.2f N.m supérieur au ' ...
            'catalogue du DSR-16 (%.2f N.m à 6 bar). Le calcul suppose un ' ...
            'actionneur plus gros.'], P.actionneur.couple, P.actionneur.coupleCatalogue);
    end

    % d) Énergie en fin de course (fiche Festo DSR, p. 4 et 5)
    % [Claude] Ajouté le 19 nov. 2026. En mode « durées de la vidéo » ou
    % « transfert imposé », les durées peuvent être plus courtes que la
    % limite : le message dit alors de combien l'énergie la dépasse.
    if P.actionneur.festo.actif
        Emax  = P.actionneur.festo.energieMax;                               % [J]
        Etr   = energieFinCourse(P, res.masse, res.T,       P.thetaPrise, P.thetaDepot);
        Eret  = energieFinCourse(P, 0,         res.Tretour, P.thetaDepot, P.thetaPrise);
        marge = 1.001;          % tolérance pour l'arrondi des durées
        if Etr > marge * Emax || Eret > marge * Emax
            if strcmp(niveau, 'ok')
                niveau = 'avertissement';
            end
            lignes{end+1} = sprintf(['Hors limite Festo : énergie en fin de course = %.1f x ' ...
                'la limite (transfert), %.1f x (retour).'], Etr / Emax, Eret / Emax);
            lignes{end+1} = '   Butées externes ou amortisseurs requis (fiche DSR, p. 4).';
        else
            [~, infoF] = dureeFesto(P, res.masse, P.thetaPrise, P.thetaDepot);
            if infoF.extrapole
                lignes{end+1} = sprintf(['Limite Festo extrapolée : J = %.0fe-4 kg.m^2, au-delà du ' ...
                    'graphique (%.0fe-4).'], infoF.J * 1e4, P.actionneur.festo.Jgraphique * 1e4);
            end
            vitesse = abs(P.thetaDepot - P.thetaPrise) / res.T * 180 / pi;    % [deg/s]
            if vitesse < P.actionneur.festo.vitesseEtranglement
                lignes{end+1} = sprintf(['Vérin étranglé (%.0f deg/s < 180) : au moins 6 bar, ' ...
                    'temps à ±30 %% (fiche DSR, p. 4).'], vitesse);
            end
        end
    end
end

end
