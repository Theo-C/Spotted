/// Mapping clé logique de catégorie (stockée en BDD) → emoji affiché.
/// Volontairement simple en MVP — on remplacera par des SVG custom plus tard.
String emojiForCategory(String key) {
  return switch (key) {
    'birds' => '🦅',
    'mammals' => '🦌',
    'reptiles' => '🦎',
    'bats' => '🦇',
    _ => '🐾',
  };
}
