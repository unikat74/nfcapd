# nfcapd

Dockerowy kolektor przepływów NetFlow oparty na [nfdump](https://github.com/phaag/nfdump).

## Opis

Projekt zawiera trzy kontenery:

- **nfcapd** – nasłuchuje na przepływy NetFlow (UDP), zapisuje je do plików i rotuje co zadany interwał
- **nfcapd-retention** – cyklicznie usuwa pliki starsze niż 13 miesięcy
- **nfcapd-monitor** – monitoruje działanie kolektora i miejsca na dysku, wysyła powiadomienia push przez [ntfy.sh](https://ntfy.sh)

nfdump budowany jest ze źródeł bezpośrednio w obrazie Dockera.

## Wymagania

- Docker
- Docker Compose

## Uruchomienie

### 1. Konfiguracja

Skopiuj plik przykładowy i uzupełnij wartości:

```bash
cp .env.example .env
```

Minimalnie musisz ustawić:
- `HOST_IP` – jeśli chcesz bindować nfcapd do konkretnego interfejsu
- `NTFY_URL` – jeśli chcesz korzystać z monitoringu

### 2. Start kolektora i retencji

```bash
docker compose up -d nfcapd nfcapd-retention
```

### 3. Start monitora (opcjonalnie)

Po skonfigurowaniu `NTFY_URL` w `.env`:

```bash
docker compose build nfcapd-monitor
docker compose up -d nfcapd-monitor
```

Po weryfikacji że monitor działa poprawnie zmień w `.env`:
```
# restart: "no" → unless-stopped w docker-compose.yml
```
lub ustaw ręcznie `restart: unless-stopped` dla serwisu `nfcapd-monitor`.

## Konfiguracja

Wszystkie zmienne konfiguracyjne w pliku `.env` (wzorzec: `.env.example`).

| Zmienna              | Domyślna wartość   | Opis                                                  |
|----------------------|--------------------|-------------------------------------------------------|
| `TZ`                 | `Europe/Warsaw`    | Strefa czasowa                                        |
| `NFDUMP_VERSION`     | `1.7.7`            | Wersja nfdump                                         |
| `DATA_DIR`           | `./nfcapd/data`    | Katalog zapisu danych na hoście                       |
| `FLOW_DIR`           | `/flows`           | Katalog zapisu danych wewnątrz kontenera              |
| `HOST_IP`            | *(wszystkie)*      | IP hosta do bindowania portu UDP                      |
| `PORT`               | `12345`            | Port UDP nasłuchu                                     |
| `SUBDIR_FORMAT`      | `1`                | Format podkatalogów (`-S` nfcapd), `1` = YYYY/MM/DD  |
| `ROTATE_INTERVAL`    | `300`              | Interwał rotacji plików (sekundy)                     |
| `RETENTION_SLEEP`    | `3600`             | Interwał uruchamiania retencji (sekundy)              |
| `NTFY_URL`           | –                  | URL topic ntfy.sh do powiadomień push                 |
| `HOSTNAME_LABEL`     | *(hostname)*       | Nazwa serwera w treści powiadomień                    |
| `FILE_AGE_THRESHOLD` | `15`               | Minuty bez nowego pliku zanim zostanie wysłany alert  |
| `DISK_THRESHOLD`     | `90`               | Procent zajętości dysku wyzwalający alert             |
| `CHECK_INTERVAL`     | `300`              | Interwał sprawdzania przez monitor (sekundy)          |

## Monitoring (ntfy.sh)

Monitor wysyła powiadomienia push na telefon gdy:
- nfcapd przestaje generować pliki (domyślnie: brak pliku przez 15 min)
- dysk osiągnie próg zajętości (domyślnie: 90%)
- problem ustępuje (powiadomienie recovery)

### Konfiguracja aplikacji ntfy

1. Zainstaluj aplikację **ntfy** autorstwa **Philipp Heckel** (ikona niebieska):
   - [iOS – App Store](https://apps.apple.com/us/app/ntfy/id1625396347)
   - [Android – Google Play](https://play.google.com/store/apps/details?id=io.heckel.ntfy)
2. W aplikacji dodaj subskrypcję swojego topicu (np. `nfcapd-firma-x7k2m`)
3. Ustaw `NTFY_URL=https://ntfy.sh/nfcapd-firma-x7k2m` w `.env`

> **Ważne:** topic jest publiczny – wybierz trudną do odgadnięcia nazwę.

### Test powiadomienia

```bash
docker compose exec nfcapd-monitor curl \
  -H "Title: Test" -d "Monitor dziala!" \
  https://ntfy.sh/TWOJ_TOPIC
```

## Analiza przepływów

Do analizy zebranych danych użyj narzędzia `nfdump`:

```bash
# Odczyt pojedynczego pliku
nfdump -r ./nfcapd/data/<ścieżka>/nfcapd.<timestamp>

# Odczyt z całego katalogu
nfdump -R ./nfcapd/data/
```
