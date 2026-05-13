import React, { useState } from 'react';
import {
  Compass, Map as MapIcon, User, BookOpen, Search, Filter, ChevronRight,
  ChevronLeft, Plus, MapPin, Trees, Target, Award, Settings,
} from 'lucide-react';

// =====================================================================
// Wireframes — refonte d'architecture d'information
// =====================================================================
// Suite à la discussion : la home actuelle mélange 3 jobs (gamification,
// exploration territoriale, accueil). Le territoire en tant que niveau
// de navigation est peut-être obsolète.
//
// 3 architectures comparées :
// A. Statu quo nettoyé (3 tabs Explorer/Carnet/Profil)
// B. Aplati — territoire = filtre, pas un écran (3 tabs Espèces/Carnet/Profil)
// C. Hybride — comme B mais "Mes zones" en section du Profil
// =====================================================================

const T = {
  base: '#F5EDDF', card: '#FAF6EC', muted: '#F0E8D2', divider: '#E8E0CE',
  forest: '#1F3D2E', forestLight: '#2D5A42',
  terracotta: '#B8624A', gold: '#C49120', goldLight: '#FFD66B',
  textPrimary: '#2A1F15', textSecondary: '#6B5D4F', textMuted: '#A89B86',
  rCommon: '#7A7569', rRare: '#2D6E8C', rEpic: '#7A3D9A', rLegend: '#C49120',
};

const RARITY = {
  commun: T.rCommon, rare: T.rRare, epique: T.rEpic, legendaire: T.rLegend,
};

const SPECIES = [
  { id: 1, name: 'Faucon pèlerin', sci: 'Falco peregrinus', cat: '🦅', rarity: 'epique', zone: 'Oise', observed: false },
  { id: 2, name: 'Martin-pêcheur', sci: 'Alcedo atthis', cat: '🦅', rarity: 'rare', zone: 'Oise', observed: true, lastObs: '28 fév.', photo: true },
  { id: 3, name: 'Balbuzard pêcheur', sci: 'Pandion haliaetus', cat: '🦅', rarity: 'legendaire', zone: 'Oise', observed: false },
  { id: 4, name: 'Chevreuil', sci: 'Capreolus capreolus', cat: '🦌', rarity: 'commun', zone: 'Oise', observed: true, lastObs: '15 mars', photo: true },
  { id: 5, name: 'Renard roux', sci: 'Vulpes vulpes', cat: '🦊', rarity: 'commun', zone: 'Aisne', observed: true, lastObs: '2 avr.' },
  { id: 6, name: 'Loutre d\'Europe', sci: 'Lutra lutra', cat: '🦦', rarity: 'legendaire', zone: 'Aisne', observed: false },
  { id: 7, name: 'Huppe fasciée', sci: 'Upupa epops', cat: '🦅', rarity: 'epique', zone: 'Oise', observed: false },
  { id: 8, name: 'Buse variable', sci: 'Buteo buteo', cat: '🦅', rarity: 'commun', zone: 'Oise', observed: true, lastObs: '12 mars', photo: true },
];

const TERRITORIES = [
  { code: '60', name: 'Oise', tag: 'DOMICILE', tagColor: T.forest, observed: 8, total: 71 },
  { code: '02', name: 'Aisne', tag: 'VOISIN', tagColor: T.terracotta, observed: 1, total: 52 },
];

// =====================================================================
// PRIMITIVES
// =====================================================================
const Label = ({ children, color = T.textSecondary, size = 10, ls = 2.5 }) => (
  <span style={{
    fontFamily: 'Karla, sans-serif',
    fontSize: size, letterSpacing: `${ls / 10}em`,
    fontWeight: 700, color,
  }}>{children.toString().toUpperCase()}</span>
);

const Title = ({ children, size = 22, color = T.forest, italic = false }) => (
  <span style={{
    fontFamily: 'Cormorant Garamond, serif',
    fontSize: size, fontWeight: 600, color,
    fontStyle: italic ? 'italic' : 'normal', lineHeight: 1.1,
  }}>{children}</span>
);

const Body = ({ children, size = 13, color = T.textPrimary, weight = 400, italic = false }) => (
  <span style={{
    fontFamily: 'Karla, sans-serif',
    fontSize: size, color, fontWeight: weight,
    fontStyle: italic ? 'italic' : 'normal',
  }}>{children}</span>
);

const Progress = ({ value, max, color = T.terracotta, h = 5 }) => {
  const pct = max === 0 ? 0 : Math.min(100, (value / max) * 100);
  return (
    <div className="w-full rounded-full overflow-hidden" style={{ height: h, backgroundColor: T.divider }}>
      <div className="h-full" style={{ width: pct + '%', backgroundColor: color, borderRadius: 999 }} />
    </div>
  );
};

const TerritoryBadge = ({ code, size = 32 }) => (
  <div className="flex items-center justify-center rounded-lg"
    style={{
      width: size, height: size,
      background: `linear-gradient(135deg, ${T.forest}, ${T.forestLight})`,
    }}>
    <span style={{
      fontFamily: 'Cormorant Garamond, serif',
      fontSize: code.length >= 3 ? size * 0.36 : size * 0.46,
      fontWeight: 700, color: T.goldLight,
    }}>{code}</span>
  </div>
);

// Phone frame réutilisable
const PhoneFrame = ({ children, label }) => (
  <div className="flex flex-col items-center">
    <div className="mb-2"><Label color={T.goldLight} ls={2}>{label}</Label></div>
    <div style={{ width: 320, height: 660 }} className="relative rounded-[36px] shadow-2xl"
      >
      <div className="absolute inset-0 rounded-[36px] p-2"
        style={{ background: 'linear-gradient(135deg, #1A1208, #2A1F15)' }}>
        <div className="w-full h-full rounded-[28px] overflow-hidden relative"
          style={{ backgroundColor: T.base }}>
          <div className="absolute top-0 left-0 right-0 h-5 flex items-center justify-between px-5 z-20 pointer-events-none">
            <Body size={9} weight={700} color={T.forest}>9:41</Body>
            <div className="w-5 h-2 rounded-sm border" style={{ borderColor: T.forest }}>
              <div className="h-full" style={{ width: '70%', backgroundColor: T.forest, borderRadius: 1 }} />
            </div>
          </div>
          <div className="absolute inset-0 pt-5">{children}</div>
        </div>
      </div>
    </div>
  </div>
);

const BottomNav = ({ tabs, current }) => (
  <div className="absolute bottom-0 left-0 right-0 h-14 flex items-center justify-around"
    style={{ backgroundColor: T.card, borderTop: `1px solid ${T.divider}` }}>
    {tabs.map(t => {
      const Icon = t.icon;
      const active = t.id === current;
      return (
        <div key={t.id} className="flex flex-col items-center gap-0.5">
          <Icon size={18} color={active ? T.forest : T.textMuted} />
          <Body size={9} weight={700} color={active ? T.forest : T.textMuted}>{t.label}</Body>
        </div>
      );
    })}
  </div>
);

const FAB = () => (
  <div className="absolute right-3 z-10 rounded-full flex items-center justify-center shadow-lg"
    style={{ bottom: 70, width: 52, height: 52, backgroundColor: T.forest }}>
    <Plus size={24} color={T.base} />
  </div>
);

// =====================================================================
// ARCHITECTURE A — Statu quo nettoyé
// =====================================================================
// 3 tabs Explorer/Carnet/Profil — comme aujourd'hui mais resserré :
// - Mini-cartes des territoires supprimées (lignes compactes)
// - Bouton + devient un FAB global (pas dans le header)
// - Le drill territoire → catégories → espèces reste
// =====================================================================
const ArchA = () => (
  <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
    <div className="px-4 pt-3 pb-1">
      <Label color={T.terracotta} ls={2.5}>Carnet naturaliste</Label>
      <div className="mt-0.5"><Title size={28} italic>Spotted</Title></div>
    </div>

    {/* Mini-stats compact en haut, vs grosse carte gradient */}
    <div className="mx-4 mt-2 px-3 py-2 rounded-xl flex items-center gap-3"
      style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
      <div className="flex items-center gap-1">
        <Title size={16}>3</Title>
        <Body size={10} color={T.textSecondary} weight={700}>NIV</Body>
      </div>
      <div className="w-px h-5" style={{ backgroundColor: T.divider }} />
      <Body size={11}>🔥 5j</Body>
      <Body size={9} color={T.gold} weight={700}>×1.10</Body>
      <div className="flex-1" />
      <Body size={11} color={T.terracotta} weight={700}>2/3 quêtes →</Body>
    </div>

    <div className="px-4 mt-3 mb-1"><Label>Mes terrains</Label></div>
    <div className="px-4 space-y-2 flex-1">
      {TERRITORIES.map(t => (
        <div key={t.code} className="flex items-center gap-3 px-3 py-2.5 rounded-xl"
          style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
          <TerritoryBadge code={t.code} size={36} />
          <div className="flex-1">
            <div className="flex items-center gap-1.5">
              <Title size={16}>{t.name}</Title>
              <span className="px-1.5 py-0.5 rounded-full" style={{ backgroundColor: t.tagColor }}>
                <Body size={8} color={T.base} weight={700}>{t.tag}</Body>
              </span>
            </div>
            <div className="mt-1 flex items-center gap-2">
              <Body size={10} weight={700} color={T.forest}>{t.observed}</Body>
              <div className="flex-1"><Progress value={t.observed} max={t.total} h={4} /></div>
              <Body size={10} color={T.textSecondary}>{t.total}</Body>
            </div>
          </div>
          <ChevronRight size={14} color={T.forest} />
        </div>
      ))}
    </div>

    <FAB />
    <BottomNav current="explore" tabs={[
      { id: 'explore', icon: Compass, label: 'Explorer' },
      { id: 'carnet', icon: MapIcon, label: 'Carnet' },
      { id: 'profil', icon: User, label: 'Profil' },
    ]} />
  </div>
);

// =====================================================================
// ARCHITECTURE B — Aplati (territoire = filtre)
// =====================================================================
// 3 tabs Espèces/Carnet/Profil — la home devient direct la liste
// d'espèces avec un filtre zone optionnel. Le drilldown territorial
// est supprimé. Le territoire reste une donnée système.
// =====================================================================
const ArchB = () => (
  <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
    <div className="px-4 pt-3 pb-2 flex items-center justify-between">
      <Title size={24}>Espèces</Title>
      <Body size={11} weight={700} color={T.terracotta}>9 / 123</Body>
    </div>

    {/* Search bar */}
    <div className="mx-4 px-3 py-2 rounded-full flex items-center gap-2"
      style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
      <Search size={14} color={T.textSecondary} />
      <Body size={12} color={T.textMuted}>Buse, faucon, alcedo…</Body>
      <div className="flex-1" />
      <Filter size={14} color={T.forest} />
    </div>

    {/* Filtres en row scrollable */}
    <div className="px-4 pt-2 pb-1 flex gap-1.5 overflow-x-auto">
      <Chip active label="Toutes" />
      <Chip label="🦅 Oiseaux" />
      <Chip label="🦌 Mamm." />
      <Chip label="🦎 Rept." />
      <div className="w-px self-stretch" style={{ backgroundColor: T.divider }} />
      <Chip label="📍 Oise" />
      <Chip label="📍 Aisne" />
    </div>

    <div className="flex-1 overflow-y-auto px-4 pb-20">
      {SPECIES.slice(0, 5).map(s => <SpeciesRow key={s.id} s={s} />)}
      <Body size={10} italic color={T.textMuted}>… 4 autres</Body>
    </div>

    <FAB />
    <BottomNav current="especes" tabs={[
      { id: 'especes', icon: BookOpen, label: 'Espèces' },
      { id: 'carnet', icon: MapIcon, label: 'Carnet' },
      { id: 'profil', icon: User, label: 'Profil' },
    ]} />
  </div>
);

const Chip = ({ label, active }) => (
  <div className="px-2.5 py-1 rounded-full whitespace-nowrap"
    style={{
      backgroundColor: active ? T.forest : T.card,
      border: `1.5px solid ${active ? T.forest : T.divider}`,
    }}>
    <Body size={11} weight={600} color={active ? T.base : T.textSecondary}>{label}</Body>
  </div>
);

const SpeciesRow = ({ s }) => {
  const color = RARITY[s.rarity];
  return (
    <div className="flex items-stretch rounded-xl overflow-hidden mb-2"
      style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
      <div style={{ width: 4, backgroundColor: color }} />
      <div className="flex-1 p-2.5 flex items-center gap-2.5">
        <div className="w-9 h-9 rounded-full flex items-center justify-center"
          style={{ backgroundColor: T.muted, fontSize: 16 }}>{s.observed ? s.cat : '?'}</div>
        <div className="flex-1 min-w-0">
          <Body size={13} weight={600}>{s.observed ? s.name : '???'}</Body>
          <div><Body size={10} italic color={T.textSecondary}>{s.observed ? s.sci : 'À débusquer'} · {s.zone}</Body></div>
        </div>
        {s.observed ? (
          <Body size={10} color={T.textSecondary}>{s.lastObs}</Body>
        ) : (
          <Body size={10} weight={700} color={color}>{s.rarity}</Body>
        )}
      </div>
    </div>
  );
};

// =====================================================================
// ARCHITECTURE C — Hybride
// =====================================================================
// Comme B (3 tabs Espèces/Carnet/Profil + liste flat) mais le profil
// montre une section "Mes zones" avec la progression par territoire,
// pour ne pas perdre la vue d'ensemble.
// =====================================================================
const ArchC = () => {
  const [tab, setTab] = useState('especes');
  return (
    <div className="h-full flex flex-col" style={{ backgroundColor: T.base }}>
      {tab === 'especes' && <ArchCEspecesContent />}
      {tab === 'profil' && <ArchCProfilContent />}

      <FAB />
      <div className="absolute bottom-0 left-0 right-0 h-14 flex items-center justify-around"
        style={{ backgroundColor: T.card, borderTop: `1px solid ${T.divider}` }}>
        <TabBtn id="especes" current={tab} onTap={() => setTab('especes')} icon={BookOpen} label="Espèces" />
        <TabBtn id="carnet" current={tab} onTap={() => setTab('carnet')} icon={MapIcon} label="Carnet" />
        <TabBtn id="profil" current={tab} onTap={() => setTab('profil')} icon={User} label="Profil" />
      </div>
    </div>
  );
};

const TabBtn = ({ id, current, onTap, icon: Icon, label }) => {
  const active = id === current;
  return (
    <button onClick={onTap} className="flex flex-col items-center gap-0.5">
      <Icon size={18} color={active ? T.forest : T.textMuted} />
      <Body size={9} weight={700} color={active ? T.forest : T.textMuted}>{label}</Body>
    </button>
  );
};

const ArchCEspecesContent = () => (
  <>
    <div className="px-4 pt-3 pb-2 flex items-center justify-between">
      <Title size={24}>Espèces</Title>
      <Body size={11} weight={700} color={T.terracotta}>9 / 123</Body>
    </div>
    <div className="mx-4 px-3 py-2 rounded-full flex items-center gap-2"
      style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
      <Search size={14} color={T.textSecondary} />
      <Body size={12} color={T.textMuted}>Buse, faucon, alcedo…</Body>
      <div className="flex-1" />
      <Filter size={14} color={T.forest} />
    </div>
    <div className="px-4 pt-2 pb-1 flex gap-1.5 overflow-x-auto">
      <Chip active label="Toutes" />
      <Chip label="🦅 Oiseaux" />
      <Chip label="🦌 Mamm." />
      <div className="w-px self-stretch" style={{ backgroundColor: T.divider }} />
      <Chip label="📍 Oise" />
      <Chip label="📍 Aisne" />
    </div>
    <div className="flex-1 overflow-y-auto px-4 pb-20">
      {SPECIES.slice(0, 5).map(s => <SpeciesRow key={s.id} s={s} />)}
      <Body size={10} italic color={T.textMuted}>… 4 autres</Body>
    </div>
    <div className="px-4 mb-16 mt-2 text-center">
      <Body size={9} italic color={T.textMuted}>↓ tape l'onglet Profil pour voir "Mes zones"</Body>
    </div>
  </>
);

const ArchCProfilContent = () => (
  <div className="h-full overflow-y-auto pb-20 px-4 pt-3">
    {/* Level header très compact */}
    <div className="rounded-2xl p-3" style={{ background: `linear-gradient(135deg, ${T.forest}, ${T.forestLight})` }}>
      <div className="flex items-center gap-3">
        <div className="w-10 h-10 rounded-full flex items-center justify-center"
          style={{ background: `linear-gradient(135deg, ${T.goldLight}, ${T.gold})` }}>
          <Title size={16} color={T.forest}>3</Title>
        </div>
        <div className="flex-1">
          <Label color="#C4A572" ls={1.5}>Niveau 3 · 420 / 900 pts</Label>
          <div className="mt-1"><Progress value={420} max={900} color={T.goldLight} h={4} /></div>
        </div>
        <div className="flex flex-col items-center" style={{ borderLeft: '1px solid #ffffff20', paddingLeft: 10 }}>
          <Body size={14}>🔥</Body>
          <Body size={11} weight={700} color={T.base}>5j</Body>
        </div>
      </div>
    </div>

    {/* Stats inline */}
    <div className="mt-3 px-3 py-3 rounded-xl flex justify-around"
      style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}` }}>
      {[['9', 'ESPÈCES'], ['14', 'OBS'], ['5', 'PHOTOS'], ['1', 'LÉGEND.']].map(([v, l]) => (
        <div key={l} className="text-center">
          <Title size={18}>{v}</Title>
          <div><Body size={8} weight={700} color={T.textSecondary}>{l}</Body></div>
        </div>
      ))}
    </div>

    {/* SECTION MES ZONES — le delta vs B */}
    <div className="mt-4 mb-1 flex items-center justify-between">
      <Label>Mes zones</Label>
      <Body size={10} color={T.forest} weight={700}>+ AJOUTER</Body>
    </div>
    <div className="space-y-2">
      {TERRITORIES.map(t => (
        <div key={t.code} className="flex items-center gap-3 px-3 py-2 rounded-xl"
          style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
          <TerritoryBadge code={t.code} size={32} />
          <div className="flex-1">
            <Title size={14}>{t.name}</Title>
            <div className="flex items-center gap-2 mt-0.5">
              <Body size={10} weight={700} color={T.forest}>{t.observed}</Body>
              <div className="flex-1"><Progress value={t.observed} max={t.total} h={3} /></div>
              <Body size={10} color={T.textSecondary}>{t.total}</Body>
            </div>
          </div>
        </div>
      ))}
    </div>

    {/* Badges teaser, quêtes, etc */}
    <div className="mt-4 mb-1"><Label>Badges</Label></div>
    <div className="px-3 py-2.5 rounded-xl flex items-center"
      style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
      <div className="flex-1">
        <Title size={18}>5 / 13</Title>
      </div>
      <div className="flex gap-1">
        {['🐣', '🐾', '⚡', '🔥', '📸'].map(e => (
          <div key={e} className="w-6 h-6 rounded-full flex items-center justify-center"
            style={{ backgroundColor: T.muted, fontSize: 12 }}>{e}</div>
        ))}
      </div>
      <ChevronRight size={14} color={T.forest} />
    </div>

    <div className="mt-4 mb-1"><Label>Quêtes du jour</Label></div>
    <div className="px-3 py-2.5 rounded-xl"
      style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
      <Body size={11}>2 / 3 réclamées · +50 XP restant</Body>
    </div>

    <div className="mt-4 mb-1"><Label>Réglages</Label></div>
    <div className="px-3 py-2.5 rounded-xl flex items-center gap-2"
      style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
      <Body size={12}>Rappel quotidien · 13:00</Body>
    </div>
  </div>
);

// =====================================================================
// PROS / CONS PANELS
// =====================================================================
const Pros = ({ items }) => (
  <div className="rounded-xl p-2.5"
    style={{ backgroundColor: '#E8F0E2', border: `1px solid #94B584` }}>
    <Label color={T.forest} ls={2}>✓ Pour</Label>
    <ul className="mt-1 ml-3 list-disc">
      {items.map((it, i) => (
        <li key={i}><Body size={10} color={T.textPrimary}>{it}</Body></li>
      ))}
    </ul>
  </div>
);

const Cons = ({ items }) => (
  <div className="rounded-xl p-2.5"
    style={{ backgroundColor: '#FCE7E2', border: `1px solid ${T.terracotta}` }}>
    <Label color={T.terracotta} ls={2}>✗ Contre</Label>
    <ul className="mt-1 ml-3 list-disc">
      {items.map((it, i) => (
        <li key={i}><Body size={10} color={T.textPrimary}>{it}</Body></li>
      ))}
    </ul>
  </div>
);

// =====================================================================
// APP — 3 architectures côte à côte
// =====================================================================
export default function ArchitectureV2() {
  return (
    <div className="min-h-screen p-6"
      style={{ background: `radial-gradient(circle at 50% 0%, ${T.forest} 0%, #0d1f17 100%)` }}>
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-8">
          <Label color={T.goldLight} ls={3}>REFONTE ARCHITECTURE</Label>
          <div className="mt-1"><Title size={32} color={T.base} italic>3 directions possibles</Title></div>
          <div className="mt-2 max-w-2xl mx-auto">
            <Body size={12} italic color={T.goldLight}>
              Tension actuelle : la home mélange gamification, exploration et accueil.
              Les territoires en tant que niveau de navigation font doublon avec le Carnet.
            </Body>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

          {/* ───────── A ───────── */}
          <div className="space-y-3">
            <PhoneFrame label="A · Statu quo nettoyé"><ArchA /></PhoneFrame>
            <div className="px-2">
              <Body size={11} color={T.goldLight} italic>
                Tabs : Explorer / Carnet / Profil.
                Mini-cartes virées, "+" en FAB. Le drill territoire reste.
              </Body>
            </div>
            <Pros items={[
              'Refonte minimale',
              'Familier si tu testes déjà l\'app',
              'Garde l\'idée "Pokédex par région"',
            ]} />
            <Cons items={[
              'Le doublon "carte des terrains vs carte du carnet" persiste',
              'Drilldown 3 niveaux pour atteindre une espèce',
              '"Explorer" reste un verbe vague',
            ]} />
          </div>

          {/* ───────── B ───────── */}
          <div className="space-y-3">
            <PhoneFrame label="B · Aplati (territoire = filtre)"><ArchB /></PhoneFrame>
            <div className="px-2">
              <Body size={11} color={T.goldLight} italic>
                Tabs : Espèces / Carnet / Profil.
                Liste flat avec filtre zone. Plus de territoire en nav.
              </Body>
            </div>
            <Pros items={[
              'Nom de tabs clairs (Espèces, Carnet, Profil)',
              'Plus de doublon visuel',
              '1 tap pour voir la liste d\'espèces',
              'Le carnet vintage respire',
            ]} />
            <Cons items={[
              'Plus radical, plus de code à déplacer',
              'On perd la vue "complétion par territoire"',
              'Si tu ajoutes 5+ zones, le filtre devient encombré',
            ]} />
          </div>

          {/* ───────── C ───────── */}
          <div className="space-y-3">
            <PhoneFrame label="C · Hybride (Espèces flat + Mes zones en Profil)">
              <ArchC />
            </PhoneFrame>
            <div className="px-2">
              <Body size={11} color={T.goldLight} italic>
                Tape sur Profil dans la phone pour voir la section "Mes zones".
                Garde la vue de complétion par zone, sans la mettre au centre.
              </Body>
            </div>
            <Pros items={[
              'Meilleur des deux mondes',
              'Vue de complétion par zone conservée (Profil)',
              'L\'écran principal reste centré sur "que vais-je observer ?"',
              'Bouton "+ AJOUTER une zone" naturel dans Profil',
            ]} />
            <Cons items={[
              'Profil devient un peu long',
              'Plus de surfaces à designer (Profil enrichi)',
            ]} />
          </div>

        </div>

        <div className="mt-8 p-5 rounded-2xl"
          style={{ background: `linear-gradient(135deg, ${T.gold}20, ${T.gold}10)`,
                   border: `1.5px solid ${T.gold}` }}>
          <Label color={T.forest} ls={2.5}>Ma recommandation</Label>
          <div className="mt-2">
            <Body size={13} color={T.textPrimary}>
              <strong>C (hybride)</strong> est ce qui correspond le mieux à ton usage réel : tu vis
              à un endroit, tu vas occasionnellement explorer ailleurs. Le territoire reste une
              donnée importante (rareté locale, progression), mais sort du chemin de navigation
              quotidienne. La liste d'espèces directe = 1 tap, et tu retrouves le côté "Pokédex
              par région" dans le Profil sans l'imposer.
              <br /><br />
              <strong>Si tu veux le moins de churn possible</strong>, A. Si tu veux clean, B.
            </Body>
          </div>
        </div>
      </div>
    </div>
  );
}
