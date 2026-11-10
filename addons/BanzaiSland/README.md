# Island

## Translating Island

Every piece of text the player sees goes through `ns.L["English text"]`. If a string has no translation, the English text is shown, so a partly finished translation still works.

Island already includes machine-translated drafts for deDE, esES, esMX, frFR, koKR, ptBR, ruRU, zhCN and zhTW (in `Locales/`). To correct one, just edit its file. Only the file matching the player's game language is used. To add another language, follow the steps below.

### Add a translation

1. Copy `Locales/Template.lua` to `Locales/<code>.lua`, where `<code>` is the WoW locale: `deDE`, `esES`, `esMX`, `frFR`, `itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN` or `zhTW`.
2. Put this as the first line of the new file:

   ```lua
   local L = select(2, ...).NewLocale("deDE") if not L then return end
   ```

3. Fill in the text on the right of each line: `L["Size"] = "Größe"`. Leave a line as `""` to keep the English for that string.
4. Keep placeholders such as `%s` and `%d` exactly as they are. They may be reordered with `%1$s` / `%2$s` if the grammar needs it. Lines marked `-- keep placeholders` contain them.
5. Add `Locales\<code>.lua` to `Island.toc` after `Locale.lua`. Never list `Template.lua`.
6. Send the file as a pull request, or hand it to the maintainer.

### Regenerating the template (maintainers)

Run this from the repo root before each release, and commit any change:

```
python -I tools/localization/gen_template.py
```

It rewrites `Locales/Template.lua` from the `L["..."]` calls in the source. It prints a warning for any dynamic `L[variable]` lookup, because those strings can't be extracted automatically and need a manual check. Pass another addon folder name as an argument to generate a template for a different addon.

### Terms that need a native speaker's review

The included translations are machine drafts. These are the terms the translators were least sure about. If you speak the language, check them against the real game client first.

| Locale | Terms to check |
|---|---|
| deDE | "Kriegsmeute", "Ruhm", "Tiefen", "Sprechender Kopf" |
| esES | "Eterno" (Forever), "Confirmación de grupo" (ready check), "Profundidades" (Delves), "Cabeza parlante" (Talking Head), "Gran Cámara" (Great Vault) |
| esMX | Same as esES. "ratón" and "hermandad" were kept from esES. |
| frFR | "gouffre" (Delve), "bataillon" (Warband), "tête parlante" (Talking Head), "Grande chambre forte" (Great Vault), yards shown as "m", plurals such as "%d prêt(s)" |
| ptBR | "Eterno" (Forever), "Imersão" (Delve), "Bando de Guerra" (Warband), "Cabeça Falante" (Talking Head), "Renome", "Pull", "tratador" (handler) |
| ruRU | "Известность" (Renown), "отряд" (Warband), "вылазки" (Delves), "Поиск подземелий", "Говорящая голова", "пулл", the card-builder wording |
| koKR | 탐욕 (Greed) and 필요 (Need), 구렁 (Delve), 문장 (Seals), 귀속 (lockout), 알약 (buff pills), the Shadowcloth / Mooncloth / Spellcloth names |
| zhCN | 永久 (Forever), 地下堡 (Delve), 战团 (Warband), 名望 (Renown), 巅峰 (Paragon), 传承 (Legacy), 冷却管理器 (Cooldown Manager) |
| zhTW | 探究 (Delve), 戰團 (Warband), 地城 |

For deDE the translator did not say which English term each word stands for, so check those against the strings in `Locales/deDE.lua`.
