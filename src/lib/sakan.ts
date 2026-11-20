/**
 * Sakan : accès à la base (PostgREST / Supabase) et à la connexion (Supabase Auth).
 * La page envoie des identifiants et des dates ; la base calcule le prix, vérifie les dates et décide.
 */
const API = (import.meta.env.PUBLIC_API_URL ?? 'http://localhost:54331').replace(/\/$/, '');
const CLE = import.meta.env.PUBLIC_API_KEY ?? '';
const AUTH = API.replace(/\/rest\/v1$/, '/auth/v1');
const CLE_SESSION = 'sakan:session';

export type Logement = {
  id: number; slug: string; titre: string; ville: string; quartier: string; lat: number; lng: number;
  description: string; capacite: number; chambres: number; prix_nuit: number; prix_semaine: number | null;
  prix_mois: number | null; sejour_min: number;
};
export type Periode = { debut: string; fin: string };
export type Devis = {
  total: number; nuits: number; mois: number; semaines: number; nuits_seules: number;
  prix_mois: number | null; prix_semaine: number | null; prix_nuit: number; sans_remise: number; libre: boolean;
};
export type Statut = 'en_attente' | 'acceptee' | 'refusee' | 'annulee';
export type Demande = {
  id: number; statut: Statut; debut: string; fin: string; nuits: number; personnes: number; prix_total: number;
  detail_prix: Devis; message: string; motif: string | null; cree_le: string; decide_le: string | null;
  logement: { id: number; slug: string; titre: string; ville: string; quartier: string };
  autre: { nom: string; telephone: string | null };
};
export type MonLogement = {
  id: number; slug: string; titre: string; ville: string; prix_nuit: number; en_attente: number;
  blocages: { id: number; debut: string; fin: string; raison: string }[];
};
export type Session = { access_token: string; refresh_token: string; expires_at: number; email: string };

export class ErreurSakan extends Error { constructor(public code: string) { super(code); } }

// ---------------------------------------------------------------- session
export function lireSession(): Session | null {
  try { const s = JSON.parse(localStorage.getItem(CLE_SESSION) ?? 'null'); return s?.access_token ? s : null; } catch { return null; }
}
function ecrire(s: Session | null) {
  try { s ? localStorage.setItem(CLE_SESSION, JSON.stringify(s)) : localStorage.removeItem(CLE_SESSION); } catch { /* privé */ }
}
async function auth(chemin: string, corps: object): Promise<Session> {
  let r: Response;
  try {
    r = await fetch(`${AUTH}/${chemin}`, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: CLE }, body: JSON.stringify(corps) });
  } catch { throw new ErreurSakan('reseau'); }
  const j = await r.json().catch(() => null);
  if (!r.ok || !j?.access_token) throw new ErreurSakan(r.status === 400 || r.status === 401 ? 'identifiants' : r.status === 429 ? 'trop_d_essais' : 'reseau');
  const s: Session = { access_token: j.access_token, refresh_token: j.refresh_token,
    expires_at: j.expires_at ?? Math.floor(Date.now() / 1000) + (j.expires_in ?? 3600), email: j.user?.email ?? '' };
  ecrire(s);
  return s;
}
export const connecter = (email: string, mdp: string) => auth('token?grant_type=password', { email: email.trim(), password: mdp });
export function deconnecter() {
  const s = lireSession(); ecrire(null);
  if (s) fetch(`${AUTH}/logout`, { method: 'POST', headers: { apikey: CLE, Authorization: `Bearer ${s.access_token}` } }).catch(() => {});
}
async function jeton(): Promise<string | null> {
  const s = lireSession();
  if (!s) return null;
  if (s.expires_at - 60 > Date.now() / 1000) return s.access_token;
  try { return (await auth('token?grant_type=refresh_token', { refresh_token: s.refresh_token })).access_token; }
  catch { ecrire(null); return null; }
}

// ---------------------------------------------------------------- appels
async function rpc<T>(fonction: string, corps: object = {}, connecte = false): Promise<T> {
  const h: Record<string, string> = { 'Content-Type': 'application/json' };
  if (CLE) h.apikey = CLE;
  const j = connecte ? await jeton() : null;
  if (connecte && !j) throw new ErreurSakan('non_connecte');
  h.Authorization = `Bearer ${j ?? CLE}`;
  if (!j && !CLE) delete h.Authorization;
  let r: Response;
  try { r = await fetch(`${API}/rpc/${fonction}`, { method: 'POST', headers: h, body: JSON.stringify(corps) }); }
  catch { throw new ErreurSakan('reseau'); }
  const x = await r.json().catch(() => null);
  if (r.status === 401) { ecrire(null); throw new ErreurSakan('non_connecte'); }
  if (!r.ok) throw new ErreurSakan(x?.code === 'P0001' && x?.message ? x.message : 'reseau');
  return x as T;
}

/** Catalogue, lu au moment de la construction (une page par logement). */
export async function logements(): Promise<Logement[]> {
  const h: Record<string, string> = CLE ? { apikey: CLE, Authorization: `Bearer ${CLE}` } : {};
  const r = await fetch(`${API}/logements?select=*&order=id`, { headers: h });
  if (!r.ok) throw new Error(`API ${r.status}`);
  return (await r.json()).map((l: Logement) => ({ ...l, lat: Number(l.lat), lng: Number(l.lng) }));
}
export const calendrier = (id: number) => rpc<Periode[]>('calendrier', { p_logement: id });
export const devis = (id: number, debut: string, fin: string) => rpc<Devis>('devis', { p_logement: id, p_debut: debut, p_fin: fin });
export const moi = () => rpc<{ role: 'proprietaire' | 'locataire'; nom: string }>('moi', {}, true);
export const demander = (id: number, debut: string, fin: string, personnes: number, message: string) =>
  rpc<Demande>('demander', { p_logement: id, p_debut: debut, p_fin: fin, p_personnes: personnes, p_message: message }, true);
export const mesDemandes = () => rpc<Demande[]>('mes_demandes', {}, true);
export const annuler = (id: number) => rpc<Demande>('annuler', { p_demande: id }, true);
export const demandesRecues = () => rpc<Demande[]>('demandes_recues', { p_statut: null }, true);
export const accepter = (id: number) => rpc<Demande & { refusees_d_office: number }>('accepter', { p_demande: id }, true);
export const refuser = (id: number, motif: string) => rpc<Demande>('refuser', { p_demande: id, p_motif: motif }, true);
export const mesLogements = () => rpc<MonLogement[]>('mes_logements', {}, true);
export const bloquer = (id: number, debut: string, fin: string, raison: string) =>
  rpc<{ id: number }>('bloquer', { p_logement: id, p_debut: debut, p_fin: fin, p_raison: raison }, true);
export const debloquer = (id: number) => rpc<null>('debloquer', { p_blocage: id }, true);

// ---------------------------------------------------------------- textes
export const ERREURS: Record<string, string> = {
  reseau: 'La base ne répond pas. Vérifiez la connexion et réessayez.',
  identifiants: 'E-mail ou mot de passe incorrect.',
  trop_d_essais: 'Trop d’essais : attendez une minute.',
  non_connecte: 'Connectez-vous pour continuer.',
  acces_refuse: 'Ce compte n’a pas de profil sur Sakan.',
  dates_invalides: 'Choisissez une date d’arrivée puis une date de départ.',
  date_passee: 'La date d’arrivée est déjà passée.',
  sejour_trop_long: 'Un séjour dure un an au plus.',
  sejour_trop_court: 'Ce logement se loue pour un séjour plus long.',
  trop_de_personnes: 'Trop de personnes pour ce logement.',
  message_trop_long: 'Message trop long (500 caractères au plus).',
  dates_indisponibles: 'Ces dates ne sont plus libres : quelqu’un vient de les prendre ou le propriétaire les a bloquées.',
  demande_deja_envoyee: 'Vous avez déjà une demande en attente sur ces dates.',
  reserve_aux_locataires: 'Seul un compte locataire peut demander des dates.',
  reserve_aux_proprietaires: 'Réservé aux propriétaires.',
  demande_introuvable: 'Demande introuvable.',
  deja_close: 'Cette demande a déjà reçu une réponse.',
  sejour_commence: 'Le séjour a commencé : il ne peut plus être annulé ici.',
  motif_requis: 'Indiquez un motif (3 caractères au moins).',
  motif_trop_long: 'Motif trop long (200 caractères au plus).',
  logement_introuvable: 'Logement introuvable.',
  blocage_introuvable: 'Blocage introuvable.',
};
export const message = (e: unknown) => ERREURS[e instanceof ErreurSakan ? e.code : 'reseau'] ?? ERREURS.reseau;

export const dh = (n: number) => `${new Intl.NumberFormat('fr-FR').format(n)} DH`;
const MOIS = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
export function jour(iso: string): string {
  const [a, m, j] = iso.split('-').map(Number);
  return `${j} ${MOIS[m - 1]}${a !== new Date().getFullYear() ? ` ${a}` : ''}`;
}
export const STATUTS: Record<Statut, string> = { en_attente: 'En attente', acceptee: 'Acceptée', refusee: 'Refusée', annulee: 'Annulée' };
/** Décomposition lisible du prix calculé par la base. */
export function detailPrix(d: Devis): string[] {
  const l: string[] = [];
  if (d.mois) l.push(`${d.mois} mois × ${dh(d.prix_mois!)}`);
  if (d.semaines) l.push(`${d.semaines} semaine${d.semaines > 1 ? 's' : ''} × ${dh(d.prix_semaine!)}`);
  if (d.nuits_seules) l.push(`${d.nuits_seules} nuit${d.nuits_seules > 1 ? 's' : ''} × ${dh(d.prix_nuit)}`);
  return l;
}
