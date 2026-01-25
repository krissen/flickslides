# Besluts- och frågehantering

## Eskaleringsmodell

```
┌─────────────────────────────────────────────────────────────┐
│                     PRODUKTÄGARE                            │
│  Kristian Niemi                                             │
│  Beslutar om:                                               │
│  • Scope-ändringar                                          │
│  • Arkitekturbeslut som påverkar UX                         │
│  • Release/distribution                                     │
│  • Affärsprioriteringar                                     │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │ Eskalerar
                           │
┌─────────────────────────────────────────────────────────────┐
│                    PROJEKTLEDARE                            │
│  Claude                                                     │
│  Beslutar själv om:                                         │
│  • Tekniska implementationsval (inom best practices)        │
│  • Kodstandard och arkitekturmönster                        │
│  • Prioritering av utvecklingsuppgifter                     │
│  • Resursallokering mellan roller                           │
│  • API-design och protokoll                                 │
│                                                             │
│  Eskalerar:                                                 │
│  • Val som påverkar användarupplevelse                      │
│  • Scope-förändringar                                       │
│  • Oklara krav                                              │
│  • Tekniska begränsningar som kräver kompromiss             │
└─────────────────────────────────────────────────────────────┘
                           ▲
                           │ Rapporterar frågor
                           │
┌─────────────────────────────────────────────────────────────┐
│                    SUB-AGENTER                              │
│  watchOS, iOS, macOS, UX, QA                                │
│  Rapporterar:                                               │
│  • Blockeringar och risker                                  │
│  • Tekniska frågor som kräver beslut                        │
│  • Oklarheter i uppdrag                                     │
│  • Förslag på förbättringar                                 │
└─────────────────────────────────────────────────────────────┘
```

## Frågeformat

Sub-agenter inkluderar frågor i sin statusrapport:

```
FRÅGOR:
  1. [TEKNISK] Beskrivning av frågan
  2. [UX] Beskrivning av frågan
  3. [SCOPE] Beskrivning av frågan
```

## Beslutslogg

Alla beslut dokumenteras med:
- **ID:** BESLUT-YYYY-MM-DD-NN
- **Fråga:** Vad som behövde beslutas
- **Beslutare:** Projektledare eller Produktägare
- **Beslut:** Vad som beslutades
- **Motivering:** Varför (referens till principer/best practices)
- **Påverkan:** Vilka delar av projektet som påverkas

## Beslutsprinciper

Projektledaren fattar beslut baserat på:

1. **Projektmål:** Gestsäkerhet > allt annat
2. **Target:** Ultra 1 först (Produktägarens enhet)
3. **Minimalism:** Enklaste lösningen som fungerar
4. **Best practices:** Swift API Design Guidelines, Apple HIG
5. **Community standards:** Etablerade mönster i Swift-communityn
