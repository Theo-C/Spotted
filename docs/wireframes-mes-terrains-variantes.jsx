import React, { useState } from 'react';
import { ChevronRight, MapPin, Home, Compass, Plane, Trees, Mountain, Plus } from 'lucide-react';

// =====================================================================
// Wireframes — "Mes terrains" sur la Home, scénarios à 6 territoires
// =====================================================================
// Objectif : trouver une présentation qui scale au-delà de 2 territoires
// et qui supporte les futurs cas non-FR (pays étrangers, DOM-TOM, îles).
//
// 4 variantes proposées + l'état actuel pour comparaison.
// =====================================================================

const T = {
  base: '#F5EDDF', card: '#FAF6EC', muted: '#F0E8D2', divider: '#E8E0CE',
  forest: '#1F3D2E', forestLight: '#2D5A42',
  terracotta: '#B8624A', gold: '#C49120', goldLight: '#FFD66B',
  textPrimary: '#2A1F15', textSecondary: '#6B5D4F', textMuted: '#A89B86',
};

// Modèle de territoire — anticipe les cas non-FR.
// `kind` : metroFR | overseasFR | foreign | island
// `badgeKind` : la pastille de gauche : 'number' (00) | 'flag' (🇨🇷) | 'icon'
const TERRITORIES = [
  { id: 'oise', kind: 'metroFR', badgeKind: 'number', badge: '60',
    name: 'Oise', tag: 'DOMICILE', tagColor: '#1F3D2E',
    observed: 8, total: 71 },
  { id: 'aisne', kind: 'metroFR', badgeKind: 'number', badge: '02',
    name: 'Aisne', tag: 'VOISIN', tagColor: '#B8624A',
    observed: 1, total: 52 },
  { id: 'somme', kind: 'metroFR', badgeKind: 'number', badge: '80',
    name: 'Somme', tag: 'ESCAPADE', tagColor: '#7A3D9A',
    observed: 12, total: 48 },
  { id: 'pyrenees', kind: 'metroFR', badgeKind: 'number', badge: '64',
    name: 'Pyrénées-Atlantiques', tag: 'VACANCES', tagColor: '#2D6E8C',
    observed: 4, total: 95 },
  { id: 'reunion', kind: 'overseasFR', badgeKind: 'number', badge: '974',
    name: 'La Réunion', tag: 'ÎLE', tagColor: '#7A3D9A',
    observed: 6, total: 38 },
  { id: 'costaRica', kind: 'foreign', badgeKind: 'flag', badge: '🇨🇷',
    name: 'Costa Rica', tag: 'VOYAGE', tagColor: '#C49120',
    observed: 23, total: 142 },
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

const Title = ({ children, size = 22, color = T.forest, italic = false, weight = 600 }) => (
  <span style={{
    fontFamily: 'Cormorant Garamond, serif',
    fontSize: size, fontWeight: weight, color,
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

const Progress = ({ value, max, color = T.terracotta, h = 6, bg = '#E8E0CE' }) => {
  const pct = max === 0 ? 0 : Math.min(100, (value / max) * 100);
  return (
    <div className="w-full rounded-full overflow-hidden" style={{ height: h, backgroundColor: bg }}>
      <div className="h-full" style={{ width: pct + '%', backgroundColor: color, borderRadius: 999 }} />
    </div>
  );
};

// Pastille d'identification, polymorphique selon le type de territoire.
// Métropole FR / DOM : numéro de département.
// Pays étranger : drapeau.
// Île (générique) : icône.
const TerritoryBadge = ({ t, size = 44 }) => {
  if (t.badgeKind === 'flag') {
    return (
      <div className="flex items-center justify-center rounded-xl"
        style={{ width: size, height: size, backgroundColor: T.muted, fontSize: size * 0.55 }}>
        {t.badge}
      </div>
    );
  }
  // numéro département (FR métropole ou DOM 3 chiffres)
  const isLong = t.badge.length >= 3;
  return (
    <div className="flex items-center justify-center rounded-xl"
      style={{
        width: size, height: size,
        background: `linear-gradient(135deg, ${T.forest}, ${T.forestLight})`,
      }}>
      <span style={{
        fontFamily: 'Cormorant Garamond, serif',
        fontSize: isLong ? size * 0.36 : size * 0.46,
        fontWeight: 700, color: T.goldLight, letterSpacing: '-0.02em',
      }}>{t.badge}</span>
    </div>
  );
};

const TagPill = ({ tag, color }) => (
  <span className="px-1.5 py-0.5 rounded-full inline-flex items-center"
    style={{ backgroundColor: color, color: T.base }}>
    <Body size={8} color={T.base} weight={700}>{tag}</Body>
  </span>
);

// =====================================================================
// VARIANTE 0 — État ACTUEL (référence visuelle)
// =====================================================================
// Carte ~280 px de haut avec mini-map statique inutile + zone info.
// À 6 territoires : ~1700 px, scrolling intense, charge Mapbox inutile.
// =====================================================================
const CurrentTerritoryCard = ({ t }) => (
  <div className="rounded-2xl overflow-hidden"
    style={{ backgroundColor: T.card, border: `2px solid ${T.forest}` }}>
    <div className="h-32 relative flex items-center justify-center"
      style={{ background: 'linear-gradient(180deg, #EFE7D2, #D8CFAE)' }}>
      <Mountain size={36} color={T.forest} style={{ opacity: 0.35 }} />
      <div className="absolute top-2 right-2"><TagPill tag={t.tag} color={t.tagColor} /></div>
      <span className="absolute bottom-1 left-2"
        style={{ fontFamily: 'Karla', fontSize: 8, color: T.textMuted, fontStyle: 'italic' }}>
        carte décorative (sans info utile)
      </span>
    </div>
    <div className="p-3 flex items-center gap-2">
      <Title size={18}>{t.name}</Title>
      <Body size={11} italic color={T.terracotta}>({t.badge})</Body>
      <div className="flex-1" />
      <Body size={11} weight={700} color={T.forest}>{t.observed}</Body>
      <div style={{ width: 60 }}><Progress value={t.observed} max={t.total} h={5} /></div>
      <Body size={11} color={T.textSecondary}>{t.total}</Body>
      <ChevronRight size={14} color={T.forest} />
    </div>
  </div>
);

const VariantCurrent = () => (
  <Wrap title="État actuel (référence)"
    pros={['Visuel "carte"', 'Reconnaissance immédiate']}
    cons={[
      'Mini-carte ne montre rien d\'utile (zoom 8, pas d\'obs, pas tappable)',
      '~280 px par territoire → ~1700 px pour 6 territoires',
      'Coût Mapbox API à chaque rendu',
      'Ne s\'adapte pas aux îles / pays étrangers',
    ]}>
    <div className="space-y-2">
      {TERRITORIES.slice(0, 3).map(t => <CurrentTerritoryCard key={t.id} t={t} />)}
      <Body size={10} italic color={T.textMuted}>… 3 autres territoires masqués (scroll requis)</Body>
    </div>
  </Wrap>
);

// =====================================================================
// VARIANTE A — Liste compacte (rows)
// =====================================================================
// 1 row par territoire, ~64 px. La pastille de gauche est polymorphique
// (numero | drapeau | icône) pour gérer les cas non-FR.
// Densité maximale, lisibilité optimale, scalable à 10+ territoires.
// =====================================================================
const TerritoryRowCompact = ({ t }) => (
  <div className="flex items-center gap-3 px-3 py-2.5 rounded-xl"
    style={{ backgroundColor: T.card, border: `1px solid ${T.divider}` }}>
    <TerritoryBadge t={t} size={44} />
    <div className="flex-1 min-w-0">
      <div className="flex items-center gap-1.5 mb-0.5">
        <Title size={17}>{t.name}</Title>
        <TagPill tag={t.tag} color={t.tagColor} />
      </div>
      <div className="flex items-center gap-2">
        <Body size={11} weight={700} color={T.forest}>{t.observed}</Body>
        <div className="flex-1"><Progress value={t.observed} max={t.total} h={5} /></div>
        <Body size={11} color={T.textSecondary}>{t.total}</Body>
      </div>
    </div>
    <ChevronRight size={16} color={T.forest} />
  </div>
);

const VariantA = () => (
  <Wrap title="A · Liste compacte"
    pros={[
      'Tient à 6+ territoires sans scroll',
      'Pastille polymorphe (numéro FR / drapeau / icône) → multi-pays OK',
      'La progression est l\'info principale (visible direct)',
      'Aucun appel Mapbox API',
    ]}
    cons={[
      'Moins "carte naturaliste" visuellement',
      'Tous les territoires ont le même poids visuel',
    ]}>
    <div className="space-y-2">
      {TERRITORIES.map(t => <TerritoryRowCompact key={t.id} t={t} />)}
    </div>
  </Wrap>
);

// =====================================================================
// VARIANTE B — Grid 2 colonnes
// =====================================================================
// Tuiles carrées 100×130 avec pastille XL, nom, mini barre.
// Visuel rythmé, scalable, mais sacrifie la lisibilité de la progression.
// =====================================================================
const TerritoryTile = ({ t }) => (
  <div className="p-3 rounded-2xl flex flex-col items-center text-center"
    style={{ backgroundColor: T.card, border: `1.5px solid ${T.divider}`, minHeight: 140 }}>
    <TerritoryBadge t={t} size={56} />
    <div className="mt-2"><Title size={15}>{t.name}</Title></div>
    <div className="mt-0.5"><TagPill tag={t.tag} color={t.tagColor} /></div>
    <div className="flex-1" />
    <div className="w-full mt-2"><Progress value={t.observed} max={t.total} h={5} /></div>
    <div className="mt-1.5">
      <Body size={10} weight={700} color={T.forest}>{t.observed}</Body>
      <Body size={10} color={T.textSecondary}> / {t.total}</Body>
    </div>
  </div>
);

const VariantB = () => (
  <Wrap title="B · Grid 2 colonnes"
    pros={[
      'Visuel rythmé, équilibre entre densité et image',
      'Multi-pays OK (pastille polymorphe)',
      'Tient 8 territoires sur 4 rangées',
    ]}
    cons={[
      'Barre de progression très petite (~80 px de large)',
      'Compteur observed/total perdu visuellement',
      'Si le nom est long ("Pyrénées-Atlantiques") il tronque',
    ]}>
    <div className="grid grid-cols-2 gap-2">
      {TERRITORIES.map(t => <TerritoryTile key={t.id} t={t} />)}
    </div>
  </Wrap>
);

// =====================================================================
// VARIANTE C — Carrousel horizontal
// =====================================================================
// Cartes 200×180 swipeable horizontalement. Conserve une dimension "carte"
// (sans la mini-map) avec la pastille XL en hero.
// =====================================================================
const CarouselCard = ({ t }) => (
  <div className="flex-shrink-0 rounded-2xl p-3 flex flex-col"
    style={{
      width: 180, height: 170, backgroundColor: T.card,
      border: `1.5px solid ${T.divider}`,
    }}>
    <div className="flex items-center justify-between">
      <TerritoryBadge t={t} size={48} />
      <TagPill tag={t.tag} color={t.tagColor} />
    </div>
    <div className="mt-2"><Title size={18}>{t.name}</Title></div>
    <div className="flex-1" />
    <div className="mt-2"><Progress value={t.observed} max={t.total} h={5} /></div>
    <div className="mt-1 flex items-center justify-between">
      <Body size={11} weight={700} color={T.forest}>{t.observed} / {t.total}</Body>
      <ChevronRight size={14} color={T.forest} />
    </div>
  </div>
);

const VariantC = () => (
  <Wrap title="C · Carrousel horizontal"
    pros={[
      'Garde un côté "carte" visuel',
      'Scalable horizontalement à l\'infini',
      'Le 1er territoire (DOMICILE) reste visible en permanence',
    ]}
    cons={[
      'Découvrabilité du scroll H sur Flutter (les users oublient souvent)',
      'Vue d\'ensemble impossible — il faut swipe pour voir tous les territoires',
      '~190 px de haut quand même → moins compact que A',
    ]}>
    <div className="flex gap-2 overflow-x-auto pb-2" style={{ scrollSnapType: 'x mandatory' }}>
      {TERRITORIES.map(t => (
        <div key={t.id} style={{ scrollSnapAlign: 'start' }}>
          <CarouselCard t={t} />
        </div>
      ))}
    </div>
  </Wrap>
);

// =====================================================================
// VARIANTE D — Hybride : DOMICILE en hero + reste en liste
// =====================================================================
// Reconnaît que le territoire principal mérite plus de poids visuel.
// Les autres en liste compacte. Compromis entre A et l'actuel.
// =====================================================================
const HeroCard = ({ t }) => (
  <div className="rounded-2xl p-4 relative overflow-hidden"
    style={{
      background: `linear-gradient(135deg, ${T.forest}, ${T.forestLight})`,
    }}>
    <div className="flex items-start justify-between mb-3">
      <TerritoryBadge t={t} size={56} />
      <TagPill tag={t.tag} color={T.goldLight} />
    </div>
    <Title size={28} color={T.base}>{t.name}</Title>
    <div className="mt-3"><Progress value={t.observed} max={t.total} h={6} color={T.goldLight} bg="#ffffff30" /></div>
    <div className="mt-1.5 flex items-center justify-between">
      <div>
        <Body size={13} weight={700} color={T.base}>{t.observed} espèces vues</Body>
        <span> </span>
        <Body size={11} color="#C4A572">sur {t.total}</Body>
      </div>
      <Body size={10} weight={700} color={T.goldLight}>{Math.round((t.observed / t.total) * 100)}%</Body>
    </div>
  </div>
);

const VariantD = () => (
  <Wrap title="D · Hybride (hero + liste)"
    pros={[
      'Hiérarchie naturelle : DOMICILE = principal',
      'Visuel fort sans le coût de la mini-map',
      'Scalable (autres territoires en liste compacte)',
    ]}
    cons={[
      'Deux composants à maintenir (hero + row)',
      'Le "hero" peut être moins pertinent quand on voyage souvent',
    ]}>
    <div className="space-y-2">
      <HeroCard t={TERRITORIES[0]} />
      {TERRITORIES.slice(1).map(t => <TerritoryRowCompact key={t.id} t={t} />)}
    </div>
  </Wrap>
);

// =====================================================================
// Wrapper avec pros/cons et titre
// =====================================================================
const Wrap = ({ title, children, pros, cons }) => (
  <div className="mb-6">
    <div className="px-2 mb-1.5">
      <Title size={20}>{title}</Title>
    </div>
    <div className="grid grid-cols-1 md:grid-cols-[1fr_280px] gap-3">
      <div className="rounded-2xl p-3"
        style={{ backgroundColor: T.muted, border: `1px solid ${T.divider}` }}>
        {children}
      </div>
      <div className="space-y-2">
        <div className="rounded-xl p-2.5"
          style={{ backgroundColor: '#E8F0E2', border: `1px solid #94B584` }}>
          <Label color={T.forest} ls={2}>✓ Pour</Label>
          <ul className="mt-1 ml-3 list-disc">
            {pros.map((p, i) => (
              <li key={i}><Body size={11} color={T.textPrimary}>{p}</Body></li>
            ))}
          </ul>
        </div>
        <div className="rounded-xl p-2.5"
          style={{ backgroundColor: '#FCE7E2', border: `1px solid ${T.terracotta}` }}>
          <Label color={T.terracotta} ls={2}>✗ Contre</Label>
          <ul className="mt-1 ml-3 list-disc">
            {cons.map((c, i) => (
              <li key={i}><Body size={11} color={T.textPrimary}>{c}</Body></li>
            ))}
          </ul>
        </div>
      </div>
    </div>
  </div>
);

// =====================================================================
// App
// =====================================================================
export default function WireframeTerrainsVariantes() {
  return (
    <div className="min-h-screen p-6"
      style={{ background: `radial-gradient(circle at 50% 0%, ${T.forest} 0%, #0d1f17 100%)` }}>
      <div className="max-w-5xl mx-auto">
        <div className="text-center mb-6">
          <Label color={T.goldLight} ls={3}>WIREFRAMES · MES TERRAINS</Label>
          <div className="mt-1"><Title size={32} color={T.base} italic>Variantes pour scaler à 6+ territoires</Title></div>
          <div className="mt-2 max-w-xl mx-auto">
            <Body size={12} italic color={T.goldLight}>
              Données : Oise (DOMICILE), Aisne (VOISIN), Somme, Pyrénées-Atlantiques,
              La Réunion (DOM), Costa Rica (étranger).
              Les pastilles s'adaptent : numéro FR, drapeau étranger.
            </Body>
          </div>
        </div>

        <div className="rounded-2xl p-4" style={{ backgroundColor: T.base }}>
          <VariantCurrent />
          <VariantA />
          <VariantB />
          <VariantC />
          <VariantD />

          <div className="mt-8 p-4 rounded-2xl"
            style={{ background: `linear-gradient(135deg, ${T.gold}20, ${T.gold}10)`,
                     border: `1.5px solid ${T.gold}` }}>
            <Label color={T.forest} ls={2.5}>Recommandation</Label>
            <div className="mt-2">
              <Body size={13} color={T.textPrimary}>
                <strong>Variante A (liste compacte)</strong> pour le MVP : scalable, lisible,
                multi-pays OK, aucun coût Mapbox API. La pastille polymorphe (numéro / drapeau)
                couvre tous les cas futurs sans casser l'architecture.
                <br /><br />
                <strong>D (hybride)</strong> est une alternative si tu veux garder un visuel
                fort pour le territoire DOMICILE — à reconsidérer plus tard si l'usage le justifie.
              </Body>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
