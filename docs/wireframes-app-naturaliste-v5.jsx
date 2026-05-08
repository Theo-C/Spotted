import React, { useState, useEffect } from 'react';
import { ChevronLeft, ChevronRight, Camera, MapPin, Award, Plus, Check, Compass, Map as MapIcon, User, Sparkles, Eye, Filter, Lock, Target, Flame, Star, HelpCircle, Settings, LogOut, Bell, Palette, Database, Info, Image, X, ArrowRight, Trophy, Users, Calendar, BookOpen, RotateCcw, Edit3, AlertTriangle } from 'lucide-react';

// ========== DATA ==========
const RARITY = {
  commun: { label: 'Commun', color: '#7A7569', bg: '#E8E5DD', glow: 'transparent', points: 10, stars: 1 },
  rare: { label: 'Rare', color: '#2D6E8C', bg: '#D5E4EC', glow: '#4A9DC230', points: 30, stars: 2 },
  epique: { label: 'Épique', color: '#7A3D9A', bg: '#E8D9F0', glow: '#A050C840', points: 100, stars: 3 },
  legendaire: { label: 'Légendaire', color: '#C49120', bg: '#F7E9C5', glow: '#FFC04060', points: 300, stars: 4 },
};

const SPECIES = [
  { id: 1, name: 'Buse variable', sci: 'Buteo buteo', cat: 'oiseaux', subcat: 'rapaces-diurnes', rarity: 'commun', desc: 'Le rapace le plus visible en plaine. Posée sur piquet ou en vol plané. Plumage très variable.', observed: true, observations: [{ date: '12 mars 2026', place: 'Forêt de Compiègne', photo: true }, { date: '28 mars 2026', place: 'Plaine de Senlis', photo: false }] },
  { id: 2, name: 'Faucon pèlerin', sci: 'Falco peregrinus', cat: 'oiseaux', subcat: 'rapaces-diurnes', rarity: 'epique', desc: 'En recolonisation des falaises et grands édifices urbains. Stoop spectaculaire à 300 km/h.', observed: false },
  { id: 3, name: 'Balbuzard pêcheur', sci: 'Pandion haliaetus', cat: 'oiseaux', subcat: 'rapaces-diurnes', rarity: 'legendaire', desc: 'En passage sur les grands plans d\'eau. Plonge pour pêcher. Ventre blanc, masque facial sombre.', observed: false },
  { id: 4, name: 'Chouette hulotte', sci: 'Strix aluco', cat: 'oiseaux', subcat: 'rapaces-nocturnes', rarity: 'commun', desc: 'La plus répandue. Chant typique "hou-hou" des forêts. Souvent entendue, rarement vue.', observed: true, observations: [{ date: '4 avril 2026', place: 'Forêt de Halatte', photo: false }, { date: '20 avril 2026', place: 'Bois de Senlis', photo: false }] },
  { id: 5, name: 'Chevêche d\'Athéna', sci: 'Athene noctua', cat: 'oiseaux', subcat: 'rapaces-nocturnes', rarity: 'epique', desc: 'Bocages, vieux vergers, granges isolées. Petite, trapue, parfois diurne sur un piquet.', observed: false },
  { id: 6, name: 'Martin-pêcheur', sci: 'Alcedo atthis', cat: 'oiseaux', subcat: 'passereaux', rarity: 'rare', desc: 'L\'éclair bleu turquoise au ras de l\'eau. Cours d\'eau lents et étangs. Iconique.', observed: true, observations: [{ date: '28 février 2026', place: 'Étangs de Saint-Pierre', photo: true }] },
  { id: 7, name: 'Huppe fasciée', sci: 'Upupa epops', cat: 'oiseaux', subcat: 'passereaux', rarity: 'epique', desc: 'Crête en éventail, vol papillonnant. Vergers, bocages chauds. Chant "houp-houp-houp" doux.', observed: false },
  { id: 10, name: 'Chevreuil', sci: 'Capreolus capreolus', cat: 'mammiferes', subcat: 'cervides', rarity: 'commun', desc: 'Le cervidé le plus visible. Forêts, lisières, plaines agricoles. Tache blanche au croupion.', observed: true, observations: [{ date: '15 mars 2026', place: 'Forêt de Compiègne', photo: true }] },
  { id: 11, name: 'Cerf élaphe', sci: 'Cervus elaphus', cat: 'mammiferes', subcat: 'cervides', rarity: 'rare', desc: 'Grandes forêts domaniales. Brame spectaculaire en automne.', observed: false },
  { id: 12, name: 'Renard roux', sci: 'Vulpes vulpes', cat: 'mammiferes', subcat: 'carnivores', rarity: 'commun', desc: 'Lisières, champs. Aube et crépuscule. Queue touffue à pointe blanche.', observed: true, observations: [{ date: '2 avril 2026', place: 'Bocage de Beauvais', photo: false }] },
  { id: 13, name: 'Loutre d\'Europe', sci: 'Lutra lutra', cat: 'mammiferes', subcat: 'aquatiques', rarity: 'legendaire', desc: 'Recolonisation très lente. Une observation directe = trophée majeur.', observed: false },
];

const CATEGORIES = [
  { id: 'oiseaux', name: 'Oiseaux', icon: '🦅', total: 33, observed: 4, subcats: [{ id: 'all', name: 'Tous' }, { id: 'rapaces-diurnes', name: 'Rapaces diurnes' }, { id: 'rapaces-nocturnes', name: 'Rapaces nocturnes' }, { id: 'echassiers', name: 'Échassiers' }, { id: 'pics', name: 'Pics' }, { id: 'passereaux', name: 'Passereaux' }, { id: 'galliformes', name: 'Galliformes' }] },
  { id: 'mammiferes', name: 'Mammifères', icon: '🦌', total: 16, observed: 2, subcats: [{ id: 'all', name: 'Tous' }, { id: 'cervides', name: 'Cervidés' }, { id: 'carnivores', name: 'Carnivores' }, { id: 'petits', name: 'Petits' }, { id: 'aquatiques', name: 'Aquatiques' }] },
  { id: 'reptiles', name: 'Reptiles', icon: '🦎', total: 7, observed: 1, subcats: [{ id: 'all', name: 'Tous' }, { id: 'lezards', name: 'Lézards' }, { id: 'serpents', name: 'Serpents' }] },
  { id: 'chiropteres', name: 'Chiroptères', icon: '🦇', total: 15, observed: 1, subcats: [{ id: 'all', name: 'Toutes' }, { id: 'anthropophiles', name: 'Anthropophiles' }, { id: 'noctules', name: 'Noctules' }, { id: 'murins', name: 'Murins' }, { id: 'oreillards', name: 'Oreillards' }, { id: 'rhinolophes', name: 'Rhinolophes' }] },
];

const BADGES = [
  { id: 1, subcat: 'Rapaces diurnes', tier: 2, name: 'Amateur des cieux', earned: true, progress: 4, total: 4 },
  { id: 2, subcat: 'Rapaces nocturnes', tier: 1, name: 'Apprenti des nuits', earned: true, progress: 1, total: 1 },
  { id: 3, subcat: 'Cervidés', tier: 1, name: 'Pisteur novice', earned: true, progress: 1, total: 1 },
  { id: 4, subcat: 'Passereaux', tier: 2, name: '???', earned: false, progress: 1, total: 3 },
  { id: 5, subcat: 'Aquatiques', tier: 1, name: '???', earned: false, progress: 0, total: 1 },
  { id: 6, subcat: 'Rhinolophes', tier: 1, name: '???', earned: false, progress: 0, total: 1 },
];

// ========== UI PRIMITIVES ==========

const RarityStars = ({ rarity, size = 10 }) => {
  const r = RARITY[rarity];
  return (
    <div className="flex gap-0.5">
      {Array.from({ length: 4 }).map((_, i) => (
        <Star key={i} size={size} fill={i < r.stars ? r.color : 'none'} stroke={i < r.stars ? r.color : '#D5CDB8'} strokeWidth={1.5} />
      ))}
    </div>
  );
};

const RarityBadge = ({ rarity, size = 'sm', glow = false }) => {
  const r = RARITY[rarity];
  const sizes = { sm: 'text-[10px] px-2 py-0.5', md: 'text-xs px-2.5 py-1', lg: 'text-sm px-3 py-1.5' };
  return (
    <span className={`inline-flex items-center gap-1 rounded-full font-bold tracking-wider uppercase ${sizes[size]}`}
      style={{ backgroundColor: r.bg, color: r.color, border: `1.5px solid ${r.color}`, boxShadow: glow ? `0 0 16px ${r.glow}, 0 2px 4px ${r.color}30` : `0 1px 2px ${r.color}20` }}>
      {rarity === 'legendaire' && <Sparkles size={10} className="animate-pulse" />}
      {r.label}
    </span>
  );
};

const ProgressBar = ({ value, max, color = '#1F3D2E', height = 6 }) => {
  const pct = Math.min(100, (value / max) * 100);
  return (
    <div className="w-full bg-[#E8E0CE] rounded-full overflow-hidden" style={{ height: `${height}px` }}>
      <div className="h-full rounded-full transition-all duration-700 relative overflow-hidden" style={{ width: `${pct}%`, backgroundColor: color }}>
        <div className="absolute inset-0 opacity-40" style={{ background: 'linear-gradient(90deg, transparent 0%, white 50%, transparent 100%)', animation: 'shimmer 2s infinite' }} />
      </div>
    </div>
  );
};

const SparkleField = () => (
  <div className="absolute inset-0 pointer-events-none overflow-hidden">
    {Array.from({ length: 14 }).map((_, i) => (
      <div key={i} className="absolute" style={{ left: `${(i * 37) % 100}%`, top: `${(i * 23) % 100}%`, animation: `sparkle ${2 + (i % 3)}s ${i * 0.2}s infinite` }}>
        <Sparkles size={i % 2 === 0 ? 12 : 8} className="text-[#FFD66B]" fill="#FFD66B" />
      </div>
    ))}
  </div>
);

const ScreenHeader = ({ title, subtitle, onBack }) => (
  <div className="px-6 pt-12 pb-3">
    {onBack && (
      <button onClick={onBack} className="mb-3 -ml-1 flex items-center gap-1 text-[#1F3D2E]">
        <ChevronLeft size={20} strokeWidth={2.5} />
        <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-sm font-semibold">Retour</span>
      </button>
    )}
    {subtitle && <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.25em] text-[#B8624A] font-bold">{subtitle}</p>}
    <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[32px] leading-tight font-semibold text-[#1F3D2E]">{title}</h1>
  </div>
);

// ========== SCREENS ==========

const LoginScreen = ({ onLogin }) => (
  <div className="flex flex-col h-full" style={{ background: 'linear-gradient(180deg, #1F3D2E 0%, #2D5A42 100%)' }}>
    <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
      <div className="w-20 h-20 rounded-full flex items-center justify-center mb-6" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)', boxShadow: '0 0 40px #FFD66B70' }}>
        <span className="text-4xl">🐾</span>
      </div>
      <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[44px] font-medium text-[#FAF6EC] italic leading-tight">Spotted</h1>
      <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#C4A572] italic mt-1">Carnet de chasse naturaliste</p>
    </div>
    <div className="px-6 pb-12">
      <div className="space-y-3 mb-4">
        <div className="bg-[#FAF6EC]/10 backdrop-blur border-2 border-[#C4A572]/30 rounded-2xl px-4 py-3">
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#C4A572] font-bold mb-1">Email</p>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-sm text-[#FAF6EC]">leo@faune.app</p>
        </div>
        <div className="bg-[#FAF6EC]/10 backdrop-blur border-2 border-[#C4A572]/30 rounded-2xl px-4 py-3">
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#C4A572] font-bold mb-1">Mot de passe</p>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-sm text-[#FAF6EC]">••••••••••</p>
        </div>
      </div>
      <button onClick={onLogin} className="w-full rounded-2xl py-4 mb-3" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)', boxShadow: '0 6px 20px -4px #FFD66B70' }}>
        <span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#1F3D2E] uppercase tracking-wider text-sm">Reprendre la chasse</span>
      </button>
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-center text-xs text-[#C4A572]/80">
        Pas de compte ? <span className="font-bold text-[#FFD66B] underline">Créer mon carnet</span>
      </p>
    </div>
  </div>
);

const HomeScreen = ({ onSelectDept, onSelectDeptMap, onOpenAddMenu }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <div className="px-6 pt-12 pb-3">
      <div className="flex items-center justify-between">
        <div>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.25em] text-[#B8624A] font-bold">Carnet naturaliste</p>
          <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[34px] leading-tight font-medium text-[#1F3D2E]">Spotted</h1>
        </div>
        <button onClick={onOpenAddMenu} className="w-9 h-9 rounded-full bg-[#1F3D2E] flex items-center justify-center shadow-md">
          <Plus size={16} className="text-[#FAF6EC]" strokeWidth={3} />
        </button>
      </div>
    </div>

    <div className="mx-6 mb-4 p-4 rounded-2xl relative overflow-hidden" style={{ background: 'linear-gradient(135deg, #1F3D2E 0%, #2D5A42 60%, #1F3D2E 100%)', boxShadow: '0 8px 24px -8px rgba(31, 61, 46, 0.5)' }}>
      <div className="absolute -top-4 -right-4 text-[100px] opacity-10 leading-none">🦌</div>
      <div className="relative">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2 min-w-0">
            <div className="w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)', boxShadow: '0 0 12px #FFD66B60' }}>
              <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base font-bold text-[#1F3D2E]">4</span>
            </div>
            <div className="min-w-0">
              <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-widest text-[#C4A572]">Niveau</p>
              <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#FAF6EC] leading-none truncate">Pisteur</p>
            </div>
          </div>
          <div className="flex items-center gap-1 px-2 py-1 rounded-full flex-shrink-0" style={{ backgroundColor: '#B8624A30' }}>
            <Flame size={11} className="text-[#FFB870]" fill="#FFB870" />
            <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] font-bold text-[#FFB870]">7 j</span>
          </div>
        </div>
        <div className="flex items-baseline gap-1.5 mb-1.5">
          <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[32px] leading-[1.1] font-light text-[#FAF6EC]">1&nbsp;247</span>
          <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#C4A572] uppercase tracking-wider">/&nbsp;1&nbsp;600 pts</span>
        </div>
        <ProgressBar value={1247} max={1600} color="#FFD66B" />
      </div>
    </div>

    <div className="mx-6 mb-4">
      <div className="flex items-center gap-1.5 mb-2">
        <Target size={12} className="text-[#B8624A]" />
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#B8624A] font-bold">Quête en cours</p>
      </div>
      <div className="bg-[#FAF6EC] rounded-2xl border-2 border-[#B8624A] p-4 relative overflow-hidden" style={{ boxShadow: '0 4px 12px -4px #B8624A40' }}>
        <div className="absolute top-0 right-0 w-20 h-20 opacity-15 text-[60px] leading-none p-2">🦉</div>
        <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[15px] text-[#1F3D2E] leading-tight">
          Plus que <span className="font-bold text-[#B8624A]">2 espèces</span> pour devenir
        </p>
        <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-xl text-[#1F3D2E] font-semibold italic mb-2">Amateur des nuits</p>
        <div className="flex items-center gap-2">
          <ProgressBar value={1} max={3} color="#B8624A" height={8} />
          <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-[#1F3D2E]">1/3</span>
        </div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] mt-2 italic">Indice : la chevêche niche dans les vieux vergers</p>
      </div>
    </div>

    <div className="px-6 mb-2">
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Mes terrains</p>
    </div>

    <div className="px-6 mb-3">
      <div className="relative bg-[#FAF6EC] rounded-2xl border-2 border-[#1F3D2E] overflow-hidden" style={{ boxShadow: '0 6px 20px -6px rgba(31, 61, 46, 0.3)' }}>
        <button onClick={() => onSelectDeptMap('oise')} className="block w-full text-left active:opacity-90 transition-opacity">
          <div className="h-32 relative" style={{ background: 'linear-gradient(180deg, #EFE7D2 0%, #D8CFAE 100%)' }}>
            <svg viewBox="0 0 200 200" className="absolute inset-0 w-full h-full p-3">
              <defs><pattern id="dots" x="0" y="0" width="6" height="6" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r="0.5" fill="#1F3D2E" opacity="0.2" /></pattern></defs>
              <path d="M 100 30 L 145 50 L 165 90 L 165 130 L 145 160 L 110 175 L 90 175 L 65 165 L 40 145 L 35 110 L 45 75 L 70 50 Z" fill="url(#dots)" stroke="#1F3D2E" strokeWidth="2" />
              <g transform="translate(105, 60)">
                <circle r="16" fill="#B8624A" opacity="0.3"><animate attributeName="r" values="16;28;16" dur="2s" repeatCount="indefinite" /><animate attributeName="opacity" values="0.3;0;0.3" dur="2s" repeatCount="indefinite" /></circle>
                <circle r="6" fill="#B8624A" stroke="#FAF6EC" strokeWidth="2" />
              </g>
            </svg>
            <div className="absolute top-3 right-3 px-2.5 py-1 rounded-full bg-[#1F3D2E] text-[#FAF6EC]"><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] font-bold">DOMICILE</span></div>
            <div className="absolute bottom-2 right-2 px-2 py-1 rounded-full bg-[#FAF6EC]/95 backdrop-blur flex items-center gap-1 border border-[#1F3D2E]/30">
              <MapIcon size={10} className="text-[#1F3D2E]" />
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] font-bold text-[#1F3D2E] uppercase tracking-wider">Voir mes obs.</span>
            </div>
          </div>
        </button>
        <button onClick={() => onSelectDept('oise')} className="block w-full text-left active:opacity-90 transition-opacity border-t-2 border-[#E8E0CE]">
          <div className="p-4">
            <div className="flex items-center justify-between mb-2">
              <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl text-[#1F3D2E] font-medium">Oise <span className="text-[#B8624A] text-base italic">(60)</span></h3>
              <ChevronRight size={20} className="text-[#1F3D2E]" />
            </div>
            <div className="flex items-center gap-2">
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-[#1F3D2E]">8</span>
              <ProgressBar value={8} max={71} color="#B8624A" height={8} />
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs text-[#6B5D4F]">71</span>
            </div>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] mt-1.5 italic">63 espèces encore à découvrir</p>
          </div>
        </button>
      </div>
    </div>

    <div className="px-6 mb-6">
      <div className="bg-[#FAF6EC] rounded-2xl border-2 border-dashed border-[#C4A572] p-4 opacity-80">
        <div className="flex items-center justify-between">
          <div>
            <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-lg text-[#1F3D2E] font-medium italic">Savoie <span className="text-[#B8624A] text-sm">(73)</span></h3>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] mt-0.5">Verrouillée · Vacances été</p>
          </div>
          <Lock size={16} className="text-[#C4A572]" />
        </div>
      </div>
    </div>
  </div>
);

const AddMenuOverlay = ({ onClose, onAddRegion, onAddSpecies }) => (
  <div className="absolute inset-0 z-40 flex items-end" style={{ background: 'rgba(31, 24, 13, 0.5)' }} onClick={onClose}>
    <div className="w-full bg-[#FAF6EC] rounded-t-3xl p-6 pb-10" onClick={(e) => e.stopPropagation()}>
      <div className="w-12 h-1 bg-[#E8E0CE] rounded-full mx-auto mb-5" />
      <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-semibold text-[#1F3D2E] mb-4">Ajouter</h3>
      <button onClick={onAddSpecies} className="w-full flex items-center gap-3 p-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE] mb-2 active:scale-[0.98]">
        <div className="w-10 h-10 rounded-full bg-[#1F3D2E] flex items-center justify-center">
          <BookOpen size={18} className="text-[#FFD66B]" />
        </div>
        <div className="flex-1 text-left">
          <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base font-semibold text-[#1F3D2E]">Une nouvelle espèce</p>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F]">Enrichir le Pokédex partagé</p>
        </div>
        <ChevronRight size={18} className="text-[#1F3D2E]" />
      </button>
      <button onClick={onAddRegion} className="w-full flex items-center gap-3 p-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE] active:scale-[0.98]">
        <div className="w-10 h-10 rounded-full bg-[#B8624A] flex items-center justify-center">
          <MapPin size={18} className="text-[#FAF6EC]" />
        </div>
        <div className="flex-1 text-left">
          <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base font-semibold text-[#1F3D2E]">Un nouveau territoire</p>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F]">Département à curater</p>
        </div>
        <ChevronRight size={18} className="text-[#1F3D2E]" />
      </button>
    </div>
  </div>
);

const AddSpeciesScreen = ({ onBack, editMode = false }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <ScreenHeader title={editMode ? "Modifier l'espèce" : "Nouvelle espèce"} subtitle={editMode ? 'Édition · Pokédex partagé' : 'Pokédex partagé'} onBack={onBack} />

    <div className="px-6 pb-8">
      {editMode && (
        <div className="mb-4 p-3 rounded-xl bg-[#F7E9C5] border-2 border-[#C49120] flex items-start gap-2">
          <AlertTriangle size={14} className="text-[#C49120] flex-shrink-0 mt-0.5" />
          <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[13px] text-[#2A1F15] leading-snug">Tu peux <span className="font-bold">ajouter</span> des territoires, mais pas en supprimer un où des observations sont déjà validées (les points sont gravés dans le marbre).</p>
        </div>
      )}

      <button className="w-full h-32 rounded-2xl border-2 border-dashed border-[#1F3D2E] bg-[#FAF6EC] flex flex-col items-center justify-center gap-2 mb-5 relative">
        {editMode ? (
          <>
            <div className="w-16 h-16 rounded-lg flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #E8E5DD 0%, #7A756950 100%)' }}><span className="text-3xl">🦅</span></div>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] uppercase tracking-wider font-bold">Toucher pour changer</p>
          </>
        ) : (
          <><Image size={28} className="text-[#1F3D2E]" /><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-[#1F3D2E] uppercase tracking-wider">Photo de référence</p></>
        )}
      </button>

      <div className="space-y-3">
        <div>
          <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Nom commun</label>
          <div className="mt-1 px-4 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE]" style={{ fontFamily: 'Cormorant Garamond, serif' }}>
            <span className={`text-base ${editMode ? 'text-[#1F3D2E] font-semibold' : 'text-[#6B5D4F] italic'}`}>{editMode ? 'Buse variable' : 'Ex: Pic noir'}</span>
          </div>
        </div>
        <div>
          <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Nom scientifique</label>
          <div className="mt-1 px-4 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE]" style={{ fontFamily: 'Cormorant Garamond, serif' }}>
            <span className={`text-base italic ${editMode ? 'text-[#B8624A]' : 'text-[#6B5D4F]'}`}>{editMode ? 'Buteo buteo' : 'Dryocopus martius'}</span>
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Catégorie</label>
            <div className="mt-1 px-3 py-3 rounded-xl bg-[#1F3D2E] border-2 border-[#1F3D2E] flex items-center justify-between">
              <span className="text-xl">🦅</span>
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-[#FAF6EC]">Oiseaux</span>
              <ChevronRight size={14} className="text-[#FAF6EC]" />
            </div>
          </div>
          <div>
            <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Sous-cat.</label>
            <div className="mt-1 px-3 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE] flex items-center justify-between">
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-semibold text-[#1F3D2E]">{editMode ? 'Rapaces diurnes' : 'Pics'}</span>
              <ChevronRight size={14} className="text-[#1F3D2E]" />
            </div>
          </div>
        </div>

        <div>
          <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Présence & rareté par territoire</label>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] italic mt-0.5 mb-2">La même espèce peut être commune ici, légendaire ailleurs</p>
          <div className="space-y-2">
            <div className="bg-[#FAF6EC] border-2 border-[#1F3D2E] rounded-xl p-3" style={{ boxShadow: '0 2px 6px -2px rgba(31, 61, 46, 0.15)' }}>
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <MapPin size={12} className="text-[#1F3D2E]" />
                  <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-sm font-semibold text-[#1F3D2E]">Oise <span className="text-[#B8624A] italic">(60)</span></span>
                  {editMode && <span className="px-1.5 py-0.5 rounded-full bg-[#1F3D2E] text-[#FFD66B]" style={{ fontFamily: 'Karla, sans-serif' }}><span className="text-[8px] font-bold uppercase tracking-wider">2 obs.</span></span>}
                </div>
                {editMode ? <Lock size={14} className="text-[#C49120]" /> : <button><X size={14} className="text-[#6B5D4F]" /></button>}
              </div>
              <div className="grid grid-cols-4 gap-1">
                {Object.entries(RARITY).map(([k, v], i) => (
                  <button key={k} className={`py-1.5 rounded-lg border-2 ${i === (editMode ? 0 : 1) ? '' : 'opacity-40'} ${editMode ? 'cursor-not-allowed' : ''}`} style={{ borderColor: v.color, backgroundColor: i === (editMode ? 0 : 1) ? v.bg : 'transparent' }}>
                    <p style={{ fontFamily: 'Karla, sans-serif', color: v.color }} className="text-[9px] uppercase tracking-wider font-bold">{v.label}</p>
                  </button>
                ))}
              </div>
              {editMode && <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#6B5D4F] italic mt-1.5">Rareté verrouillée — déjà observée ici</p>}
            </div>
            <div className="bg-[#FAF6EC] border-2 border-[#E8E0CE] rounded-xl p-3">
              <div className="flex items-center justify-between mb-2">
                <div className="flex items-center gap-2">
                  <MapPin size={12} className="text-[#1F3D2E]" />
                  <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-sm font-semibold text-[#1F3D2E]">Savoie <span className="text-[#B8624A] italic">(73)</span></span>
                  {editMode && <span className="px-1.5 py-0.5 rounded-full bg-[#B8624A]/15 text-[#B8624A]" style={{ fontFamily: 'Karla, sans-serif' }}><span className="text-[8px] font-bold uppercase tracking-wider">Nouveau</span></span>}
                </div>
                <button><X size={14} className="text-[#6B5D4F]" /></button>
              </div>
              <div className="grid grid-cols-4 gap-1">
                {Object.entries(RARITY).map(([k, v], i) => (
                  <button key={k} className={`py-1.5 rounded-lg border-2 ${i === 3 ? '' : 'opacity-40'}`} style={{ borderColor: v.color, backgroundColor: i === 3 ? v.bg : 'transparent', boxShadow: i === 3 ? `0 0 8px ${v.glow}` : 'none' }}>
                    <p style={{ fontFamily: 'Karla, sans-serif', color: v.color }} className="text-[9px] uppercase tracking-wider font-bold">{v.label}</p>
                  </button>
                ))}
              </div>
            </div>
          </div>
          <button className="w-full mt-2 py-2.5 rounded-xl border-2 border-dashed border-[#B8624A] flex items-center justify-center gap-1.5">
            <Plus size={12} className="text-[#B8624A]" />
            <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] font-bold text-[#B8624A] uppercase tracking-wider">Ajouter un territoire</span>
          </button>
        </div>

        <div>
          <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Description</label>
          <div className="mt-1 px-4 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE] h-20" style={{ fontFamily: 'Cormorant Garamond, serif' }}>
            <span className={`text-sm ${editMode ? 'text-[#2A1F15]' : 'text-[#6B5D4F] italic'}`}>{editMode ? 'Le rapace le plus visible en plaine. Posée sur piquet ou en vol plané.' : 'Habitat, comportement, signes distinctifs…'}</span>
          </div>
        </div>

        <button className="w-full mt-4 rounded-2xl py-4" style={{ background: 'linear-gradient(135deg, #1F3D2E 0%, #2D5A42 100%)', boxShadow: '0 6px 20px -4px rgba(31, 61, 46, 0.5)' }}>
          <span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#FAF6EC] uppercase tracking-wider text-sm">{editMode ? 'Enregistrer les modifications' : 'Ajouter au carnet'}</span>
        </button>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-center text-[10px] text-[#6B5D4F] mt-2 italic">{editMode ? 'Marine sera notifiée des changements' : 'Visible aussi par Marine'}</p>
      </div>
    </div>
  </div>
);

const AddRegionScreen = ({ onBack }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <ScreenHeader title="Nouveau territoire" subtitle="Étendre l'aventure" onBack={onBack} />

    <div className="px-6 pb-8">
      <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#2A1F15] leading-relaxed mb-5 italic">
        Choisis un département à explorer. Tu pourras ensuite curater la liste des espèces locales avec leurs raretés.
      </p>

      <div>
        <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Pays</label>
        <div className="mt-1 px-4 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE] flex items-center justify-between">
          <div className="flex items-center gap-2"><span className="text-base">🇫🇷</span><span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#1F3D2E] font-semibold">France</span></div>
          <ChevronRight size={16} className="text-[#1F3D2E]" />
        </div>
      </div>

      <div className="mt-4">
        <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Département</label>
        <div className="mt-1 px-4 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#1F3D2E] flex items-center justify-between" style={{ boxShadow: '0 4px 12px -4px rgba(31, 61, 46, 0.2)' }}>
          <div>
            <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-lg text-[#1F3D2E] font-semibold">Savoie</p>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F]">73 · Auvergne-Rhône-Alpes</p>
          </div>
          <ChevronRight size={16} className="text-[#1F3D2E]" />
        </div>
      </div>

      <div className="mt-4">
        <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Étiquette</label>
        <div className="mt-1 grid grid-cols-3 gap-2">
          {['Domicile', 'Vacances', 'Voyage'].map((t, i) => (
            <button key={t} className={`py-2.5 rounded-xl border-2 ${i === 1 ? 'bg-[#1F3D2E] border-[#1F3D2E]' : 'bg-[#FAF6EC] border-[#E8E0CE]'}`}>
              <p style={{ fontFamily: 'Karla, sans-serif' }} className={`text-xs font-bold ${i === 1 ? 'text-[#FAF6EC]' : 'text-[#6B5D4F]'}`}>{t}</p>
            </button>
          ))}
        </div>
      </div>

      <div className="mt-5 p-4 rounded-xl bg-[#F7E9C5] border-2 border-[#C49120]">
        <div className="flex items-start gap-2">
          <Sparkles size={14} className="text-[#C49120] mt-0.5 flex-shrink-0" fill="#C49120" />
          <div>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] font-bold text-[#1F3D2E] uppercase tracking-wider">Astuce</p>
            <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-sm text-[#2A1F15] mt-1 leading-snug">La Savoie ouvre l'accès aux espèces alpines : marmotte, chamois, gypaète. Pense aussi à ajouter des sous-catégories spécifiques.</p>
          </div>
        </div>
      </div>

      <button className="w-full mt-5 rounded-2xl py-4" style={{ background: 'linear-gradient(135deg, #B8624A 0%, #C68B5A 100%)', boxShadow: '0 6px 20px -4px #B8624A60' }}>
        <span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#FAF6EC] uppercase tracking-wider text-sm">Créer le territoire</span>
      </button>
      <button className="w-full mt-2 py-3">
        <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs text-[#6B5D4F] underline">Curater les espèces plus tard</span>
      </button>
    </div>
  </div>
);

const DepartmentScreen = ({ onBack, onSelectCategory }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <div className="px-6 pt-12 pb-2">
      <button onClick={onBack} className="mb-3 -ml-1 flex items-center gap-1 text-[#1F3D2E]"><ChevronLeft size={20} strokeWidth={2.5} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-sm font-semibold">Retour</span></button>
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.25em] text-[#B8624A] font-bold">Hauts-de-France · 60</p>
      <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[44px] leading-none font-semibold text-[#1F3D2E] mt-1">Oise</h1>
      <div className="flex items-center gap-3 mt-3">
        <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[#1F3D2E]"><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] font-bold text-[#FAF6EC]">8 / 71</span></div>
        <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs text-[#6B5D4F]">11% complété</span>
      </div>
    </div>

    <div className="px-6 mt-5 mb-3">
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Catégories — 4</p>
    </div>

    <div className="px-6 grid grid-cols-2 gap-3 mb-6">
      {CATEGORIES.map((cat) => (
        <button key={cat.id} onClick={() => onSelectCategory(cat.id)} className="relative bg-[#FAF6EC] rounded-2xl border-2 border-[#E8E0CE] p-4 text-left transition-all active:scale-95 hover:border-[#1F3D2E]" style={{ boxShadow: '0 2px 8px -2px rgba(31, 61, 46, 0.1)' }}>
          <div className="flex items-start justify-between mb-2">
            <span className="text-3xl">{cat.icon}</span>
            <div className="text-right">
              <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-semibold text-[#1F3D2E] leading-none">{cat.observed}</span>
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F]">/{cat.total}</span>
            </div>
          </div>
          <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-lg text-[#1F3D2E] font-semibold leading-tight mb-2">{cat.name}</h3>
          <ProgressBar value={cat.observed} max={cat.total} color="#B8624A" height={5} />
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#6B5D4F] mt-2 uppercase tracking-wider font-bold">{cat.total - cat.observed} à trouver</p>
        </button>
      ))}
    </div>
  </div>
);

const SpeciesListScreen = ({ category, onBack, onSelectSpecies }) => {
  const [activeSubcat, setActiveSubcat] = useState('all');
  const [filterMode, setFilterMode] = useState('all');
  const cat = CATEGORIES.find((c) => c.id === category);
  let filtered = SPECIES.filter((s) => s.cat === category && (activeSubcat === 'all' || s.subcat === activeSubcat));
  if (filterMode === 'observed') filtered = filtered.filter(s => s.observed);
  if (filterMode === 'mystery') filtered = filtered.filter(s => !s.observed);

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      <div className="px-6 pt-12 pb-2">
        <button onClick={onBack} className="mb-3 -ml-1 flex items-center gap-1 text-[#1F3D2E]"><ChevronLeft size={20} strokeWidth={2.5} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-sm font-semibold">Oise</span></button>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-4xl">{cat.icon}</span>
            <div>
              <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-3xl text-[#1F3D2E] font-semibold leading-none">{cat.name}</h1>
              <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] text-[#B8624A] mt-1 font-bold uppercase tracking-wider">{cat.observed} / {cat.total} découvertes</p>
            </div>
          </div>
        </div>
        <div className="mt-3 flex gap-1 bg-[#FAF6EC] border border-[#E8E0CE] rounded-full p-0.5">
          {[{ id: 'all', label: 'Tout' }, { id: 'observed', label: '✓ Vues' }, { id: 'mystery', label: 'Mystères' }].map(f => (
            <button key={f.id} onClick={() => setFilterMode(f.id)} className={`flex-1 py-1.5 rounded-full text-[11px] font-bold transition-colors ${filterMode === f.id ? 'bg-[#1F3D2E] text-[#FAF6EC]' : 'text-[#6B5D4F]'}`} style={{ fontFamily: 'Karla, sans-serif' }}>
              {f.label}
            </button>
          ))}
        </div>
      </div>

      <div className="relative mt-3">
        <div className="overflow-x-auto pb-2">
          <div className="flex gap-2 px-6 w-max">
            {cat.subcats.map((sc) => {
              const active = activeSubcat === sc.id;
              return (
                <button key={sc.id} onClick={() => setActiveSubcat(sc.id)} style={{ fontFamily: 'Karla, sans-serif', boxShadow: active ? '0 4px 10px -2px rgba(31, 61, 46, 0.4)' : 'none', transform: active ? 'scale(1.05)' : 'scale(1)' }} className={`px-3.5 py-2 rounded-full text-xs whitespace-nowrap font-bold uppercase tracking-wider transition-all ${
                  active ? 'bg-[#1F3D2E] text-[#FFD66B] border-2 border-[#1F3D2E]' : 'bg-transparent text-[#8B7B65] border-2 border-[#D5CDB8]'
                }`}>
                  {active && '● '}{sc.name}
                </button>
              );
            })}
          </div>
        </div>
        <div className="absolute top-0 right-0 bottom-2 w-8 pointer-events-none" style={{ background: 'linear-gradient(90deg, transparent 0%, #F5EDDF 100%)' }} />
      </div>

      <div className="px-6 mt-3 space-y-2 mb-6">
        {filtered.map((species) => {
          const r = RARITY[species.rarity];
          const isLegendary = species.rarity === 'legendaire';
          if (!species.observed) {
            return (
              <button key={species.id} onClick={() => onSelectSpecies(species.id)} className="w-full flex items-center gap-3 rounded-xl border-2 border-dashed p-3 text-left transition-all hover:scale-[1.01]" style={{ borderColor: r.color, backgroundColor: '#F0E8D2', boxShadow: isLegendary ? `0 0 16px ${r.glow}` : 'none' }}>
                <div className="w-14 h-14 rounded-lg flex-shrink-0 flex items-center justify-center relative overflow-hidden border-2 border-dashed" style={{ borderColor: r.color + '40', background: `linear-gradient(135deg, ${r.color}10 0%, ${r.color}25 100%)` }}>
                  <span className="text-2xl" style={{ filter: 'sepia(0.7) saturate(0.4) brightness(0.85)' }}>{cat.icon}</span>
                </div>
                <div className="flex-1 min-w-0">
                  <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#6B5D4F] font-semibold leading-tight truncate">{species.name}</h3>
                  <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] text-[#8B7B65] italic truncate">{species.sci}</p>
                  <div className="mt-1.5 flex items-center gap-1.5"><RarityBadge rarity={species.rarity} glow={isLegendary} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#B8624A] uppercase tracking-widest font-bold">À débusquer</span></div>
                </div>
                <ChevronRight size={16} className="text-[#6B5D4F] flex-shrink-0" />
              </button>
            );
          }
          return (
            <button key={species.id} onClick={() => onSelectSpecies(species.id)} className="w-full flex items-center gap-3 bg-[#FAF6EC] rounded-xl border-2 border-[#1F3D2E] p-3 text-left transition-all hover:scale-[1.01]" style={{ boxShadow: '0 2px 8px -2px rgba(31, 61, 46, 0.15)' }}>
              <div className="w-14 h-14 rounded-lg flex-shrink-0 flex items-center justify-center relative" style={{ background: `linear-gradient(135deg, ${r.bg} 0%, ${r.color}40 100%)` }}>
                <span className="text-2xl">{cat.icon}</span>
                <div className="absolute -top-1 -right-1 w-5 h-5 rounded-full bg-[#1F3D2E] flex items-center justify-center border-2 border-[#FAF6EC]"><Check size={10} className="text-[#FAF6EC]" strokeWidth={3.5} /></div>
              </div>
              <div className="flex-1 min-w-0">
                <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#1F3D2E] font-semibold leading-tight truncate">{species.name}</h3>
                <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] text-[#B8624A] italic truncate">{species.sci}</p>
                <div className="mt-1.5 flex items-center gap-1.5"><RarityBadge rarity={species.rarity} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F]">{species.observations?.length || 0} obs.</span></div>
              </div>
              <ChevronRight size={16} className="text-[#1F3D2E] flex-shrink-0" />
            </button>
          );
        })}
      </div>
    </div>
  );
};

const SpeciesDetailScreen = ({ speciesId, onBack, onObserve, onEdit }) => {
  const species = SPECIES.find((s) => s.id === speciesId) || SPECIES[1];
  const [observed, setObserved] = useState(species.observed);
  const r = RARITY[species.rarity];
  const cat = CATEGORIES.find((c) => c.id === species.cat);
  const isLegendary = species.rarity === 'legendaire';

  return (
    <div className="flex flex-col h-full overflow-y-auto">
      <div className="relative h-64 overflow-hidden" style={{ background: `linear-gradient(135deg, ${r.color} 0%, ${r.color}DD 100%)` }}>
        {isLegendary && <SparkleField />}
        <button onClick={onBack} className="absolute top-12 left-5 w-9 h-9 rounded-full bg-[#FAF6EC]/95 backdrop-blur flex items-center justify-center z-10"><ChevronLeft size={18} className="text-[#1F3D2E]" strokeWidth={2.5} /></button>
        <div className="absolute top-12 right-5 z-10 flex items-center gap-2">
          <button onClick={onEdit} className="w-9 h-9 rounded-full bg-[#FAF6EC]/95 backdrop-blur flex items-center justify-center"><Edit3 size={15} className="text-[#1F3D2E]" /></button>
          <RarityBadge rarity={species.rarity} size="md" glow={true} />
        </div>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="text-[120px]" style={!observed ? { filter: 'sepia(0.6) saturate(0.4) brightness(0.95)', opacity: 0.7 } : { opacity: 0.85 }}>{cat.icon}</span>
          {!observed && (<div className="absolute bottom-3 right-3 px-3 py-1 rounded-full bg-[#FAF6EC]/95 backdrop-blur border-2 border-dashed" style={{ borderColor: r.color }}><span style={{ fontFamily: 'Karla, sans-serif', color: r.color }} className="text-[10px] font-bold uppercase tracking-widest">À débusquer</span></div>)}
        </div>
        <div className="absolute bottom-0 left-0 right-0 h-12" style={{ background: 'linear-gradient(180deg, transparent 0%, #F5EDDF 100%)' }} />
      </div>

      <div className="px-6 pt-2 pb-8 flex-1">
        <div className="flex items-center gap-2 mb-1"><RarityStars rarity={species.rarity} size={12} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">{cat.name} · {species.subcat.replace('-', ' ')}</span></div>
        {observed ? (<><h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[34px] leading-tight font-semibold text-[#1F3D2E] mt-1">{species.name}</h1><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#B8624A] italic">{species.sci}</p></>)
        : (<><h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[34px] leading-tight font-semibold text-[#6B5D4F] mt-1">{species.name}</h1><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#8B7B65] italic">{species.sci}</p></>)}

        <div className="mt-4 grid grid-cols-3 gap-2">
          <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><div className="flex items-center justify-center gap-1 mb-1"><Sparkles size={12} className="text-[#C49120]" fill="#C49120" /><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-wider text-[#6B5D4F] font-bold">Points</p></div><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">+{r.points}</p></div>
          <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><Camera size={14} className="mx-auto text-[#B8624A] mb-1" /><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-wider text-[#6B5D4F] font-bold">Bonus photo</p><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">+50%</p></div>
          <div className="rounded-xl border-2 p-3 text-center" style={{ backgroundColor: observed ? '#1F3D2E' : '#FAF6EC', borderColor: observed ? '#1F3D2E' : '#E8E0CE' }}><Eye size={14} className={`mx-auto mb-1 ${observed ? 'text-[#FFD66B]' : 'text-[#6B5D4F]'}`} /><p style={{ fontFamily: 'Karla, sans-serif' }} className={`text-[9px] uppercase tracking-wider font-bold ${observed ? 'text-[#C4A572]' : 'text-[#6B5D4F]'}`}>Statut</p><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className={`text-base font-bold ${observed ? 'text-[#FAF6EC]' : 'text-[#6B5D4F]'}`}>{observed ? 'Vue ✓' : '—'}</p></div>
        </div>

        <div className="mt-4"><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold mb-2">{observed ? 'Description' : 'Fiche guide de terrain'}</p><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[15px] leading-relaxed text-[#2A1F15]">{species.desc}</p></div>

        {!observed && (
          <div className="mt-4 p-3 rounded-xl border-2 border-dashed flex items-start gap-2" style={{ borderColor: r.color, backgroundColor: r.bg + '60' }}>
            <Target size={14} style={{ color: r.color }} className="flex-shrink-0 mt-0.5" />
            <div>
              <p style={{ fontFamily: 'Karla, sans-serif', color: r.color }} className="text-[10px] uppercase tracking-widest font-bold">Pour la débusquer</p>
              <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-sm text-[#2A1F15] mt-0.5 leading-snug">Pars en lisière de forêt à l'aube ou au crépuscule, observe les piquets isolés en plaine. Patience et silence.</p>
            </div>
          </div>
        )}

        {observed && species.observations && (
          <div className="mt-5">
            <div className="flex items-center justify-between mb-1">
              <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Mes observations · {species.observations.length}</p>
            </div>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] italic mb-2">Points crédités à la première découverte. Les suivantes ajoutent un marqueur sur la carte.</p>
            <div className="space-y-2">
              {species.observations.map((obs, i) => {
                const isFirst = i === 0;
                const earned = isFirst ? (obs.photo ? Math.round(r.points * 1.5) : r.points) : 0;
                return (
                  <div key={i} className={`p-3 rounded-xl flex items-center gap-3 ${isFirst ? 'bg-[#1F3D2E]' : 'bg-[#FAF6EC] border-2 border-[#E8E0CE]'}`}>
                    <div className={`w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0 ${isFirst ? 'bg-[#FAF6EC]/10' : 'bg-[#1F3D2E]/10'}`}>{obs.photo ? <Camera size={16} className={isFirst ? 'text-[#FFD66B]' : 'text-[#1F3D2E]'} /> : <MapPin size={16} className={isFirst ? 'text-[#FFD66B]' : 'text-[#1F3D2E]'} />}</div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-1.5">
                        <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className={`text-sm font-semibold leading-tight truncate ${isFirst ? 'text-[#FAF6EC]' : 'text-[#1F3D2E]'}`}>{obs.place}</p>
                        {isFirst && <span className="px-1.5 py-0.5 rounded-full bg-[#FFD66B] flex-shrink-0" style={{ fontFamily: 'Karla, sans-serif' }}><span className="text-[8px] font-extrabold uppercase tracking-wider text-[#1F3D2E]">1ʳᵉ</span></span>}
                      </div>
                      <p style={{ fontFamily: 'Karla, sans-serif' }} className={`text-[11px] ${isFirst ? 'text-[#C4A572]' : 'text-[#6B5D4F]'}`}>{obs.date}{obs.photo && ' · 📸'}</p>
                    </div>
                    {earned > 0 ? (
                      <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-lg font-bold text-[#FFD66B]">+{earned}</span>
                    ) : (
                      <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] uppercase tracking-wider font-bold">Marqueur</span>
                    )}
                  </div>
                );
              })}

              {!species.observations.some(o => o.photo) && (
                <button className="w-full py-3 rounded-xl bg-[#F7E9C5] border-2 border-[#C49120] flex items-center justify-center gap-2" style={{ boxShadow: '0 4px 12px -4px #C4912040' }}>
                  <Camera size={14} className="text-[#C49120]" />
                  <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] font-extrabold text-[#1F3D2E] uppercase tracking-wider">Ajouter une photo · Bonus +{Math.round(r.points * 0.5)} pts</span>
                </button>
              )}

              <button className="w-full py-2.5 rounded-xl border-2 border-dashed border-[#1F3D2E] flex items-center justify-center gap-1.5"><Plus size={12} className="text-[#1F3D2E]" /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] font-bold text-[#1F3D2E] uppercase tracking-wider">Nouvelle observation (0 pt · marqueur)</span></button>
            </div>
          </div>
        )}

        {!observed && (<button onClick={() => onObserve(species)} className="mt-5 w-full rounded-2xl py-4 px-5 flex items-center justify-center gap-2 transition-all active:scale-95" style={{ background: `linear-gradient(135deg, ${r.color} 0%, ${r.color}DD 100%)`, boxShadow: `0 6px 20px -4px ${r.color}80` }}><Sparkles size={18} className="text-[#FAF6EC]" fill="#FFD66B" /><span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#FAF6EC] uppercase tracking-wider">Je l'ai vue !</span></button>)}
        {!observed && (<p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] text-center text-[#6B5D4F] mt-2 italic">Géolocalisation auto · photo proposée</p>)}
      </div>
    </div>
  );
};

// ========== OBSERVATION FLOW OVERLAYS ==========

const PhotoChoiceOverlay = ({ species, onSkip, onCapture, onEditMeta }) => {
  const r = RARITY[species.rarity];
  const withPhoto = Math.round(r.points * 1.5);
  return (
    <div className="absolute inset-0 z-50 flex items-end" style={{ background: 'rgba(31, 24, 13, 0.6)' }}>
      <div className="w-full bg-[#FAF6EC] rounded-t-3xl p-6 pb-10">
        <div className="w-12 h-1 bg-[#E8E0CE] rounded-full mx-auto mb-5" />
        <div className="text-center mb-4">
          <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-semibold text-[#1F3D2E]">Une photo souvenir ?</h3>
        </div>

        <button onClick={onEditMeta} className="w-full mb-4 p-3 rounded-xl bg-[#FAF6EC] border-2 border-[#E8E0CE] flex items-center gap-2.5 active:scale-[0.99]">
          <div className="w-8 h-8 rounded-full bg-[#1F3D2E] flex items-center justify-center flex-shrink-0"><MapPin size={14} className="text-[#FFD66B]" /></div>
          <div className="flex-1 text-left min-w-0">
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-widest text-[#6B5D4F] font-bold">Détectée auto</p>
            <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-sm text-[#1F3D2E] font-semibold truncate">Compiègne · aujourd'hui 14:32</p>
          </div>
          <Edit3 size={14} className="text-[#1F3D2E] flex-shrink-0" />
        </button>

        <button onClick={onCapture} className="w-full rounded-2xl py-4 mb-2 flex items-center justify-center gap-2" style={{ background: 'linear-gradient(135deg, #C49120 0%, #B8624A 100%)', boxShadow: '0 6px 20px -4px #C4912070' }}>
          <Camera size={18} className="text-[#FAF6EC]" />
          <div className="flex flex-col items-start">
            <span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#FAF6EC] uppercase tracking-wider text-sm leading-none">Prendre une photo</span>
            <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#FFD66B] mt-0.5">+{withPhoto} pts · bonus +50%</span>
          </div>
        </button>
        <button onClick={onSkip} className="w-full rounded-2xl py-3.5 border-2 border-[#1F3D2E] flex flex-col items-center">
          <span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#1F3D2E] uppercase tracking-wider text-sm leading-none">Sans photo</span>
          <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] mt-0.5">+{r.points} pts</span>
        </button>
      </div>
    </div>
  );
};

const EditMetaOverlay = ({ onClose }) => (
  <div className="absolute inset-0 z-50 flex items-end" style={{ background: 'rgba(31, 24, 13, 0.6)' }}>
    <div className="w-full bg-[#FAF6EC] rounded-t-3xl p-6 pb-8">
      <div className="w-12 h-1 bg-[#E8E0CE] rounded-full mx-auto mb-5" />
      <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-semibold text-[#1F3D2E] mb-1">Préciser le moment</h3>
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] text-[#6B5D4F] italic mb-5">Pour saisir une observation passée</p>

      <div className="mb-3">
        <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Date d'observation</label>
        <div className="mt-1 px-4 py-3 rounded-xl bg-[#FAF6EC] border-2 border-[#1F3D2E] flex items-center justify-between">
          <div className="flex items-center gap-2"><Calendar size={14} className="text-[#1F3D2E]" /><span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#1F3D2E] font-semibold">7 mai 2026 · 14:32</span></div>
          <ChevronRight size={14} className="text-[#1F3D2E]" />
        </div>
      </div>

      <div className="mb-4">
        <label style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Lieu d'observation</label>
        <div className="mt-1 rounded-xl border-2 border-[#1F3D2E] overflow-hidden">
          <div className="h-32 relative" style={{ background: 'linear-gradient(180deg, #E5DDC6 0%, #D8CFAE 100%)' }}>
            <svg viewBox="0 0 300 130" className="w-full h-full">
              <defs><pattern id="topo2" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M 0 10 Q 5 7 10 10 T 20 10" fill="none" stroke="#1F3D2E" strokeWidth="0.4" opacity="0.2" /></pattern></defs>
              <rect width="300" height="130" fill="url(#topo2)" />
              <path d="M 0 70 Q 100 60 180 80 T 300 90" fill="none" stroke="#2D6E8C" strokeWidth="2" opacity="0.5" />
              <g transform="translate(150, 65)">
                <circle r="14" fill="#B8624A" opacity="0.3"><animate attributeName="r" values="14;22;14" dur="2s" repeatCount="indefinite" /></circle>
                <circle r="6" fill="#B8624A" stroke="#FAF6EC" strokeWidth="2" />
              </g>
            </svg>
            <div className="absolute bottom-2 left-2 right-2 px-2.5 py-1.5 rounded-full bg-[#FAF6EC]/95 backdrop-blur flex items-center gap-2 border border-[#1F3D2E]/30"><Target size={10} className="text-[#1F3D2E]" /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] font-bold text-[#1F3D2E] uppercase tracking-wider">Tap pour repositionner le marqueur</span></div>
          </div>
        </div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] italic mt-1.5 text-center">📍 Forêt de Compiègne · 49.4179°N 2.8328°E</p>
      </div>

      <button onClick={onClose} className="w-full rounded-2xl py-3.5" style={{ background: 'linear-gradient(135deg, #1F3D2E 0%, #2D5A42 100%)' }}>
        <span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#FAF6EC] uppercase tracking-wider text-sm">Confirmer</span>
      </button>
    </div>
  </div>
);

const PhotoCaptureOverlay = ({ onValidate, onCancel }) => {
  const [captured, setCaptured] = useState(false);
  return (
    <div className="absolute inset-0 z-50 bg-black flex flex-col">
      <div className="flex-1 relative" style={{ background: captured ? 'linear-gradient(135deg, #2D5A42 0%, #1F3D2E 100%)' : 'radial-gradient(circle at center, #3D2F1F 0%, #1A1208 100%)' }}>
        {!captured && (
          <>
            <button onClick={onCancel} className="absolute top-12 left-5 w-9 h-9 rounded-full bg-black/40 backdrop-blur flex items-center justify-center"><X size={18} className="text-white" /></button>
            <div className="absolute inset-12 border-2 border-white/30 rounded-3xl" />
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"><Camera size={64} className="text-white/40" /></div>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="absolute bottom-32 left-0 right-0 text-center text-xs text-white/60 italic">Cadre l'animal au centre</p>
          </>
        )}
        {captured && (
          <div className="absolute inset-0 flex items-center justify-center">
            <span className="text-[180px] opacity-90">🦅</span>
          </div>
        )}
      </div>
      <div className="bg-black p-6 pb-10 flex items-center justify-center gap-6">
        {!captured ? (
          <button onClick={() => setCaptured(true)} className="w-20 h-20 rounded-full bg-white border-4 border-white/30 active:scale-95 transition-transform" />
        ) : (
          <>
            <button onClick={() => setCaptured(false)} className="px-5 py-3 rounded-full bg-white/10"><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-white uppercase tracking-wider">Reprendre</span></button>
            <button onClick={onValidate} className="px-6 py-3 rounded-full" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)' }}><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-[#1F3D2E] uppercase tracking-wider">Valider</span></button>
          </>
        )}
      </div>
    </div>
  );
};

const DiscoveryOverlay = ({ species, withPhoto, onClose }) => {
  const [stage, setStage] = useState(0);
  const [points, setPoints] = useState(0);
  const r = RARITY[species.rarity];
  const cat = CATEGORIES.find((c) => c.id === species.cat);
  const finalPoints = withPhoto ? Math.round(r.points * 1.5) : r.points;

  useEffect(() => {
    const t1 = setTimeout(() => setStage(1), 300);
    const t2 = setTimeout(() => setStage(2), 1000);
    const t3 = setTimeout(() => {
      setStage(3);
      let curr = 0;
      const intv = setInterval(() => { curr += Math.ceil(finalPoints / 25); if (curr >= finalPoints) { curr = finalPoints; clearInterval(intv); } setPoints(curr); }, 40);
    }, 1500);
    const t4 = setTimeout(() => setStage(4), 2500);
    return () => { clearTimeout(t1); clearTimeout(t2); clearTimeout(t3); clearTimeout(t4); };
  }, [finalPoints]);

  return (
    <div className="absolute inset-0 z-50 flex flex-col items-center justify-center" style={{ background: 'radial-gradient(circle at center, #1F3D2EE0 0%, #0A0F0BF5 100%)' }}>
      <SparkleField />
      <div className="absolute inset-0" style={{ background: `radial-gradient(circle at center, ${r.glow} 0%, transparent 60%)`, opacity: stage >= 2 ? 1 : 0, transition: 'opacity 0.6s' }} />
      <div className="relative z-10 px-6 w-full">
        <div className="text-center mb-5" style={{ opacity: stage >= 1 ? 1 : 0, transform: stage >= 1 ? 'translateY(0)' : 'translateY(-20px)', transition: 'all 0.6s' }}>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.4em] text-[#FFD66B] font-bold">★ Nouvelle découverte ★</p>
        </div>
        <div className="relative mx-auto rounded-2xl p-5 mb-5" style={{ background: `linear-gradient(135deg, ${r.color} 0%, ${r.color}CC 100%)`, boxShadow: `0 0 60px ${r.glow}, 0 20px 40px -10px ${r.color}80`, border: `3px solid ${r.color === '#C49120' ? '#FFD66B' : r.color}`, opacity: stage >= 2 ? 1 : 0, transform: stage >= 2 ? 'scale(1) rotate(0deg)' : 'scale(0.6) rotate(-8deg)', transition: 'all 0.7s cubic-bezier(0.34, 1.56, 0.64, 1)' }}>
          <div className="text-center">
            <RarityBadge rarity={species.rarity} size="lg" glow={true} />
            <div className="my-4 text-[90px] leading-none">{cat.icon}</div>
            <h2 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[28px] font-bold text-[#FAF6EC] leading-tight">{species.name}</h2>
            <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-sm text-[#FAF6EC]/80 italic mt-1">{species.sci}</p>
            <div className="mt-3 flex justify-center"><RarityStars rarity={species.rarity} size={14} /></div>
            {withPhoto && <div className="mt-3 inline-flex items-center gap-1 px-2 py-1 rounded-full bg-[#FAF6EC]/20"><Camera size={10} className="text-[#FAF6EC]" /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] font-bold text-[#FAF6EC] uppercase tracking-wider">Photo + 50%</span></div>}
          </div>
        </div>
        <div className="text-center" style={{ opacity: stage >= 3 ? 1 : 0, transform: stage >= 3 ? 'translateY(0)' : 'translateY(20px)', transition: 'all 0.5s' }}>
          <div className="inline-flex items-baseline gap-2 px-5 py-2.5 rounded-full mb-4" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)', boxShadow: '0 0 30px #FFD66B70' }}>
            <Sparkles size={18} className="text-[#1F3D2E]" fill="#1F3D2E" />
            <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">+{points}</span>
            <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs font-bold text-[#1F3D2E] uppercase tracking-wider">pts</span>
          </div>
        </div>
        <div className="text-center" style={{ opacity: stage >= 4 ? 1 : 0, transform: stage >= 4 ? 'translateY(0)' : 'translateY(20px)', transition: 'all 0.5s 0.1s' }}>
          <button onClick={onClose} className="px-7 py-2.5 rounded-full bg-[#FAF6EC] text-[#1F3D2E]"><span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold uppercase tracking-wider text-xs">Continuer la chasse</span></button>
        </div>
      </div>
    </div>
  );
};

const BadgeUnlockOverlay = ({ onClose }) => {
  const [stage, setStage] = useState(0);
  useEffect(() => { const t = setTimeout(() => setStage(1), 300); const t2 = setTimeout(() => setStage(2), 1200); return () => { clearTimeout(t); clearTimeout(t2); }; }, []);
  return (
    <div className="absolute inset-0 z-50 flex flex-col items-center justify-center" style={{ background: 'radial-gradient(circle at center, #1F3D2EF0 0%, #0A0F0BF8 100%)' }}>
      <SparkleField />
      <div className="absolute inset-0" style={{ background: 'radial-gradient(circle at center, #FFD66B40 0%, transparent 60%)' }} />
      <div className="relative z-10 px-8 text-center">
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.4em] text-[#FFD66B] font-bold mb-6" style={{ opacity: stage >= 1 ? 1 : 0, transition: 'opacity 0.5s' }}>✦ Badge déverrouillé ✦</p>
        <div className="relative mx-auto mb-6" style={{ width: '180px', height: '180px', opacity: stage >= 1 ? 1 : 0, transform: stage >= 1 ? 'scale(1) rotate(0deg)' : 'scale(0.5) rotate(-15deg)', transition: 'all 0.7s cubic-bezier(0.34, 1.56, 0.64, 1)' }}>
          <div className="absolute inset-0 rounded-full" style={{ background: 'conic-gradient(from 0deg, #FFD66B, #C49120, #FFD66B, #C49120, #FFD66B)', animation: 'spin 8s linear infinite' }} />
          <div className="absolute inset-2 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)', boxShadow: '0 0 40px #FFD66B' }}>
            <Award size={80} className="text-[#1F3D2E]" strokeWidth={2.2} />
          </div>
        </div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-widest text-[#C4A572] font-bold" style={{ opacity: stage >= 2 ? 1 : 0, transform: stage >= 2 ? 'translateY(0)' : 'translateY(15px)', transition: 'all 0.5s' }}>Sous-catégorie · Rapaces nocturnes</p>
        <h2 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[36px] font-semibold text-[#FAF6EC] leading-tight mt-1" style={{ opacity: stage >= 2 ? 1 : 0, transform: stage >= 2 ? 'translateY(0)' : 'translateY(15px)', transition: 'all 0.5s 0.1s' }}>Amateur des nuits</h2>
        <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#C4A572] italic mt-2" style={{ opacity: stage >= 2 ? 1 : 0, transition: 'opacity 0.5s 0.2s' }}>3 espèces de rapaces nocturnes observées</p>
        <button onClick={onClose} className="mt-8 px-7 py-2.5 rounded-full bg-[#FAF6EC]" style={{ opacity: stage >= 2 ? 1 : 0, transition: 'opacity 0.5s 0.3s' }}><span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#1F3D2E] uppercase tracking-wider text-xs">Magnifique</span></button>
      </div>
    </div>
  );
};

const ObservationsMapScreen = () => (
  <div className="flex flex-col h-full">
    <div className="px-6 pt-12 pb-3">
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.25em] text-[#B8624A] font-bold">Carnet géographique</p>
      <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[32px] leading-tight font-semibold text-[#1F3D2E]">Mes observations</h1>
    </div>
    <div className="px-6 mb-3 overflow-x-auto"><div className="flex gap-2 w-max">{['Toutes', 'Oiseaux', 'Mammifères', 'Reptiles', 'Chiroptères'].map((f, i) => (<button key={f} style={{ fontFamily: 'Karla, sans-serif' }} className={`px-3 py-1.5 rounded-full text-xs whitespace-nowrap font-semibold ${i === 0 ? 'bg-[#1F3D2E] text-[#FAF6EC]' : 'bg-[#FAF6EC] text-[#6B5D4F] border border-[#E8E0CE]'}`}>{f}</button>))}</div></div>
    <div className="flex-1 mx-6 mb-4 rounded-2xl overflow-hidden border-2 border-[#1F3D2E] relative" style={{ background: 'linear-gradient(180deg, #E5DDC6 0%, #D8CFAE 100%)' }}>
      <svg viewBox="0 0 300 400" className="w-full h-full">
        <defs><pattern id="topomap" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse"><path d="M 0 10 Q 5 7 10 10 T 20 10" fill="none" stroke="#1F3D2E" strokeWidth="0.4" opacity="0.2" /><path d="M 0 18 Q 5 15 10 18 T 20 18" fill="none" stroke="#1F3D2E" strokeWidth="0.4" opacity="0.2" /><path d="M 0 2 Q 5 -1 10 2 T 20 2" fill="none" stroke="#1F3D2E" strokeWidth="0.4" opacity="0.2" /></pattern></defs>
        <rect width="300" height="400" fill="url(#topomap)" />
        <path d="M 0 200 Q 80 180 150 220 T 300 240" fill="none" stroke="#2D6E8C" strokeWidth="2.5" opacity="0.5" />
        <path d="M 100 0 Q 130 100 110 200 T 140 400" fill="none" stroke="#2D6E8C" strokeWidth="2" opacity="0.4" />
        {[{ x: 80, y: 120, r: 'commun' }, { x: 95, y: 145, r: 'commun' }, { x: 160, y: 100, r: 'rare' }, { x: 220, y: 180, r: 'commun' }, { x: 130, y: 280, r: 'epique' }, { x: 75, y: 250, r: 'rare' }, { x: 200, y: 310, r: 'commun' }, { x: 180, y: 230, r: 'legendaire' }].map((m, i) => (
          <g key={i}><circle cx={m.x} cy={m.y} r="14" fill={RARITY[m.r].color} opacity="0.25" /><circle cx={m.x} cy={m.y} r="7" fill={RARITY[m.r].color} stroke="#FAF6EC" strokeWidth="2.5" />{m.r === 'legendaire' && <circle cx={m.x} cy={m.y} r="20" fill="none" stroke={RARITY[m.r].color} strokeWidth="1.5"><animate attributeName="r" values="14;28;14" dur="2s" repeatCount="indefinite" /><animate attributeName="opacity" values="0.8;0;0.8" dur="2s" repeatCount="indefinite" /></circle>}</g>
        ))}
        <g transform="translate(150, 200)"><circle r="22" fill="#1F3D2E" opacity="0.2"><animate attributeName="r" values="22;34;22" dur="2.5s" repeatCount="indefinite" /></circle><circle r="9" fill="#1F3D2E" stroke="#FAF6EC" strokeWidth="3" /></g>
      </svg>
      <div className="absolute bottom-3 left-3 right-3 bg-[#FAF6EC]/95 backdrop-blur rounded-xl border-2 border-[#1F3D2E] p-2.5 flex justify-around">{Object.entries(RARITY).map(([k, v]) => (<div key={k} className="flex items-center gap-1.5"><div className="w-3 h-3 rounded-full" style={{ backgroundColor: v.color, boxShadow: k === 'legendaire' ? `0 0 8px ${v.glow}` : 'none' }} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#2A1F15] font-semibold">{v.label}</span></div>))}</div>
    </div>
    <div className="px-6 mb-4 grid grid-cols-3 gap-2">
      <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">12</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#6B5D4F] uppercase tracking-wider font-bold">Obs.</p></div>
      <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">3</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#6B5D4F] uppercase tracking-wider font-bold">Lieux</p></div>
      <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">7</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#6B5D4F] uppercase tracking-wider font-bold">Jours</p></div>
    </div>
  </div>
);

const ProfileScreen = ({ onOpenSettings, onOpenMarine }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <div className="px-6 pt-12 pb-3 flex items-start justify-between">
      <div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.25em] text-[#B8624A] font-bold">Naturaliste</p>
        <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[32px] leading-tight font-semibold text-[#1F3D2E]">Léo</h1>
      </div>
      <button onClick={onOpenSettings} className="w-9 h-9 rounded-full bg-[#FAF6EC] border-2 border-[#1F3D2E] flex items-center justify-center"><Settings size={16} className="text-[#1F3D2E]" /></button>
    </div>

    <div className="mx-6 mb-5 p-5 rounded-2xl relative overflow-hidden" style={{ background: 'linear-gradient(135deg, #1F3D2E 0%, #2D5A42 60%, #1F3D2E 100%)', boxShadow: '0 8px 24px -8px rgba(31, 61, 46, 0.5)' }}>
      <div className="absolute -top-4 -right-4 text-[120px] opacity-10 leading-none">🦌</div>
      <div className="relative">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-14 h-14 rounded-full flex items-center justify-center flex-shrink-0" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)', boxShadow: '0 0 20px #FFD66B60' }}><span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">4</span></div>
          <div className="min-w-0 flex-1">
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-[0.18em] text-[#C4A572] font-bold truncate">Niveau 4 · Pisteur</p>
            <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-lg text-[#FAF6EC] leading-tight">1&nbsp;247 / 1&nbsp;600 pts</p>
          </div>
        </div>
        <ProgressBar value={1247} max={1600} color="#FFD66B" height={10} />
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#C4A572] mt-2 uppercase tracking-wider font-bold">Niveau 5 dans 353 pts</p>
      </div>
    </div>

    <div className="px-6 mb-5 grid grid-cols-3 gap-2">
      <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">8</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-wider text-[#6B5D4F] font-bold">Espèces</p></div>
      <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">12</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-wider text-[#6B5D4F] font-bold">Obs.</p></div>
      <div className="bg-[#FAF6EC] rounded-xl border-2 border-[#E8E0CE] p-3 text-center"><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">5</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-wider text-[#6B5D4F] font-bold">Photos</p></div>
    </div>

    <div className="px-6 mb-3"><div className="flex items-center justify-between"><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Mes badges</p><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#B8624A] font-bold">3 / 17</p></div></div>
    <div className="px-6 mb-3 grid grid-cols-2 gap-2">
      {BADGES.map((b) => (
        <div key={b.id} className={`relative rounded-xl border-2 p-3 ${b.earned ? 'bg-[#FAF6EC] border-[#C49120]' : 'bg-[#FAF6EC]/60 border-[#E8E0CE] border-dashed'}`} style={b.earned ? { boxShadow: '0 4px 12px -4px #C4912040' } : {}}>
          <div className="w-11 h-11 rounded-full flex items-center justify-center mb-2 relative" style={{ background: b.earned ? 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)' : '#E8E0CE', boxShadow: b.earned ? '0 0 12px #FFD66B40' : 'none' }}>{b.earned ? <Award size={20} className="text-[#1F3D2E]" strokeWidth={2.5} /> : <Lock size={16} className="text-[#6B5D4F]" />}</div>
          <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] uppercase tracking-wider text-[#6B5D4F] font-bold">{b.subcat}</p>
          <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className={`text-sm font-semibold leading-tight mt-0.5 ${b.earned ? 'text-[#1F3D2E]' : 'text-[#6B5D4F] italic'}`}>{b.name}</p>
          <div className="mt-2"><ProgressBar value={b.progress} max={b.total} color={b.earned ? '#C49120' : '#B8624A'} height={4} /></div>
          {!b.earned && <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[9px] text-[#6B5D4F] mt-1 italic">{b.progress} / {b.total}</p>}
        </div>
      ))}
    </div>

    <button onClick={onOpenMarine} className="mx-6 my-5 p-4 rounded-2xl bg-[#FAF6EC] border-2 border-[#E8E0CE] active:scale-[0.98] transition-transform">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #B8624A 0%, #C68B5A 100%)' }}><span className="text-base">🐾</span></div>
          <div className="text-left">
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-wider text-[#6B5D4F] font-bold">Mon binôme</p>
            <p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-base text-[#1F3D2E] font-semibold">Marine · Niveau 3 · 12 espèces</p>
          </div>
        </div>
        <ChevronRight size={18} className="text-[#1F3D2E]" />
      </div>
    </button>
  </div>
);

const MarineProfileScreen = ({ onBack }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <div className="px-6 pt-12 pb-3">
      <button onClick={onBack} className="mb-3 -ml-1 flex items-center gap-1 text-[#1F3D2E]"><ChevronLeft size={20} strokeWidth={2.5} /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-sm font-semibold">Profil</span></button>
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] uppercase tracking-[0.25em] text-[#B8624A] font-bold">Naturaliste · Binôme</p>
      <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-[32px] leading-tight font-semibold text-[#1F3D2E]">Marine</h1>
    </div>

    <div className="mx-6 mb-5 p-5 rounded-2xl relative overflow-hidden" style={{ background: 'linear-gradient(135deg, #B8624A 0%, #C68B5A 60%, #B8624A 100%)', boxShadow: '0 8px 24px -8px rgba(184, 98, 74, 0.5)' }}>
      <div className="absolute -top-4 -right-4 text-[120px] opacity-10 leading-none">🐾</div>
      <div className="relative">
        <div className="flex items-center gap-3 mb-3"><div className="w-14 h-14 rounded-full flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #FFD66B 0%, #C49120 100%)' }}><span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-2xl font-bold text-[#1F3D2E]">3</span></div><div><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#FAF6EC]/70 font-bold">Niveau 3 · Apprentie</p><p style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-xl text-[#FAF6EC] leading-tight">945 / 1 600 pts</p></div></div>
        <ProgressBar value={945} max={1600} color="#FAF6EC" height={10} />
      </div>
    </div>

    <div className="px-6 mb-3"><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Comparatif</p></div>
    <div className="px-6 mb-5">
      <div className="bg-[#FAF6EC] rounded-2xl border-2 border-[#E8E0CE] overflow-hidden">
        {[{ label: 'Espèces vues', a: 8, b: 12 }, { label: 'Observations', a: 12, b: 18 }, { label: 'Légendaires', a: 0, b: 1 }, { label: 'Badges', a: 3, b: 5 }].map((row, i) => (
          <div key={i} className={`flex items-center px-4 py-3 ${i > 0 ? 'border-t border-[#E8E0CE]' : ''}`}>
            <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className={`text-2xl font-bold w-12 text-right ${row.a > row.b ? 'text-[#1F3D2E]' : 'text-[#6B5D4F]'}`}>{row.a}</span>
            <span style={{ fontFamily: 'Karla, sans-serif' }} className="flex-1 text-center text-[10px] uppercase tracking-wider text-[#6B5D4F] font-bold">{row.label}</span>
            <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className={`text-2xl font-bold w-12 ${row.b > row.a ? 'text-[#B8624A]' : 'text-[#6B5D4F]'}`}>{row.b}</span>
          </div>
        ))}
        <div className="flex items-center px-4 py-2 bg-[#1F3D2E]"><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] font-bold text-[#FAF6EC] uppercase tracking-wider w-12 text-right">Toi</span><span className="flex-1" /><span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] font-bold text-[#FFB870] uppercase tracking-wider w-12">Marine</span></div>
      </div>
    </div>

    <div className="px-6 mb-3"><p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold">Sa dernière trouvaille</p></div>
    <div className="px-6 mb-6">
      <div className="bg-[#FAF6EC] rounded-2xl border-2 border-[#C49120] p-4 relative overflow-hidden" style={{ boxShadow: '0 0 16px #FFC04030' }}>
        <div className="flex items-center gap-3">
          <div className="w-14 h-14 rounded-lg flex items-center justify-center" style={{ background: 'linear-gradient(135deg, #F7E9C5 0%, #C4912040 100%)' }}><span className="text-2xl">🦡</span></div>
          <div className="flex-1">
            <RarityBadge rarity="legendaire" glow={true} />
            <h3 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-lg text-[#1F3D2E] font-semibold mt-1">Blaireau européen</h3>
            <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#6B5D4F] italic">il y a 2 jours · Forêt d'Halatte</p>
          </div>
        </div>
      </div>
    </div>
  </div>
);

const SettingsScreen = ({ onBack }) => (
  <div className="flex flex-col h-full overflow-y-auto">
    <ScreenHeader title="Réglages" subtitle="Compte & app" onBack={onBack} />
    <div className="px-6 pb-8 space-y-5">
      <div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold mb-2">Compte</p>
        <div className="bg-[#FAF6EC] rounded-2xl border-2 border-[#E8E0CE] overflow-hidden">
          {[{ icon: User, label: 'Profil & pseudo', value: 'Léo' }, { icon: Bell, label: 'Notifications', value: 'Activées' }, { icon: Users, label: 'Mon binôme', value: 'Marine' }].map((it, i) => (
            <button key={i} className={`w-full flex items-center gap-3 px-4 py-3.5 ${i > 0 ? 'border-t border-[#E8E0CE]' : ''}`}>
              <it.icon size={18} className="text-[#1F3D2E]" />
              <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="flex-1 text-left text-base text-[#1F3D2E] font-semibold">{it.label}</span>
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs text-[#6B5D4F]">{it.value}</span>
              <ChevronRight size={14} className="text-[#6B5D4F]" />
            </button>
          ))}
        </div>
      </div>
      <div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold mb-2">Application</p>
        <div className="bg-[#FAF6EC] rounded-2xl border-2 border-[#E8E0CE] overflow-hidden">
          {[{ icon: Palette, label: 'Style de carte', value: 'Outdoors' }, { icon: Database, label: 'Données hors-ligne', value: '12 Mo' }, { icon: MapPin, label: 'Géolocalisation', value: 'Précise' }].map((it, i) => (
            <button key={i} className={`w-full flex items-center gap-3 px-4 py-3.5 ${i > 0 ? 'border-t border-[#E8E0CE]' : ''}`}>
              <it.icon size={18} className="text-[#1F3D2E]" />
              <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="flex-1 text-left text-base text-[#1F3D2E] font-semibold">{it.label}</span>
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs text-[#6B5D4F]">{it.value}</span>
              <ChevronRight size={14} className="text-[#6B5D4F]" />
            </button>
          ))}
        </div>
      </div>
      <div>
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-widest text-[#6B5D4F] font-bold mb-2">À propos</p>
        <div className="bg-[#FAF6EC] rounded-2xl border-2 border-[#E8E0CE] overflow-hidden">
          {[{ icon: Info, label: 'Version', value: '0.1.0 · MVP' }, { icon: BookOpen, label: 'Crédits', value: '' }].map((it, i) => (
            <button key={i} className={`w-full flex items-center gap-3 px-4 py-3.5 ${i > 0 ? 'border-t border-[#E8E0CE]' : ''}`}>
              <it.icon size={18} className="text-[#1F3D2E]" />
              <span style={{ fontFamily: 'Cormorant Garamond, serif' }} className="flex-1 text-left text-base text-[#1F3D2E] font-semibold">{it.label}</span>
              <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-xs text-[#6B5D4F]">{it.value}</span>
              <ChevronRight size={14} className="text-[#6B5D4F]" />
            </button>
          ))}
        </div>
      </div>
      <button className="w-full rounded-2xl py-3.5 border-2 border-[#B8624A] flex items-center justify-center gap-2"><LogOut size={16} className="text-[#B8624A]" /><span style={{ fontFamily: 'Karla, sans-serif' }} className="font-bold text-[#B8624A] uppercase tracking-wider text-sm">Se déconnecter</span></button>
    </div>
  </div>
);

// ========== BOTTOM NAV ==========

const BottomNav = ({ tab, onChange, hidden }) => {
  if (hidden) return null;
  const tabs = [{ id: 'explore', icon: Compass, label: 'Explorer' }, { id: 'map', icon: MapIcon, label: 'Carnet' }, { id: 'profile', icon: User, label: 'Profil' }];
  return (
    <div className="absolute bottom-0 left-0 right-0 bg-[#FAF6EC] border-t border-[#E8E0CE] flex">
      {tabs.map((t) => {
        const Icon = t.icon;
        const active = tab === t.id;
        return (
          <button key={t.id} onClick={() => onChange(t.id)} className="flex-1 py-3 flex flex-col items-center gap-1 relative">
            <Icon size={22} className={active ? 'text-[#1F3D2E]' : 'text-[#A89B86]'} strokeWidth={active ? 2.4 : 1.8} fill={active ? '#1F3D2E' : 'none'} fillOpacity={active ? 0.12 : 0} />
            <span style={{ fontFamily: 'Karla, sans-serif' }} className={`text-[10px] tracking-wide ${active ? 'text-[#1F3D2E] font-bold' : 'text-[#A89B86] font-medium'}`}>
              {t.label}
            </span>
            {active && <div className="w-1 h-1 rounded-full bg-[#1F3D2E] absolute bottom-1.5" />}
          </button>
        );
      })}
    </div>
  );
};

// ========== APP ==========

export default function App() {
  const [view, setView] = useState({ name: 'login' });
  const [tab, setTab] = useState('explore');
  const [drillStack, setDrillStack] = useState([]);
  const [overlay, setOverlay] = useState(null); // { type: 'add-menu'|'photo-choice'|'photo-capture'|'discovery'|'badge', species? }

  const drillTo = (item) => setDrillStack([...drillStack, item]);
  const drillBack = () => setDrillStack(drillStack.slice(0, -1));
  const switchTab = (newTab) => { setTab(newTab); setDrillStack([]); setView({ name: 'main' }); };
  const goTo = (name) => setView({ name });

  let screen;
  if (view.name === 'login') screen = <LoginScreen onLogin={() => setView({ name: 'main' })} />;
  else if (view.name === 'add-species') screen = <AddSpeciesScreen onBack={() => setView({ name: 'main' })} />;
  else if (view.name === 'edit-species') screen = <AddSpeciesScreen onBack={() => setView({ name: 'main' })} editMode={true} />;
  else if (view.name === 'add-region') screen = <AddRegionScreen onBack={() => setView({ name: 'main' })} />;
  else if (view.name === 'settings') screen = <SettingsScreen onBack={() => setView({ name: 'main' })} />;
  else if (view.name === 'marine') screen = <MarineProfileScreen onBack={() => setView({ name: 'main' })} />;
  else {
    if (tab === 'explore') {
      if (drillStack.length === 0) screen = <HomeScreen onSelectDept={(d) => drillTo(d)} onSelectDeptMap={() => { setTab('map'); }} onOpenAddMenu={() => setOverlay({ type: 'add-menu' })} />;
      else if (drillStack.length === 1) screen = <DepartmentScreen onBack={drillBack} onSelectCategory={(c) => drillTo(c)} />;
      else if (drillStack.length === 2) screen = <SpeciesListScreen category={drillStack[1]} onBack={drillBack} onSelectSpecies={(s) => drillTo(s)} />;
      else screen = <SpeciesDetailScreen speciesId={drillStack[2]} onBack={drillBack} onObserve={(sp) => setOverlay({ type: 'photo-choice', species: sp })} onEdit={() => setView({ name: 'edit-species' })} />;
    } else if (tab === 'map') screen = <ObservationsMapScreen />;
    else if (tab === 'profile') screen = <ProfileScreen onOpenSettings={() => goTo('settings')} onOpenMarine={() => goTo('marine')} />;
  }

  const hideNav = view.name !== 'main' || (tab === 'explore' && drillStack.length >= 3);
  const inOverlay = overlay !== null;

  return (
    <div className="w-full min-h-screen flex flex-col items-center justify-center p-6" style={{ background: 'linear-gradient(135deg, #2A1F15 0%, #3D2F1F 100%)' }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,300;0,400;0,500;0,600;0,700;1,400;1,500&family=Karla:wght@400;500;600;700;800&display=swap');
        @keyframes shimmer { 0% { transform: translateX(-100%); } 100% { transform: translateX(200%); } }
        @keyframes sparkle { 0%, 100% { opacity: 0; transform: scale(0.5) rotate(0deg); } 50% { opacity: 1; transform: scale(1) rotate(180deg); } }
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
      `}</style>

      <div className="mb-6 text-center">
        <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] uppercase tracking-[0.3em] text-[#FFD66B] font-bold">Wireframes v3 · cahier des charges complet</p>
        <h1 style={{ fontFamily: 'Cormorant Garamond, serif' }} className="text-3xl text-[#FAF6EC] italic font-light mt-1">Spotted</h1>
      </div>

      <div className="relative" style={{ width: '380px', height: '760px' }}>
        <div className="absolute inset-0 rounded-[44px] shadow-2xl" style={{ background: 'linear-gradient(135deg, #1A1208 0%, #2A1F15 100%)', padding: '12px' }}>
          <div className="w-full h-full rounded-[34px] overflow-hidden relative" style={{ backgroundColor: '#F5EDDF' }}>
            {view.name !== 'login' && (
              <div className="absolute top-0 left-0 right-0 h-7 flex items-center justify-between px-6 z-10 pointer-events-none">
                <span style={{ fontFamily: 'Karla, sans-serif' }} className="text-[11px] font-bold text-[#1F3D2E]">9:41</span>
                <div className="flex items-center gap-1"><div className="flex gap-0.5">{[1, 2, 3, 4].map((i) => <div key={i} className={`w-1 ${i < 4 ? 'bg-[#1F3D2E]' : 'bg-[#1F3D2E]/30'}`} style={{ height: `${i * 2 + 2}px` }} />)}</div><div className="w-6 h-2.5 rounded-sm border border-[#1F3D2E] ml-1 relative"><div className="absolute inset-0.5 bg-[#1F3D2E] rounded-[1px]" style={{ width: '70%' }} /></div></div>
              </div>
            )}
            <div className="absolute inset-0 pb-16">{screen}</div>
            <BottomNav tab={tab} onChange={switchTab} hidden={hideNav} />
            {overlay?.type === 'add-menu' && <AddMenuOverlay onClose={() => setOverlay(null)} onAddSpecies={() => { setOverlay(null); goTo('add-species'); }} onAddRegion={() => { setOverlay(null); goTo('add-region'); }} />}
            {overlay?.type === 'photo-choice' && <PhotoChoiceOverlay species={overlay.species} onSkip={() => setOverlay({ type: 'discovery', species: overlay.species, withPhoto: false })} onCapture={() => setOverlay({ type: 'photo-capture', species: overlay.species })} onEditMeta={() => setOverlay({ type: 'edit-meta', species: overlay.species })} />}
            {overlay?.type === 'edit-meta' && <EditMetaOverlay onClose={() => setOverlay({ type: 'photo-choice', species: overlay.species })} />}
            {overlay?.type === 'photo-capture' && <PhotoCaptureOverlay onCancel={() => setOverlay({ type: 'photo-choice', species: overlay.species })} onValidate={() => setOverlay({ type: 'discovery', species: overlay.species, withPhoto: true })} />}
            {overlay?.type === 'discovery' && <DiscoveryOverlay species={overlay.species} withPhoto={overlay.withPhoto} onClose={() => setOverlay({ type: 'badge' })} />}
            {overlay?.type === 'badge' && <BadgeUnlockOverlay onClose={() => setOverlay(null)} />}
          </div>
        </div>
      </div>

      <div className="mt-6 flex flex-wrap gap-2 justify-center max-w-md">
        {[
          { label: 'Login', action: () => { setView({ name: 'login' }); setOverlay(null); } },
          { label: 'Accueil', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack([]); setOverlay(null); } },
          { label: '+ menu', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack([]); setOverlay({ type: 'add-menu' }); } },
          { label: 'Ajout espèce', action: () => { setView({ name: 'add-species' }); setOverlay(null); } },
          { label: 'Édition espèce', action: () => { setView({ name: 'edit-species' }); setOverlay(null); } },
          { label: 'Ajout territoire', action: () => { setView({ name: 'add-region' }); setOverlay(null); } },
          { label: 'Liste espèces', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack(['oise', 'oiseaux']); setOverlay(null); } },
          { label: 'Fiche débloquée', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack(['oise', 'oiseaux', 1]); setOverlay(null); } },
          { label: 'Fiche débusquer', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack(['oise', 'oiseaux', 5]); setOverlay(null); } },
          { label: 'Espèce sans photo', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack(['oise', 'oiseaux', 4]); setOverlay(null); } },
          { label: 'Modif lieu/date', action: () => { setView({ name: 'main' }); setTab('explore'); setDrillStack(['oise', 'oiseaux', 5]); setOverlay({ type: 'edit-meta', species: SPECIES.find(s => s.id === 5) }); } },
          { label: 'Carnet géo', action: () => { setView({ name: 'main' }); setTab('map'); setDrillStack([]); setOverlay(null); } },
          { label: 'Profil', action: () => { setView({ name: 'main' }); setTab('profile'); setDrillStack([]); setOverlay(null); } },
          { label: 'Profil Marine', action: () => { setView({ name: 'marine' }); setOverlay(null); } },
          { label: 'Réglages', action: () => { setView({ name: 'settings' }); setOverlay(null); } },
        ].map((j) => (
          <button key={j.label} onClick={j.action} style={{ fontFamily: 'Karla, sans-serif' }} className="px-3 py-1.5 rounded-full text-xs bg-[#FAF6EC]/10 border border-[#C4A572]/40 text-[#C4A572] hover:bg-[#C4A572]/20 transition-colors font-semibold">
            {j.label}
          </button>
        ))}
      </div>
      <p style={{ fontFamily: 'Karla, sans-serif' }} className="text-[10px] text-[#FFD66B]/70 mt-3 italic text-center max-w-md">
        💡 Mode "guide de terrain" (sépia, pointillés) → tu sais quoi chercher. Validation → mutation visuelle vers le mode "trophée" (couleur, gloire). Teste : <span className="text-[#FFD66B] font-bold">Fiche débusquer</span> → "Je l'ai vue !"
      </p>
    </div>
  );
}
