# Kalibrering

Kalibrering lär FlickSlides att känna igen just dina gester för bättre precision.

## Varför kalibrera?

Standardinställningarna fungerar för de flesta, men kalibrering kan hjälpa om:
- Dina gester inte registreras tillförlitligt
- Du får false positives (oavsiktliga registreringar)
- Du vill använda en personlig geststil

## Starta kalibrering

1. Öppna FlickSlides på iPhone
2. Tryck på **Gestkalibrering**
3. Se till att Watch är ansluten (grön prick)
4. Tryck **Starta kalibrering**

## Kalibreringsprocessen

### Steg 1: Nästa-gester

1. Du ombeds göra "nästa slide"-gesten
2. **Håll armen still** tills indikatorn blir grön
3. **Gör gesten** när det står "Gör gesten NU!"
4. Upprepa 10-15 gånger

### Steg 2: Föregående-gester

Samma process som steg 1, men med "föregående slide"-gesten.

### Steg 3: Negativa exempel

1. Gör **vanliga rörelser** som INTE är gester
2. T.ex. titta på klockan, lyfta armen, gestikulera
3. Detta hjälper appen skilja gester från vardagsrörelser

### Steg 4: Analys

Appen analyserar dina inspelningar och:
- Tar bort avvikande exempel (outliers)
- Skapar en personlig gestprofil
- Visar statistik när det är klart

## Tips för bra kalibrering

- **Gör naturliga gester** – överdrivna rörelser ger sämre resultat
- **Variera lite** – gör inte exakt identiska rörelser varje gång
- **Lugn miljö** – undvik kalibrering i bilen eller på språng
- **Samma arm** – kalibrera med den arm du har klockan på

## Inställningar

Under Inställningar på iPhone kan du:

### Använd kalibrering
Slå av/på personliga gester. Om av används standarddetektering.

### Rensa kalibrering
Ta bort alla inspelade gester och börja om.

### Justera trösklar manuellt

- **Accelerationströskel:** Hur stark rörelse krävs (lägre = känsligare)
- **Rotationströskel:** Hur mycket handledsrotation krävs
- **Debounce-intervall:** Minsta tid mellan gester

## Felsökning

### Kalibreringen avbryts
- Se till att Watch-appen är öppen under hela processen
- Håll iPhone och Watch nära varandra

### "Behöver fler gester"
- Dina gester varierade för mycket
- Gör mer konsekventa rörelser nästa gång

### Gester fungerar sämre efter kalibrering
- Gå till Inställningar och slå av "Använd kalibrering"
- Eller rensa kalibrering och gör om processen
