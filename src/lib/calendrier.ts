/**
 * Calendrier des disponibilités : deux mois, semaine du lundi. Les nuits prises (séjours acceptés et blocages)
 * sont barrées, hachurées et portent une bande « LOUÉ » collée en travers, une bande par suite de nuits et par
 * semaine. On touche l'arrivée puis le départ ; une sélection qui enjambe une nuit prise est refusée.
 */
import type { Periode } from './sakan';

const JOURS = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
const MOIS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
export const iso = (d: Date) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const ajouter = (s: string, n: number) => { const [a, m, j] = s.split('-').map(Number); return iso(new Date(a, m - 1, j + n)); };

export type Choix = { debut: string | null; fin: string | null };

export function monterCalendrier(racine: HTMLElement, prises: Periode[], quandChange: (c: Choix) => void) {
  const auj = iso(new Date());
  const pris = new Set<string>();
  for (const p of prises) for (let d = p.debut; d < p.fin; d = ajouter(d, 1)) pris.add(d);
  let premier = new Date(); premier.setDate(1);
  const choix: Choix = { debut: null, fin: null };

  const libreEntre = (a: string, b: string) => { for (let d = a; d < b; d = ajouter(d, 1)) if (pris.has(d)) return false; return true; };

  function cliquer(d: string) {
    if (!choix.debut || choix.fin || d <= choix.debut) {
      if (pris.has(d)) return;                              // on n'arrive pas une nuit prise
      choix.debut = d; choix.fin = null;
    } else if (libreEntre(choix.debut, d)) {
      choix.fin = d;                                        // le jour du départ peut être une nuit prise : on part le matin
    } else {
      if (pris.has(d)) return;
      choix.debut = d; choix.fin = null;                    // la sélection enjambait une nuit prise : on recommence
    }
    rendre();
    quandChange({ ...choix });
  }

  function mois(debutMois: Date): HTMLElement {
    const sec = document.createElement('section');
    const an = debutMois.getFullYear(), m = debutMois.getMonth();
    const h = document.createElement('h3'); h.textContent = `${MOIS[m]} ${an}`;
    const grille = document.createElement('div'); grille.className = 'grille';
    grille.setAttribute('role', 'grid'); grille.setAttribute('aria-label', `${MOIS[m]} ${an}`);
    // chaque case est placée explicitement : les bandes « LOUÉ » se superposent sans pousser les jours
    const placer = (e: HTMLElement, i: number) => { e.style.gridRow = String(Math.floor(i / 7) + 2); e.style.gridColumn = String((i % 7) + 1); };
    JOURS.forEach((j, c) => { const e = document.createElement('span'); e.className = 'jsem'; e.textContent = j; e.setAttribute('aria-hidden', 'true'); e.style.gridRow = '1'; e.style.gridColumn = String(c + 1); grille.append(e); });
    const decalage = (debutMois.getDay() + 6) % 7;
    const nbJours = new Date(an, m + 1, 0).getDate();
    const cases: string[] = [];
    for (let i = 0; i < decalage; i++) { cases.push(''); }
    for (let j = 1; j <= nbJours; j++) {
      const d = iso(new Date(an, m, j));
      const b = document.createElement('button');
      b.type = 'button'; b.className = 'jour'; b.textContent = String(j);
      const passe = d < auj, estPris = pris.has(d);
      if (passe) b.classList.add('passe');
      if (estPris) b.classList.add('pris');
      if (d === auj) b.classList.add('aujourdhui');
      if (d === choix.debut || d === choix.fin) b.classList.add('choisi');
      if (choix.debut && choix.fin && d > choix.debut && d < choix.fin) b.classList.add('dans');
      const etat = estPris ? 'loué' : passe ? 'passé' : 'libre';
      b.setAttribute('aria-label', `${j} ${MOIS[m]} : ${etat}${d === choix.debut ? ', arrivée' : d === choix.fin ? ', départ' : ''}`);
      // une nuit prise reste cliquable comme jour de DÉPART (on part le matin même)
      const departPossible = estPris && choix.debut && !choix.fin && d > choix.debut && libreEntre(choix.debut, d);
      b.disabled = passe || (estPris && !departPossible);
      b.addEventListener('click', () => cliquer(d));
      placer(b, cases.length);
      grille.append(b); cases.push(d);
    }
    // les bandes « LOUÉ » : une par suite de nuits prises, découpée par semaine
    const ligne = (i: number) => Math.floor(i / 7) + 2;                 // +1 pour l'en-tête des jours, grille 1-indexée
    let i = 0;
    while (i < cases.length) {
      if (!cases[i] || !pris.has(cases[i])) { i++; continue; }
      let k = i;
      while (k + 1 < cases.length && cases[k + 1] && pris.has(cases[k + 1]) && ligne(k + 1) === ligne(i)) k++;
      const bande = document.createElement('span');
      bande.className = 'bande-jours'; bande.setAttribute('aria-hidden', 'true');
      bande.textContent = 'Loué';
      bande.style.gridRow = String(ligne(i));
      bande.style.gridColumn = `${(i % 7) + 1} / ${(k % 7) + 2}`;
      grille.append(bande);
      i = k + 1;
    }
    sec.append(h, grille);
    return sec;
  }

  function rendre() {
    const second = new Date(premier.getFullYear(), premier.getMonth() + 1, 1);
    const nav = document.createElement('div'); nav.className = 'mois-tete';
    const titre = document.createElement('p'); titre.className = 'sr'; titre.textContent = 'Disponibilités';
    const boutons = document.createElement('div'); boutons.className = 'mois-nav';
    const prec = document.createElement('button'); prec.type = 'button'; prec.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m15 18-6-6 6-6"/></svg>'; prec.setAttribute('aria-label', 'Mois précédent');
    const suiv = document.createElement('button'); suiv.type = 'button'; suiv.innerHTML = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m9 18 6-6-6-6"/></svg>'; suiv.setAttribute('aria-label', 'Mois suivant');
    const ceMois = new Date(); ceMois.setDate(1);
    prec.disabled = premier <= ceMois;
    prec.addEventListener('click', () => { premier = new Date(premier.getFullYear(), premier.getMonth() - 1, 1); rendre(); });
    suiv.addEventListener('click', () => { premier = new Date(premier.getFullYear(), premier.getMonth() + 1, 1); rendre(); });
    boutons.append(prec, suiv);
    const m1 = mois(premier), m2 = mois(second);
    const tete1 = document.createElement('div'); tete1.className = 'mois-tete';
    tete1.append(m1.querySelector('h3')!, boutons);
    m1.prepend(tete1);
    const tete2 = document.createElement('div'); tete2.className = 'mois-tete'; tete2.append(m2.querySelector('h3')!); m2.prepend(tete2);
    racine.replaceChildren(titre, m1, m2);
  }

  rendre();
  return {
    effacer() { choix.debut = null; choix.fin = null; rendre(); quandChange({ ...choix }); },
    marquerPris(p: Periode) { for (let d = p.debut; d < p.fin; d = ajouter(d, 1)) pris.add(d); rendre(); },
  };
}
