# nfcapd

Dockerowy kolektor przepływów NetFlow oparty na [nfdump](https://github.com/phaag/nfdump).

## Opis

Projekt zawiera dwa kontenery:

- **nfcapd** – nasłuchuje na przepływy NetFlow (UDP), zapisuje je do plików i rotuje co zadany interwał
- **nfcapd-retention** – cyklicznie usuwa pliki starsze niż 13 miesięcy

nfdump budowany jest ze źródeł bezpośrednio w obrazie Dockera.

## Wymagania

- Docker
- Docker Compose

## Uruchomienie

```bash
docker compose up -d
```

Dane przepływów trafiają do katalogu `./nfcapd/data/`.

## Konfiguracja

Zmienne środowiskowe w `docker-compose.yml`:

| Zmienna           | Domyślna wartość  | Opis                                              |
|-------------------|-------------------|---------------------------------------------------|
| `PORT`            | `12345`           | Port UDP nasłuchu                                 |
| `FLOW_DIR`        | `/flows`          | Katalog zapisu plików przepływów                  |
| `SUBDIR_FORMAT`   | `1`               | Format podkatalogów (`-S` nfcapd)                 |
| `ROTATE_INTERVAL` | `300`             | Interwał rotacji plików (sekundy)                 |
| `SLEEP_SECONDS`   | `3600`            | Interwał uruchamiania cleanup (sekundy)           |
| `TZ`              | `Europe/Warsaw`   | Strefa czasowa                                    |

## Wersja nfdump

Wersja kontrolowana przez argument build `NFDUMP_VERSION` w `docker-compose.yml` (domyślnie `1.7.7`).

## Analiza przepływów

Do analizy zebranych danych użyj narzędzia `nfdump`:

```bash
# Odczyt pliku z przepływami
nfdump -r ./nfcapd/data/<ścieżka>/nfcapd.<timestamp>

# Odczyt z całego katalogu
nfdump -R ./nfcapd/data/
```
