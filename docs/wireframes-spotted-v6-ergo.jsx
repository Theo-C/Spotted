import React, { useState, useMemo } from 'react';
import {
  ChevronLeft, ChevronRight, Camera, MapPin, Plus, Check, Compass,
  Map as MapIcon, User, Sparkles, Eye, Filter, Target, Flame,
  HelpCircle, LogOut, Bell, X,
  Trophy, Users, Calendar, Edit3, AlertTriangle, Search, ArrowUpDown,
  ChevronDown, ChevronUp, Crosshair, Layers, MoreHorizontal, Zap, RefreshCw,
} from 'lucide-react';

// =====================================================================
// Wireframes Spotted v6 — Améliorations ergonomiques
// =====================================================================
// Démontre les propositions d'amélioration vs v5 :
//   1. Home compactée (tip GPS en onboarding, fusion Niveau + Streak)
//   2. Liste espèces avec recherche + tri + signaux rareté simplifiés
//   3. Fiche espèce désencombrée (1 indicateur rareté, edit en menu …)
//   4. Saisie obs "photo-first" avec validation zone immédiate
//   5. Journal avec filtres collapsibles + clustering markers
//   6. Profil avec page badges dédiée + accès profil partenaire
// Chaque écran affiche un bandeau "💡 Δ v5" expliquant la modif.
// =====================================================================

// ========== TOKENS (centralisés — c'est aussi une amélioration) ==========
const T = {
  // surfaces
  base: '#F5EDDF', card: '#FAF6EC', muted: '#F0E8D2', divider: '#E8E0CE',
  // primaires
  forest: '#1F3D2E', forestLight: '#2D5A42',
  terracotta: '#B8624A', gold: '#C49120', goldLight: '#FFD66B',
  // texte
  textPrimary: '#2A1F15', textSecondary: '#6B5D4F', textMuted: '#A89B86',
  // raretés
  rCommon: '#7A7569', rRare: '#2D6E8C', rEpic: '#7A3D9A', rLegend: '#C49120',
  // espaces (tokens manquants dans theme.dart actuel)
  s2: 2, s4: 4, s8: 8, s12: 12, s16: 16, s24: 24,
  // radius
  rSm: 10, rMd: 14, rLg: 18, rXl: 24,
};

const RARITY = {
  commun:     { label: 'Commun',     color: T.rCommon, stars: 1, pts: 10 },
  rare:       { label: 'Rare',       color: T.rRare,   stars: 2, pts: 30 },
  epique:     { label: 'Épique',     color: T.rEpic,   stars: 3, pts: 100 },
  legendaire: { label: 'Légendaire', color: T.rLegend, stars: 4, pts: 300 },
};

const SPECIES = [
  { id: 1,  name: 'Buse variable',      sci: 'Buteo buteo',          cat: 'oiseaux',    rarity: 'commun',     observed: true,  lastObs: '12 mars', photo: true },
  { id: 2,  name: 'Faucon pèlerin',     sci: 'Falco peregrinus',     cat: 'oiseaux',    rarity: 'epique',     observed: false },
  { id: 3,  name: 'Balbuzard pêcheur',  sci: 'Pandion haliaetus',    cat: 'oiseaux',    rarity: 'legendaire', observed: false },
  { id: 4,  name: 'Chouette hulotte',   sci: 'Strix aluco',          cat: 'oiseaux',    rarity: 'commun',     observed: true,  lastObs: '4 avr.',  photo: false },
  { id: 5,  name: 'Chevêche d\'Athéna', sci: 'Athene noctua',        cat: 'oiseaux',    rarity: 'epique',     observed: false },
  { id: 6,  name: 'Martin-pêcheur',     sci: 'Alcedo atthis',        cat: 'oiseaux',    rarity: 'rare',       observed: true,  lastObs: '28 fév.', photo: true },
  { id: 7,  name: 'Huppe fasciée',      sci: 'Upupa epops',          cat: 'oiseaux',    rarity: 'epique',     observed: false },
  { id: 10, name: 'Chevreuil',          sci: 'Capreolus capreolus',  cat: 'mammiferes', rarity: 'commun',     observed: true,  lastObs: '15 mars', photo: true },
  { id: 11, name: 'Cerf élaphe',        sci: 'Cervus elaphus',       cat: 'mammiferes', rarity: 'rare',       observed: false },
  { id: 12, name: 'Renard roux',        sci: 'Vulpes vulpes',        cat: 'mammiferes', rarity: 'commun',     observed: true,  lastObs: '2 avr.',  photo: false },
  { id: 13, name: 'Loutre d\'Europe',   sci: 'Lutra lutra',          cat: 'mammiferes', rarity: 'legendaire', observed: false },
];

const TERRITORIES = [
  { code: '60', name: 'Oise',   tag: 'DOMICILE', observed: 8,  total: 71 },
  { code: '02', name: 'Aisne',  tag: 'VOISIN',   observed: 1,  total: 52 },
];

// =====================================================================
// PRIMITIVES — centralisées (vs v5 qui répétait les styles)
// =====================================================================
const Label = ({ children, color = T.textSecondary }) => (
  <span
    style={{ fontFamily: 'Karla, sans-serif', letterSpacing: '0.18em', color, fontWeight: 700, fontSize: 10 }}
  >{children.toUpperCase()}</span>
);

const Title = ({ children, size = 22, color = T.forest, italic = false }) => (
  <span style={{
    fontFamily: 'Cormorant Garamond, serif',
    fontSize: size, fontWeight: 600, color,
    fontStyle: italic ? 'italic' : 'normal', lineHeight: 1.05,
  }}>{children}</span>
);

const Body = ({ children, size = 13, color = T.textPrimary, weight = 400, italic = false }) => (
  <span style={{
    fontFamily: 'Karla, sans-serif',
    fontSize: size, color, fontWeight: weight,
    fontStyle: italic ? 'italic' : 'normal',
  }}>{children}</span>
);

// Bandeau "💡 Δ v5" en haut de chaque écran pour expliquer la modif.
const DeltaBanner = ({ children }) => (
  <div className="mx-3 my-2 px-3 py-2 rounded-lg border border-dashed"
    style={{ borderColor: T.gold, backgroundColor: '#FFF8E5' }}>
    <Body size={10} color={T.forest} italic weight={600}>💡 {children}</Body>
  </div>
);

const RarityDot = ({ rarity, size = 8 }) => {
  const r = RARITY[rarity];
  return <div style={{ width: size, height: size, borderRadius: size, backgroundColor: r.color }} />;
};

// Indicateur de rareté UNIQUE (une seule représentation par écran).
// Remplace les 4 indicateurs concurrents de v5 (badge + bordure + pill + étoiles).
const RarityPill = ({ rarity, withStars = false }) => {
  const r = RARITY[rarity];
  return (
    <div className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full"
      style={{ backgroundColor: r.color + '18', border: `1px solid ${r.color}55` }}>
      <RarityDot rarity={rarity} size={7} />
      <Body size={10} color={r.color} weight={700}>{r.label}</Body>
      {withStars && <Body size={9} color={r.color}>{'★'.repeat(r.stars)}</Body>}
    </div>
  );
};

const Progress = ({ value, max, color = T.forest, h = 6 }) => {
  const pct = Math.min(100, (value / max) * 100);
  return (
    <div className="w-full rounded-full overflow-hidden" style={{ height: h, backgroundColor: T.divider }}>
      <div className="h-full transition-all" style={{ width: pct + '%', backgroundColor: color, borderRadius: 999 }} />
    </div>
  );
};

const TouchBtn = ({ children, onClick, color = T.forest }) => (
  // Taille tactile 48×48 minimum (vs le 36×36 du + de v5 — sous la cible Material)
  <button onClick={onClick} className="rounded-full flex items-center justify-center shadow-md"
    style={{ width: 48, height: 48, backgroundColor: color, color: T.base }}>
    {children}
  </button>
);

const AppBar = ({ title, onBack, actions }) => (
  // AppBar standard (vs _BackButton custom dupliqué de v5)
  <div className="flex items-center px-2 h-12" style={{ backgroundColor: T.base }}>
    {onBack && (
      <button onClick={onBack} className="w-10 h-10 rounded-full flex items-center justify-center">
        <ChevronLeft size={22} color={T.forest} />
      </button>
    )}
    <div className="flex-1 px-1"><Title size={20}>{title}</Title></div>
    {actions}
  </div>
);

// =====================================================================
// SCREEN 1 — Home compactée
// =====================================================================
//   v5 : Header + tip GPS + Streak + Quêtes + Niveau + Territoires
//   v6 : Header + Header de progression (Niveau + Streak fusionnés) + Quêtes
//        + Territoires (itérés depuis BDD)
//        + Tip GPS migré en onboarding (visible 1× au login)
// =====================================================================
const HomeV6 = ({ onAdd, onTerritory }) => (
  <div className="h-full overflow-y-auto" style={{ backgroundColor: T.base }}>
    <DeltaBanner>
      Δ v5 : retrait du tip GPS (→ onboarding), fusion Niveau + Streak en un seul header,
      itération des territoires depuis la BDD (vs hard-codé '60'/'02').
    </DeltaBanner>

    {/* Header app */}
    <div className="px-5 pt-3 pb-2 flex items-center justify-between">
      <div>
        <Label color={T.terracotta}>Carnet naturaliste</Label>
        <div className="mt-0.5"><Title size={32} italic>Spotted</Title></div>
      </div>
      <TouchBtn onClick={onAdd}><Plus size={22} /></TouchBtn>
    </div>

    {/* Header de progression unifié — Niveau + Streak dans une seule carte */}
    <div className="mx-5 mt-3 rounded-2xl p-4 relative overflow-hidden"
      style={{ background: `linear-gradient(135deg, ${T.forest}, ${T.forestLight})` }}>
      <div className="flex items-center gap-3">
        {/* Pastille niveau */}
        <div className="w-12 h-12 rounded-full flex items-center justify-center"
          style={{ background: `linear-gradient(135deg, ${T.goldLight}, ${T.gold})` }}>
          <Title size={20} color={T.forest}>3</Title>
        </div>
        <div className="flex-1">
          <Label color="#C4A572">Niveau 3 · 420 / 900 pts</Label>
          <div className="mt-1.5"><Progress value={420} max={900} color={T.goldLight} h={5} /></div>
        </div>
        {/* Flamme streak intégrée à droite */}
        <div className="flex flex-col items-center gap-0.5 pl-3 border-l" style={{ borderColor: '#ffffff20' }}>
          <Flame size={22} color={T.terracotta} fill={T.terracotta} />
          <Body size={16} color={T.base} weight={700}>5j</Body>
          <Body size={9} color="#C4A572" weight={600}>×1.10</Body>
        </div>
      </div>
    </div>

    {/* Quêtes du jour — compactes */}
    <div className="mx-5 mt-3 rounded-2xl p-3" style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
      <div className="flex items-center justify-between mb-2">
        <Label>Quêtes du jour</Label>
        <Body size={11} color={T.forest} weight={700}>1 / 3</Body>
      </div>
      <QuestRow icon="🌿" name="Sortie du jour" pct={1.0} xp={20} state="claimed" />
      <QuestRow icon="📸" name="Coup d'œil photo" pct={0.0} xp={30} state="locked" />
      <QuestRow icon="🎯" name="Double trouvaille" pct={1.0} xp={40} state="claimable" />
    </div>

    {/* Territoires — itérés depuis liste */}
    <div className="px-5 mt-4 mb-2"><Label>Mes terrains</Label></div>
    <div className="space-y-3 px-5">
      {TERRITORIES.map(t => (
        <TerritoryCard key={t.code} t={t} onTap={() => onTerritory(t)} />
      ))}
    </div>

    <div className="h-20" />
  </div>
);

const QuestRow = ({ icon, name, pct, xp, state }) => {
  const claimed = state === 'claimed';
  const claimable = state === 'claimable';
  return (
    <div className="flex items-center gap-2 py-1.5">
      <span style={{ fontSize: 18, width: 22, textAlign: 'center' }}>{icon}</span>
      <div className="flex-1">
        <div className="flex items-center justify-between">
          <Body size={12} weight={600} color={claimed ? T.textMuted : T.textPrimary}>{name}</Body>
          <Body size={10} weight={700} color={claimed ? T.textMuted : T.gold}>+{xp} XP</Body>
        </div>
        <div className="mt-0.5"><Progress value={pct} max={1} color={claimable ? T.forest : T.terracotta} h={4} /></div>
      </div>
      {claimed && <Check size={18} color={T.forest} />}
      {claimable && (
        // Auto-validation en v6 idéale, mais on garde le bouton ici pour montrer
        // l'option (Théo pourra trancher)
        <button className="px-2 py-0.5 rounded-full" style={{ backgroundColor: T.forest }}>
          <Body size={9} color={T.base} weight={700}>VALIDER</Body>
        </button>
      )}
    </div>
  );
};

const TerritoryCard = ({ t, onTap }) => (
  <button onClick={onTap} className="w-full rounded-2xl overflow-hidden text-left"
    style={{ backgroundColor: T.card, border: `2px solid ${T.forest}` }}>
    <div className="h-20 relative" style={{ background: 'linear-gradient(180deg, #EFE7D2 0%, #D8CFAE 100%)' }}>
      <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full" style={{ backgroundColor: t.tag === 'DOMICILE' ? T.forest : T.terracotta }}>
        <Body size={9} color={T.base} weight={700}>{t.tag}</Body>
      </div>
      <Compass size={28} color={T.forest} style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', opacity: 0.3 }} />
    </div>
    <div className="p-3 flex items-center gap-3">
      <Title size={20}>{t.name} <Body size={13} italic color={T.terracotta}>({t.code})</Body></Title>
      <div className="flex-1" />
      <div className="flex items-center gap-2">
        <Body size={12} weight={700} color={T.forest}>{t.observed}</Body>
        <div style={{ width: 80 }}><Progress value={t.observed} max={t.total} color={T.terracotta} h={6} /></div>
        <Body size={12} color={T.textSecondary}>{t.total}</Body>
      </div>
      <ChevronRight size={18} color={T.forest} />
    </div>
  </button>
);

// =====================================================================
// SCREEN 2 — Liste espèces avec recherche + tri + UI simplifiée
// =====================================================================
const SpeciesListV6 = ({ onSpecies, onBack }) => {
  const [query, setQuery] = useState('');
  const [sort, setSort] = useState('rarity-desc');
  const [statusFilter, setStatusFilter] = useState('all'); // all | observed | mystery
  const [rarityFilter, setRarityFilter] = useState('all');
  const [showSortMenu, setShowSortMenu] = useState(false);

  const filtered = useMemo(() => {
    let arr = SPECIES.filter(s => s.cat === 'oiseaux');
    if (query) {
      const q = query.toLowerCase();
      arr = arr.filter(s => s.name.toLowerCase().includes(q) || s.sci.toLowerCase().includes(q));
    }
    if (statusFilter === 'observed') arr = arr.filter(s => s.observed);
    if (statusFilter === 'mystery') arr = arr.filter(s => !s.observed);
    if (rarityFilter !== 'all') arr = arr.filter(s => s.rarity === rarityFilter);
    if (sort === 'rarity-desc') {
      const order = { legendaire: 0, epique: 1, rare: 2, commun: 3 };
      arr.sort((a, b) => order[a.rarity] - order[b.rarity]);
    } else if (sort === 'unseen-first') {
      arr.sort((a, b) => (a.observed ? 1 : 0) - (b.observed ? 1 : 0));
    } else if (sort === 'name') {
      arr.sort((a, b) => a.name.localeCompare(b.name));
    }
    return arr;
  }, [query, sort, statusFilter, rarityFilter]);

  return (
    <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
      <AppBar title="Oiseaux" onBack={onBack} />
      <DeltaBanner>
        Δ v5 : champ de recherche + tri (rareté ↓ / non vues / nom), 1 seul indicateur
        de rareté (la pastille bordure), filtres en une seule rangée compacte.
      </DeltaBanner>

      {/* Recherche + tri */}
      <div className="px-4 pt-1 pb-2 flex items-center gap-2">
        <div className="flex-1 flex items-center gap-2 px-3 py-2 rounded-full"
          style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
          <Search size={16} color={T.textSecondary} />
          <input value={query} onChange={(e) => setQuery(e.target.value)}
            placeholder="Buse, faucon…"
            style={{ fontFamily: 'Karla, sans-serif', fontSize: 13, color: T.textPrimary, outline: 'none', border: 'none', background: 'transparent', flex: 1 }} />
          {query && <X size={14} color={T.textMuted} onClick={() => setQuery('')} className="cursor-pointer" />}
        </div>
        <button onClick={() => setShowSortMenu(!showSortMenu)}
          className="px-2.5 py-2 rounded-full flex items-center gap-1"
          style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
          <ArrowUpDown size={14} color={T.forest} />
          <ChevronDown size={12} color={T.forest} />
        </button>
      </div>
      {showSortMenu && (
        <div className="absolute right-4 top-32 z-10 rounded-xl py-1 shadow-lg"
          style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
          {[
            ['rarity-desc', 'Rareté ↓'],
            ['unseen-first', 'Non vues d\'abord'],
            ['name', 'Nom A→Z'],
          ].map(([k, l]) => (
            <button key={k} onClick={() => { setSort(k); setShowSortMenu(false); }}
              className="block w-full px-4 py-2 text-left flex items-center gap-2"
              style={{ backgroundColor: sort === k ? T.muted : 'transparent' }}>
              {sort === k ? <Check size={14} color={T.forest} /> : <span style={{ width: 14 }} />}
              <Body size={12}>{l}</Body>
            </button>
          ))}
        </div>
      )}

      {/* Filtres en UNE ligne (vs 2-3 rangées v5) */}
      <div className="px-4 pb-2 flex gap-1.5 overflow-x-auto">
        <FilterChip active={statusFilter === 'all'} onClick={() => setStatusFilter('all')}>Toutes</FilterChip>
        <FilterChip active={statusFilter === 'observed'} onClick={() => setStatusFilter('observed')}>
          <Check size={11} /> Vues
        </FilterChip>
        <FilterChip active={statusFilter === 'mystery'} onClick={() => setStatusFilter('mystery')}>
          <HelpCircle size={11} /> Mystères
        </FilterChip>
        <div className="w-px self-stretch" style={{ backgroundColor: T.divider }} />
        {Object.entries(RARITY).map(([k, r]) => (
          <FilterChip key={k} active={rarityFilter === k} onClick={() => setRarityFilter(rarityFilter === k ? 'all' : k)} color={r.color}>
            <RarityDot rarity={k} size={6} /> {r.label}
          </FilterChip>
        ))}
      </div>

      {/* Liste */}
      <div className="flex-1 overflow-y-auto px-4 pb-20 space-y-2">
        {filtered.map(s => (
          <SpeciesRow key={s.id} s={s} onTap={() => onSpecies(s)} />
        ))}
      </div>
    </div>
  );
};

const FilterChip = ({ children, active, onClick, color }) => (
  <button onClick={onClick} className="px-2.5 py-1 rounded-full flex items-center gap-1 whitespace-nowrap"
    style={{
      backgroundColor: active ? (color || T.forest) : T.card,
      color: active ? T.base : T.textSecondary,
      border: `1.5px solid ${active ? (color || T.forest) : T.divider}`,
      fontFamily: 'Karla, sans-serif', fontSize: 11, fontWeight: 600,
    }}>
    {children}
  </button>
);

// Ligne d'espèce : 1 seul indicateur rareté (la bordure colorée à gauche).
// vs v5 qui avait : badge rareté + bordure card + fond emoji + check rond + opacité.
const SpeciesRow = ({ s, onTap }) => {
  const r = RARITY[s.rarity];
  return (
    <button onClick={onTap} className="w-full flex items-stretch rounded-xl overflow-hidden text-left"
      style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
      {/* Barre verticale rareté = SEUL indicateur visuel */}
      <div style={{ width: 4, backgroundColor: r.color }} />
      <div className="flex-1 p-3 flex items-center gap-3">
        <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ backgroundColor: T.muted }}>
          <span style={{ fontSize: 18 }}>{s.observed ? '🦅' : '?'}</span>
        </div>
        <div className="flex-1 min-w-0">
          <Body size={14} weight={600}>{s.observed ? s.name : '???'}</Body>
          <div><Body size={11} italic color={T.textSecondary}>{s.observed ? s.sci : 'À débusquer'}</Body></div>
        </div>
        {s.observed ? (
          <div className="text-right">
            <Body size={10} color={T.textSecondary}>{s.lastObs}</Body>
            <div className="flex items-center gap-1 justify-end mt-0.5">
              {s.photo && <Camera size={11} color={T.gold} />}
              <Body size={11} weight={700} color={T.forest}>+{r.pts}</Body>
            </div>
          </div>
        ) : (
          <Body size={11} weight={700} color={r.color}>{r.label}</Body>
        )}
      </div>
    </button>
  );
};

// =====================================================================
// SCREEN 3 — Fiche espèce désencombrée
// =====================================================================
const SpeciesDetailV6 = ({ s, onBack, onReobs, onMenu }) => {
  const r = RARITY[s.rarity];
  return (
    <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
      <AppBar title="" onBack={onBack}
        actions={
          // Edit dans un menu ··· au lieu du bouton edit accessible à tous
          // → évite vandalisme entre Théo/Axelle sur les espèces du partenaire
          <button onClick={onMenu} className="w-10 h-10 rounded-full flex items-center justify-center">
            <MoreHorizontal size={20} color={T.forest} />
          </button>
        } />
      <DeltaBanner>
        Δ v5 : 1 seul indicateur rareté (pastille discrète, plus de badge + bordure + pill + étoiles).
        Edit accessible dans menu ··· (vs bouton flottant pour tous).
        Tuile "Bonus +50%" supprimée (info statique inline sous Points).
      </DeltaBanner>

      <div className="flex-1 overflow-y-auto pb-20">
        {/* Hero épuré : photo + nom + rareté */}
        <div className="relative h-44 mx-3 rounded-2xl overflow-hidden"
          style={{ background: `linear-gradient(135deg, ${r.color}30, ${r.color}10)` }}>
          <div className="absolute inset-0 flex items-center justify-center">
            <span style={{ fontSize: 80, opacity: 0.5 }}>🦅</span>
          </div>
          <div className="absolute bottom-2 left-3 right-3 flex items-end justify-between">
            <div>
              <Title size={26}>{s.name}</Title>
              <div><Body size={12} italic color={T.textSecondary}>{s.sci}</Body></div>
            </div>
            <RarityPill rarity={s.rarity} withStars />
          </div>
        </div>

        {/* Stats inline — 2 chiffres pertinents, pas 3 tuiles */}
        <div className="mx-3 mt-3 px-4 py-3 rounded-xl flex items-center justify-between"
          style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
          <div>
            <Title size={22} color={T.forest}>+{r.pts}</Title>
            <div><Body size={10} weight={700} color={T.textSecondary}>POINTS (×1.5 AVEC PHOTO)</Body></div>
          </div>
          <div className="text-right">
            <Title size={22} color={T.forest}>3</Title>
            <div><Body size={10} weight={700} color={T.textSecondary}>OBSERVATIONS</Body></div>
          </div>
        </div>

        {/* Description */}
        <div className="mx-3 mt-3 px-4 py-3 rounded-xl" style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
          <Body size={12} color={T.textPrimary}>
            Le rapace le plus visible en plaine. Posée sur piquet ou en vol plané. Plumage très variable.
          </Body>
        </div>

        {/* Tip "Pour la débusquer" */}
        <div className="mx-3 mt-3 px-4 py-3 rounded-xl"
          style={{ backgroundColor: T.gold + '10', border: `1px solid ${T.gold}55` }}>
          <Label color={T.gold}>Pour la débusquer</Label>
          <div className="mt-1">
            <Body size={12}>Cherchez les zones agricoles ouvertes, surtout en hiver — souvent perchée immobile sur un piquet.</Body>
          </div>
        </div>

        {/* Mes observations — liste compacte */}
        <div className="px-5 mt-4 mb-2"><Label>Mes observations · 3</Label></div>
        <div className="mx-3 rounded-xl overflow-hidden" style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
          {['12 mars · Forêt de Compiègne', '28 mars · Plaine de Senlis', '4 avr. · Bois de Senlis'].map((line, i, arr) => (
            <div key={i} className="flex items-center gap-3 px-3 py-2.5"
              style={{ borderBottom: i < arr.length - 1 ? `1px solid ${T.divider}` : 'none' }}>
              <MapPin size={14} color={T.terracotta} />
              <Body size={12} weight={500}>{line}</Body>
              <div className="flex-1" />
              {i < 2 && <Camera size={12} color={T.gold} />}
            </div>
          ))}
        </div>
      </div>

      {/* CTA "Je l'ai vue" — ton naturaliste, pas Duolingo */}
      <div className="absolute bottom-16 left-3 right-3">
        <button onClick={onReobs} className="w-full py-3 rounded-2xl shadow-lg flex items-center justify-center gap-2"
          style={{ backgroundColor: T.forest, color: T.base }}>
          <Eye size={18} />
          <Title size={18} color={T.base} italic>Je l'ai revue aujourd'hui</Title>
        </button>
      </div>
    </div>
  );
};

// =====================================================================
// SCREEN 4 — Nouvelle obs "photo-first"
// =====================================================================
//   v5 : photo → IA → date → mini-carte → espèce → submit (validation zone au submit)
//   v6 : photo → validation zone INSTANTANÉE (warning inline si hors-zone) →
//        espèce (auto-suggérée IA si activée) → submit
//        + Mode "ré-obs rapide" si on vient depuis fiche : 1 seul tap.
// =====================================================================
const NewObsV6 = ({ onCancel, onSubmit, prefillSpecies }) => {
  const [step, setStep] = useState(prefillSpecies ? 'quick' : 'photo');
  const [photoLoaded, setPhotoLoaded] = useState(false);
  const [zoneStatus, setZoneStatus] = useState(null); // null | 'ok' | 'out'

  if (step === 'quick') {
    // Mode ré-obs rapide depuis fiche espèce — 1 confirmation, c'est tout.
    return (
      <div className="h-full flex flex-col items-center justify-center p-6" style={{ backgroundColor: T.base }}>
        <DeltaBanner>
          Δ v5 : mode "ré-obs rapide" depuis fiche espèce — 1 tap pour valider une re-observation
          au lieu de remplir le formulaire complet.
        </DeltaBanner>
        <div className="text-center mt-8">
          <span style={{ fontSize: 64 }}>🦅</span>
          <div className="mt-3"><Title size={28}>{prefillSpecies.name}</Title></div>
          <div><Body italic color={T.textSecondary}>Buteo buteo · {RARITY[prefillSpecies.rarity].label}</Body></div>
          <div className="mt-6 px-4 py-2 rounded-full inline-flex items-center gap-2" style={{ backgroundColor: T.muted }}>
            <MapPin size={14} color={T.forest} />
            <Body size={12}>Forêt de Compiègne · maintenant</Body>
          </div>
        </div>
        <div className="mt-auto w-full space-y-2">
          <button className="w-full py-3 rounded-2xl flex items-center justify-center gap-2"
            style={{ backgroundColor: T.forest, color: T.base }}>
            <Zap size={18} />
            <Title size={16} color={T.base}>Valider · +2 pts</Title>
          </button>
          <button onClick={() => setStep('photo')} className="w-full py-2.5 rounded-2xl"
            style={{ border: `1.5px solid ${T.forest}` }}>
            <Body size={13} weight={600} color={T.forest}>Ajouter une photo · +1 pt bonus</Body>
          </button>
          <button onClick={onCancel} className="w-full py-2"><Body size={11} color={T.textMuted}>Annuler</Body></button>
        </div>
      </div>
    );
  }

  return (
    <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
      <AppBar title="Nouvelle observation" onBack={onCancel} />
      <DeltaBanner>
        Δ v5 : photo-first. Dès l'import, la zone est validée live (warning inline si hors-zone)
        au lieu d'un dialog brutal au moment du submit.
      </DeltaBanner>

      <div className="flex-1 overflow-y-auto px-4 pb-20">
        {/* Step indicator */}
        <div className="flex items-center gap-2 my-2">
          <StepDot active n={1} label="Photo" />
          <div className="flex-1 h-px" style={{ backgroundColor: T.divider }} />
          <StepDot active={!!photoLoaded} n={2} label="Espèce" />
          <div className="flex-1 h-px" style={{ backgroundColor: T.divider }} />
          <StepDot active={false} n={3} label="OK" />
        </div>

        {/* Photo slot — gros, central */}
        <button onClick={() => { setPhotoLoaded(true); setZoneStatus('out'); }}
          className="w-full rounded-2xl flex flex-col items-center justify-center mt-2"
          style={{
            height: 220, backgroundColor: photoLoaded ? T.muted : T.card,
            border: `2px dashed ${photoLoaded ? T.gold : T.divider}`,
          }}>
          {photoLoaded ? (
            <>
              <span style={{ fontSize: 56 }}>🌿</span>
              <Body size={11} italic color={T.textSecondary}>photo.jpg · 4032×3024 · EXIF GPS ✓</Body>
            </>
          ) : (
            <>
              <Camera size={32} color={T.textSecondary} />
              <div className="mt-2"><Body size={13} weight={600} color={T.textSecondary}>Importer une photo</Body></div>
              <div><Body size={10} italic color={T.textMuted}>la date et la position seront lues automatiquement</Body></div>
            </>
          )}
        </button>

        {photoLoaded && zoneStatus === 'out' && (
          // Warning IN-LINE et IMMÉDIAT après import — pas un dialog au submit
          <div className="mt-2 px-3 py-2.5 rounded-xl flex items-start gap-2"
            style={{ backgroundColor: '#FFF0E0', border: `1.5px solid ${T.terracotta}` }}>
            <AlertTriangle size={16} color={T.terracotta} />
            <div className="flex-1">
              <Body size={12} weight={700} color={T.terracotta}>Photo prise hors zone curée</Body>
              <div className="mt-0.5"><Body size={11} color={T.textPrimary}>
                Position : Beauvais (60). L'espèce sera ajoutée à ce territoire — choisis une rareté locale.
              </Body></div>
              <div className="mt-1.5 flex gap-1.5">
                {Object.entries(RARITY).map(([k, r]) => (
                  <button key={k} className="px-2 py-0.5 rounded-full flex items-center gap-1"
                    style={{ backgroundColor: r.color + '15', border: `1px solid ${r.color}` }}>
                    <RarityDot rarity={k} size={6} />
                    <Body size={9} weight={700} color={r.color}>{r.label}</Body>
                  </button>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Date + position lus automatiquement — affichés en lecture seule */}
        {photoLoaded && (
          <div className="mt-2 px-3 py-2 rounded-xl flex items-center gap-3"
            style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
            <Calendar size={14} color={T.forest} />
            <Body size={12}>12 mai 2026, 14:23</Body>
            <div className="w-px h-4" style={{ backgroundColor: T.divider }} />
            <MapPin size={14} color={T.forest} />
            <Body size={12}>49.43°N · 2.08°E</Body>
            <button className="ml-auto"><Edit3 size={14} color={T.textMuted} /></button>
          </div>
        )}

        {/* Espèce — apparaît seulement après photo, avec suggestion IA */}
        {photoLoaded && (
          <div className="mt-3">
            <Label>Espèce</Label>
            <div className="mt-1 flex items-center gap-2 px-3 py-2 rounded-xl"
              style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
              <Search size={14} color={T.textSecondary} />
              <Body size={12} color={T.textMuted}>Tape ou utilise l'IA…</Body>
              <button className="ml-auto flex items-center gap-1 px-2 py-1 rounded-full" style={{ backgroundColor: T.forest }}>
                <Sparkles size={12} color={T.goldLight} />
                <Body size={10} weight={700} color={T.base}>IA</Body>
              </button>
            </div>
          </div>
        )}
      </div>

      {/* CTA */}
      <div className="absolute bottom-16 left-3 right-3">
        <button onClick={onSubmit} className="w-full py-3 rounded-2xl shadow-lg"
          style={{ backgroundColor: photoLoaded ? T.forest : T.textMuted, color: T.base }}>
          <Title size={16} color={T.base} italic>Enregistrer l'observation</Title>
        </button>
      </div>
    </div>
  );
};

const StepDot = ({ n, label, active }) => (
  <div className="flex flex-col items-center">
    <div className="w-6 h-6 rounded-full flex items-center justify-center"
      style={{ backgroundColor: active ? T.forest : T.divider }}>
      <Body size={11} weight={700} color={active ? T.base : T.textMuted}>{n}</Body>
    </div>
    <Body size={9} color={active ? T.forest : T.textMuted} weight={600}>{label}</Body>
  </div>
);

// =====================================================================
// SCREEN 5 — Journal avec filtres collapsibles + clustering
// =====================================================================
const JournalV6 = ({ onBack }) => {
  const [filtersOpen, setFiltersOpen] = useState(false);
  return (
    <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
      <DeltaBanner>
        Δ v5 : filtres collapsibles (étaient toujours visibles, mangeaient ~110 px).
        Markers clustérisés + boutons "Recentrer toutes" et "Style".
      </DeltaBanner>

      {/* Carte avec contrôles flottants */}
      <div className="flex-1 relative" style={{ backgroundColor: '#D9D2BB' }}>
        {/* Markers cluster (un seul cercle) */}
        <div className="absolute" style={{ top: 100, left: 80 }}>
          <ClusterMarker count={12} />
        </div>
        <div className="absolute" style={{ top: 200, left: 220 }}>
          <SingleMarker rarity="rare" />
        </div>
        <div className="absolute" style={{ top: 280, left: 140 }}>
          <ClusterMarker count={4} />
        </div>
        <div className="absolute" style={{ top: 360, left: 260 }}>
          <SingleMarker rarity="legendaire" />
        </div>

        {/* Filtres collapsibles en haut */}
        <div className="absolute top-2 left-2 right-2">
          <button onClick={() => setFiltersOpen(!filtersOpen)}
            className="px-3 py-2 rounded-full flex items-center gap-2 shadow-md"
            style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
            <Filter size={14} color={T.forest} />
            <Body size={11} weight={700} color={T.forest}>Filtres</Body>
            <Body size={10} color={T.textSecondary}>· 38 obs</Body>
            <div className="flex-1" />
            {filtersOpen ? <ChevronUp size={14} color={T.forest} /> : <ChevronDown size={14} color={T.forest} />}
          </button>
          {filtersOpen && (
            <div className="mt-2 p-2 rounded-xl shadow-lg" style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
              <div className="flex gap-1 flex-wrap mb-1.5">
                {['🦅 Oiseaux', '🦌 Mamm.', '🦎 Rept.', '🦇 Chir.'].map(c => (
                  <FilterChip key={c} active={c.includes('Oiseaux')}>{c}</FilterChip>
                ))}
              </div>
              <div className="flex gap-1 flex-wrap mb-1.5">
                {Object.entries(RARITY).map(([k, r]) => (
                  <FilterChip key={k} active={false} color={r.color}>
                    <RarityDot rarity={k} size={6} /> {r.label}
                  </FilterChip>
                ))}
              </div>
              <div className="flex gap-1 flex-wrap">
                <FilterChip active><Users size={11} /> Théo</FilterChip>
                <FilterChip><Users size={11} /> Axelle</FilterChip>
              </div>
            </div>
          )}
        </div>

        {/* Boutons flottants : ma position, fit-bounds, style map */}
        <div className="absolute right-2 bottom-4 flex flex-col gap-2">
          <FloatBtn icon={<Crosshair size={18} color={T.forest} />} />
          <FloatBtn icon={<Target size={18} color={T.forest} />} label="Recentrer toutes" />
          <FloatBtn icon={<Layers size={18} color={T.forest} />} />
          <FloatBtn icon={<RefreshCw size={18} color={T.forest} />} />
        </div>
      </div>
    </div>
  );
};

const ClusterMarker = ({ count }) => (
  // Clustering — vs v5 qui superposait 100 cercles au même endroit
  <div className="rounded-full flex items-center justify-center shadow-lg"
    style={{
      width: 44, height: 44,
      background: `radial-gradient(circle, ${T.forest} 0%, ${T.forestLight} 100%)`,
      border: `3px solid ${T.base}`,
    }}>
    <Body size={13} color={T.base} weight={700}>{count}</Body>
  </div>
);

const SingleMarker = ({ rarity }) => {
  const r = RARITY[rarity];
  return (
    <div className="rounded-full shadow-lg"
      style={{ width: 22, height: 22, backgroundColor: r.color, border: `3px solid ${T.base}` }} />
  );
};

const FloatBtn = ({ icon, label }) => (
  <div className="flex items-center gap-1.5">
    {label && (
      <div className="px-2 py-1 rounded-full" style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
        <Body size={10} weight={600}>{label}</Body>
      </div>
    )}
    <button className="w-10 h-10 rounded-full shadow-md flex items-center justify-center"
      style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>{icon}</button>
  </div>
);

// =====================================================================
// SCREEN 6 — Profil v6 (avec route /badges dédiée + profil partenaire)
// =====================================================================
const ProfileV6 = ({ onBadges, onPartner, onAxelle }) => (
  <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
    <div className="px-4 pt-3"><Title size={22}>Profil</Title></div>
    <DeltaBanner>
      Δ v5 : badges → vraie route /badges (vs bottom sheet draggable).
      Accès au profil d'Axelle/Théo en haut (carnet partagé).
      Stats sur une ligne. Layout fixe propre (vs Spacer fragile).
    </DeltaBanner>

    <div className="flex-1 px-4 pb-20 overflow-y-auto">
      {/* Header niveau */}
      <div className="rounded-2xl p-4" style={{ background: `linear-gradient(135deg, ${T.forest}, ${T.forestLight})` }}>
        <div className="flex items-center gap-3">
          <div className="w-14 h-14 rounded-full flex items-center justify-center"
            style={{ background: `linear-gradient(135deg, ${T.goldLight}, ${T.gold})` }}>
            <Title size={22} color={T.forest}>3</Title>
          </div>
          <div className="flex-1">
            <Body size={9} weight={700} color="#C4A572" style={{ letterSpacing: '0.15em' }}>NIVEAU 3</Body>
            <div><Title size={24} color={T.base}>Théo</Title></div>
          </div>
        </div>
      </div>

      {/* Switcher Théo / Axelle — carnet partagé */}
      <div className="mt-3 rounded-xl flex p-0.5" style={{ backgroundColor: T.muted }}>
        <button onClick={onPartner}
          className="flex-1 py-1.5 rounded-lg flex items-center justify-center gap-1.5"
          style={{ backgroundColor: T.card }}>
          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: T.terracotta }} />
          <Body size={11} weight={700}>Théo</Body>
        </button>
        <button onClick={onAxelle}
          className="flex-1 py-1.5 rounded-lg flex items-center justify-center gap-1.5"
          style={{ opacity: 0.55 }}>
          <div className="w-3 h-3 rounded-full" style={{ backgroundColor: '#7A3D9A' }} />
          <Body size={11} weight={700}>Axelle</Body>
        </button>
      </div>

      {/* Stats inline */}
      <div className="mt-3 px-3 py-3 rounded-xl flex justify-around" style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
        {[
          { v: '12', l: 'ESPÈCES' },
          { v: '23', l: 'OBS' },
          { v: '8',  l: 'PHOTOS' },
          { v: '1',  l: 'LÉGEND.' },
        ].map((s, i, arr) => (
          <React.Fragment key={s.l}>
            <div className="text-center">
              <Title size={22} color={T.forest}>{s.v}</Title>
              <div><Body size={9} weight={700} color={T.textSecondary}>{s.l}</Body></div>
            </div>
            {i < arr.length - 1 && <div style={{ width: 1, height: 28, backgroundColor: T.divider }} />}
          </React.Fragment>
        ))}
      </div>

      {/* Badges → ouvre route /badges */}
      <button onClick={onBadges} className="w-full mt-3 px-3 py-3 rounded-xl flex items-center text-left"
        style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
        <div>
          <Label>Badges</Label>
          <div className="mt-0.5"><Title size={20}>5 / 13</Title></div>
        </div>
        <div className="ml-4 flex gap-1">
          {['🐣', '🎯', '⚡', '🔥', '📸'].map((e, i) => (
            <div key={i} className="w-7 h-7 rounded-full flex items-center justify-center"
              style={{ backgroundColor: T.muted, border: `1px solid ${T.gold}60` }}>
              <span style={{ fontSize: 14 }}>{e}</span>
            </div>
          ))}
        </div>
        <div className="flex-1" />
        <ChevronRight size={18} color={T.forest} />
      </button>

      {/* Réglages — section dédiée propre, pas de Spacer fragile */}
      <div className="mt-6">
        <Label>Réglages</Label>
        <div className="mt-2 rounded-xl overflow-hidden" style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
          <SettingRow icon={<Bell size={16} color={T.forest} />} title="Rappel quotidien" subtitle="Notification à 13:00" toggle />
          <div style={{ height: 1, backgroundColor: T.divider }} />
          <SettingRow icon={<LogOut size={16} color={T.terracotta} />} title="Se déconnecter" color={T.terracotta} />
        </div>
      </div>
    </div>
  </div>
);

const SettingRow = ({ icon, title, subtitle, toggle, color = T.textPrimary }) => (
  <div className="flex items-center gap-3 px-3 py-2.5">
    {icon}
    <div className="flex-1">
      <Body size={13} weight={600} color={color}>{title}</Body>
      {subtitle && <div><Body size={10} italic color={T.textSecondary}>{subtitle}</Body></div>}
    </div>
    {toggle ? (
      <div className="w-10 h-5 rounded-full p-0.5" style={{ backgroundColor: T.forest }}>
        <div className="w-4 h-4 rounded-full ml-auto" style={{ backgroundColor: T.base }} />
      </div>
    ) : (
      <ChevronRight size={14} color={T.textMuted} />
    )}
  </div>
);

// =====================================================================
// SCREEN 7 — Page Badges dédiée (vs bottom sheet de v5)
// =====================================================================
const BadgesV6 = ({ onBack }) => (
  <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
    <AppBar title="Badges" onBack={onBack} />
    <DeltaBanner>
      Δ v5 : vraie page (vs DraggableScrollableSheet). Back natif système, scroll naturel,
      partageable via deep link, mieux pour 20+ badges.
    </DeltaBanner>

    <div className="flex-1 overflow-y-auto px-4 pb-4">
      {/* Compteur global */}
      <div className="flex items-center gap-3 mb-3 px-3 py-2.5 rounded-xl"
        style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
        <Trophy size={20} color={T.gold} />
        <Body size={13} weight={600}>5 sur 13 badges débloqués</Body>
        <div className="flex-1" />
        <div style={{ width: 80 }}><Progress value={5} max={13} color={T.gold} h={6} /></div>
      </div>

      {/* Catégories */}
      {[
        { name: 'Premiers pas', items: [['🐣', 'Première observation', true], ['🎯', '10 espèces', true], ['📜', '25 espèces', false, 0.48], ['🐠', '50 espèces', false, 0.24]] },
        { name: 'Rareté',       items: [['⚡', 'Premier épique', true], ['🌟', 'Premier légendaire', false, 0], ['💫', 'Cinq légendaires', false, 0]] },
        { name: 'Photographe',  items: [['📸', 'Premières photos', false, 0.8], ['📷', 'Photographe', false, 0.16]] },
        { name: 'Série',        items: [['🔥', 'Une semaine', true], ['🦊', 'Pisteur du mois', false, 0.17], ['🏛', 'Centurion', false, 0.05], ['🎯', 'Année complète', false, 0]] },
      ].map(cat => (
        <div key={cat.name} className="mb-3">
          <div className="px-1 mb-1.5"><Title size={16}>{cat.name}</Title></div>
          <div className="grid grid-cols-3 gap-2">
            {cat.items.map(([icon, name, earned, pct]) => (
              <div key={name} className="p-2 rounded-xl flex flex-col items-center text-center"
                style={{
                  backgroundColor: earned ? T.card : T.muted,
                  border: `1.5px solid ${earned ? T.gold + '99' : T.divider}`,
                  opacity: earned ? 1 : 0.85,
                  boxShadow: earned ? `0 0 12px ${T.gold}20` : 'none',
                }}>
                <span style={{ fontSize: 26, opacity: earned ? 1 : 0.5 }}>{icon}</span>
                <div className="mt-1"><Body size={9} weight={700} color={earned ? T.forest : T.textSecondary}>{name}</Body></div>
                {earned ? (
                  <Check size={12} color={T.forest} style={{ marginTop: 3 }} />
                ) : (
                  <div className="w-full mt-1.5"><Progress value={pct} max={1} color={T.terracotta} h={3} /></div>
                )}
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  </div>
);

// =====================================================================
// SCREEN 8 — Onboarding (où le tip GPS de v5 vit maintenant)
// =====================================================================
const OnboardingV6 = ({ onDone }) => {
  const [step, setStep] = useState(0);
  const steps = [
    { icon: '👋', title: 'Bienvenue dans Spotted', body: 'Ton carnet naturaliste perso pour la Picardie. Photo + lieu = obs validée.' },
    { icon: '📷', title: 'Configure ton app caméra', body: 'Active "Enregistrer la localisation" dans Open Camera ou Google Camera. Sans ça, les EXIF GPS sont stripés et il faudra saisir le lieu à la main.' },
    { icon: '🔔', title: 'Rappel quotidien (optionnel)', body: 'Une notif à 13:00 pour entretenir ta série. Tu peux refuser et activer plus tard dans Profil.' },
  ];
  const s = steps[step];
  return (
    <div className="h-full flex flex-col p-6" style={{ backgroundColor: T.base }}>
      <DeltaBanner>
        Δ v5 : le tip "active la GPS caméra" est ici (vu 1× au 1er login),
        plus en banner permanent sur la Home.
      </DeltaBanner>
      <div className="flex-1 flex flex-col items-center justify-center text-center">
        <span style={{ fontSize: 80 }}>{s.icon}</span>
        <div className="mt-4"><Title size={24}>{s.title}</Title></div>
        <div className="mt-3 max-w-xs"><Body size={13} color={T.textSecondary}>{s.body}</Body></div>
      </div>
      <div className="flex justify-center gap-1.5 mb-4">
        {steps.map((_, i) => (
          <div key={i} className="rounded-full transition-all"
            style={{ width: i === step ? 20 : 6, height: 6, backgroundColor: i === step ? T.forest : T.divider }} />
        ))}
      </div>
      <button onClick={() => step < steps.length - 1 ? setStep(step + 1) : onDone()}
        className="w-full py-3 rounded-2xl shadow-md"
        style={{ backgroundColor: T.forest, color: T.base }}>
        <Title size={16} color={T.base}>{step < steps.length - 1 ? 'Suivant' : 'C\'est parti'}</Title>
      </button>
      {step < steps.length - 1 && (
        <button onClick={onDone} className="mt-2 py-2"><Body size={11} color={T.textMuted}>Passer</Body></button>
      )}
    </div>
  );
};

// =====================================================================
// BOTTOM NAV
// =====================================================================
const BottomNav = ({ tab, onChange }) => (
  <div className="absolute bottom-0 left-0 right-0 h-16 flex items-center justify-around"
    style={{ backgroundColor: T.card, borderTop: `1px solid ${T.divider}` }}>
    {[
      { id: 'home',    icon: Compass, label: 'Accueil' },
      { id: 'map',     icon: MapIcon, label: 'Carnet' },
      { id: 'profile', icon: User,    label: 'Profil' },
    ].map(t => {
      const Icon = t.icon;
      const active = tab === t.id;
      return (
        <button key={t.id} onClick={() => onChange(t.id)} className="flex flex-col items-center gap-0.5">
          <Icon size={20} color={active ? T.forest : T.textMuted} />
          <Body size={9} weight={700} color={active ? T.forest : T.textMuted}>{t.label}</Body>
        </button>
      );
    })}
  </div>
);

// =====================================================================
// APP SHELL
// =====================================================================
export default function WireframesV6() {
  const [view, setView] = useState({ name: 'home' });
  const [tab, setTab] = useState('home');

  let screen;
  switch (view.name) {
    case 'home':         screen = <HomeV6 onAdd={() => setView({ name: 'new-obs' })} onTerritory={() => setView({ name: 'species-list' })} />; break;
    case 'species-list': screen = <SpeciesListV6 onBack={() => setView({ name: 'home' })} onSpecies={(s) => setView({ name: 'species-detail', species: s })} />; break;
    case 'species-detail': screen = <SpeciesDetailV6 s={view.species} onBack={() => setView({ name: 'species-list' })} onReobs={() => setView({ name: 'new-obs', prefill: view.species })} onMenu={() => alert('Menu : Modifier · Supprimer')} />; break;
    case 'new-obs':      screen = <NewObsV6 onCancel={() => setView({ name: 'home' })} onSubmit={() => setView({ name: 'home' })} prefillSpecies={view.prefill} />; break;
    case 'journal':      screen = <JournalV6 onBack={() => setView({ name: 'home' })} />; break;
    case 'profile':      screen = <ProfileV6 onBadges={() => setView({ name: 'badges' })} onPartner={() => {}} onAxelle={() => alert('Bascule sur le profil d\'Axelle (lecture seule)')} />; break;
    case 'badges':       screen = <BadgesV6 onBack={() => setView({ name: 'profile' })} />; break;
    case 'onboarding':   screen = <OnboardingV6 onDone={() => setView({ name: 'home' })} />; break;
    default:             screen = <HomeV6 onAdd={() => setView({ name: 'new-obs' })} onTerritory={() => setView({ name: 'species-list' })} />;
  }

  const hideNav = ['new-obs', 'onboarding', 'species-detail', 'badges'].includes(view.name);
  const switchTab = (t) => {
    setTab(t);
    if (t === 'home') setView({ name: 'home' });
    if (t === 'map') setView({ name: 'journal' });
    if (t === 'profile') setView({ name: 'profile' });
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-6"
      style={{ background: `radial-gradient(circle at 50% 0%, ${T.forest} 0%, #0d1f17 100%)` }}>
      <div className="mb-6 text-center">
        <Body size={10} weight={700} color={T.goldLight}>WIREFRAMES V6 · AMÉLIORATIONS ERGONOMIQUES</Body>
        <div className="mt-1"><Title size={32} color={T.base} italic>Spotted</Title></div>
        <div className="mt-1"><Body size={11} italic color={T.goldLight}>Audit ergo intégré — banners 💡 expliquent les deltas vs v5</Body></div>
      </div>

      <div className="relative" style={{ width: 380, height: 760 }}>
        <div className="absolute inset-0 rounded-[44px] shadow-2xl p-3"
          style={{ background: 'linear-gradient(135deg, #1A1208, #2A1F15)' }}>
          <div className="w-full h-full rounded-[34px] overflow-hidden relative"
            style={{ backgroundColor: T.base }}>
            <div className="absolute top-0 left-0 right-0 h-7 flex items-center justify-between px-6 z-20 pointer-events-none">
              <Body size={11} weight={700} color={T.forest}>9:41</Body>
              <div className="flex items-center gap-1">
                <div className="flex gap-0.5">
                  {[1, 2, 3, 4].map(i => (
                    <div key={i} style={{ width: 3, height: i * 2 + 2, backgroundColor: i < 4 ? T.forest : T.forest + '40' }} />
                  ))}
                </div>
                <div className="w-6 h-2.5 rounded-sm border ml-1" style={{ borderColor: T.forest }}>
                  <div className="h-full" style={{ width: '70%', backgroundColor: T.forest, borderRadius: 1 }} />
                </div>
              </div>
            </div>
            <div className="absolute inset-0 pt-7" style={{ paddingBottom: hideNav ? 0 : 64 }}>{screen}</div>
            {!hideNav && <BottomNav tab={tab} onChange={switchTab} />}
          </div>
        </div>
      </div>

      {/* Navigation directe */}
      <div className="mt-6 flex flex-wrap gap-2 justify-center max-w-xl">
        {[
          ['🏠 Home',          () => { setView({ name: 'home' });          setTab('home'); }],
          ['🗒 Liste espèces', () => { setView({ name: 'species-list' });  setTab('home'); }],
          ['🦅 Fiche espèce', () => { setView({ name: 'species-detail', species: SPECIES[0] }); setTab('home'); }],
          ['📸 Nouvelle obs', () => { setView({ name: 'new-obs' });        setTab('home'); }],
          ['⚡ Ré-obs rapide', () => { setView({ name: 'new-obs', prefill: SPECIES[0] }); setTab('home'); }],
          ['🗺 Journal',      () => { setView({ name: 'journal' });        setTab('map'); }],
          ['👤 Profil',       () => { setView({ name: 'profile' });        setTab('profile'); }],
          ['🏆 Badges',       () => { setView({ name: 'badges' });         setTab('profile'); }],
          ['🚀 Onboarding',   () => { setView({ name: 'onboarding' });     setTab('home'); }],
        ].map(([label, action]) => (
          <button key={label} onClick={action}
            className="px-3 py-1.5 rounded-full text-xs transition-colors"
            style={{
              backgroundColor: T.card + '15', border: `1px solid ${T.gold}60`,
              color: T.goldLight, fontFamily: 'Karla, sans-serif', fontWeight: 600,
            }}>
            {label}
          </button>
        ))}
      </div>

      <p style={{ fontFamily: 'Karla, sans-serif' }}
        className="text-[10px] mt-3 italic text-center max-w-md"
        style={{ color: T.goldLight + 'BB' }}>
        💡 Top 5 démontré : <span style={{ fontWeight: 700, color: T.goldLight }}>Photo-first obs</span>,{' '}
        <span style={{ fontWeight: 700, color: T.goldLight }}>Search + tri liste</span>,{' '}
        <span style={{ fontWeight: 700, color: T.goldLight }}>Home compacte</span>,{' '}
        <span style={{ fontWeight: 700, color: T.goldLight }}>Design tokens</span>,{' '}
        <span style={{ fontWeight: 700, color: T.goldLight }}>1 indicateur rareté</span>
      </p>
    </div>
  );
}
