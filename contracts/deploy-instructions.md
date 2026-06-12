# ArcNames — Deploy Talimatları

## Arc Testnet Bilgileri
- Chain ID: 5042002
- RPC: https://rpc.testnet.arc.network
- Explorer: https://testnet.arcscan.app
- USDC ERC-20: 0x3600000000000000000000000000000000000000

## Adım 1 — Test USDC Al
1. https://faucet.circle.com/ adresine git
2. "Arc Testnet" seç
3. MetaMask adresini gir → USDC al (test için)

## Adım 2 — Remix IDE ile Deploy

1. https://remix.ethereum.org/ aç
2. "contracts" klasörüne `ArcNameRegistry.sol` dosyasını yükle (veya yapıştır)
3. **Compiler** sekmesi:
   - Solidity version: `0.8.20`
   - EVM version: `paris` (veya default)
   - "Compile ArcNameRegistry.sol" tıkla
4. **Deploy & Run** sekmesi:
   - Environment: `Injected Provider - MetaMask`
   - MetaMask'ta Arc Testnet seçili olsun
   - Contract: `ArcNameRegistry`
   - Constructor parametresi (`_usdc`):
     ```
     0x3600000000000000000000000000000000000000
     ```
   - "Deploy" tıkla → MetaMask'ta onayla
5. Deploy sonrası **kontrat adresini kopyala** → `arcnames_v4.html` içindeki
   `CONTRACT_ADDRESS` değişkenine yapıştır

## Adım 3 — HTML'i Güncelle

`arcnames_v4.html` içinde şu satırı bul ve deploy edilen adresi gir:
```js
const CONTRACT_ADDRESS = 'BURAYA_DEPLOY_ADRESINI_YAZ';
```

## Fiyatlar (USDC, 6 decimal)
| Uzunluk | Yıllık Fiyat |
|---------|-------------|
| 2 char  | $50 USDC    |
| 3 char  | $20 USDC    |
| 4 char  | $10 USDC    |
| 5+ char | $2 USDC     |

## Kontrat Fonksiyonları
- `register(name, years)` — İsim kaydet (önce USDC approve gerekli)
- `renew(name, years)` — Yenile
- `transfer(name, to)` — Transfer et
- `setPrimary(name)` — Primary ayarla
- `isAvailable(name)` — Müsait mi?
- `getPrice(name, years)` — Fiyat hesapla
- `getRecord(name)` — Kayıt detayları
- `getNamesOf(wallet)` — Cüzdanın isimlerini getir
- `getPrimaryName(wallet)` — Primary ismi getir
- `resolve(name)` — İsmi adrese çözümle
- `withdraw()` — USDC çek (sadece owner)

---

## ArcNameMarket Deploy (Adım 5)

### Gerekli adresler
- USDC: `0x3600000000000000000000000000000000000000`
- ArcNameRegistry: `0xBE267dcfC6eeB905e788358eAA792e2eCcB23F01`

### Remix'te deploy
1. `ArcNameMarket.sol` dosyasını Remix'e yükle
2. Compiler: `0.8.20`
3. Deploy & Run → `ArcNameMarket`
4. Constructor parametreleri:
   ```
   _usdc:     0x3600000000000000000000000000000000000000
   _registry: 0xBE267dcfC6eeB905e788358eAA792e2eCcB23F01
   ```
5. Deploy et → Market kontrat adresini kopyala

### HTML güncelleme
`arcnames_v4.html` içinde:
```js
const MARKET_ADDRESS = 'BURAYA_MARKET_ADRESINI_YAZ';
```

### Satış Akışı (Kullanıcı açısından)
1. My Names → Sell butonu tıkla
2. Fiyat gir → "List on Marketplace"
   - Adım 1: `registry.transfer(name, MARKET_ADDRESS)` — isme esrow
   - Adım 2: `market.list(name, price)` — listeye ekle
3. Market sayfasında görünür
4. Alıcı "Buy Now" → USDC approve + market.buy()
5. İsim anında alıcıya geçer, satıcı USDC alır (%97.5)

---

## ProfileRegistry Deploy (Adım 6)

### Gerekli adresler
- ArcNameRegistry: `0xBE267dcfC6eeB905e788358eAA792e2eCcB23F01`

### Remix'te deploy
1. `ProfileRegistry.sol` dosyasını Remix'e yükle
2. Compiler: `0.8.20`
3. Deploy & Run → `ProfileRegistry`
4. Constructor parametresi:
   ```
   _registry: 0xBE267dcfC6eeB905e788358eAA792e2eCcB23F01
   ```
5. Deploy et → ProfileRegistry kontrat adresini kopyala

### HTML güncelleme
`arcnames_v4.html` içinde:
```js
const PROFILE_ADDRESS = 'BURAYA_PROFILE_ADRESINI_YAZ';
```

### Desteklenen key'ler
| Key          | Açıklama            |
|--------------|---------------------|
| display      | Görünen ad          |
| bio          | Kısa bio            |
| url          | Website             |
| avatar       | Avatar URL          |
| com.twitter  | Twitter/X handle    |
| addr.eth     | ETH adres mapping   |
| addr.btc     | BTC adres mapping   |
