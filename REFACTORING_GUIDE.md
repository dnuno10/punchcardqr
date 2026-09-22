# Refactoring Guide: RPC-Based Architecture

## Objetivo
Eliminar las funciones de Supabase (Edge Functions) y usar RPC (Remote Procedure Calls) directamente desde el cliente Flutter/Dart. Solo mantener `index.ts` para Stripe Checkout y Webhook.

## Estructura

### Funciones a Eliminar
Todas EXCEPTO:
- ✅ `supabase/functions/create-checkout-session/index.ts` (Stripe Checkout)
- ✅ `supabase/functions/stripe-webhook/index.ts` (Stripe Webhook)

**Eliminar:**
- ❌ `award-punch/index.ts`
- ❌ `claim-recovery/index.ts`
- ❌ `create-customer-portal/index.ts`
- ❌ `get-public-card/index.ts`
- ❌ `get-public-program/index.ts`
- ❌ `join-program/index.ts`
- ❌ `recover-card/index.ts`
- ❌ `redeem-reward/index.ts`
- ❌ `resolve-scan/index.ts`
- ❌ `reverse-last-punch/index.ts`
- ❌ `update-customer-contact/index.ts`

## Refactorización

### 1. Nuevo Servicio RPC
✅ Creado: `lib/core/services/rpc_service.dart`

El servicio RPC:
- Llama RPC functions de PostgreSQL directamente
- Convierte errores PostgreSQL a `AppException`
- Maneja autenticación JWT automáticamente

### 2. Refactorizar Llamadas

#### Antes (Edge Function)
```dart
final card = await callFunction('get-public-card', {'token': widget.token});
```

#### Después (RPC)
```dart
final card = await ref.read(rpcProvider).call(
  'get_public_card',
  params: {'p_token': widget.token},
);
```

### 3. Cambios en RLS (Row Level Security)

**IMPORTANTE:** Las funciones RPC necesitan políticas RLS apropiadas:

#### Para funciones públicas (sin autenticación):
```sql
-- get_public_card, get_public_program
CREATE POLICY "public_access" ON cards
  FOR SELECT USING (true);
```

#### Para funciones autenticadas:
```sql
-- award_punch, join_program, etc.
CREATE POLICY "owner_only" ON memberships
  FOR SELECT USING (auth.uid() = owner_id);
```

## Paso a Paso de Refactorización

### Paso 1: Crear Servicios de Datos (Data Layer)

Ejemplo para `get_public_card`:

```dart
// lib/features/public_card/data/card_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/rpc_service.dart';

class CardRepository {
  CardRepository(this._rpc);
  
  final RpcService _rpc;
  
  Future<Map<String, dynamic>> getPublicCard(String token) async {
    return await _rpc.call(
      'get_public_card',
      params: {'p_token': token},
    );
  }
}

final cardRepositoryProvider = Provider((ref) => 
  CardRepository(ref.watch(rpcProvider)),
);
```

### Paso 2: Refactorizar Pantallas

Ejemplo para `CardScreen`:

```dart
// lib/features/public_card/presentation/card_screen.dart
// Cambiar:
// final card = await callFunction('get-public-card', {'token': widget.token});
// Por:
final card = await ref.read(cardRepositoryProvider).getPublicCard(widget.token);
```

### Paso 3: Mantener Funciones de Stripe

Solo refactorizar `create-checkout-session` y `stripe-webhook` para:

```dart
// lib/features/billing/data/billing_repository.dart
class BillingRepository {
  Future<Map<String, dynamic>> createCheckoutSession({
    required String priceId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    // Llamar Edge Function de Stripe (la única que permanece)
    return await callFunction('create-checkout-session', {
      'price_id': priceId,
      'success_url': successUrl,
      'cancel_url': cancelUrl,
    });
  }
}
```

## Mapeo de Funciones a RPC

| Edge Function | RPC Function | Tabla | Autenticación |
|---------------|--------------|-------|----------------|
| `get-public-card` | `get_public_card` | `cards` | Pública (token) |
| `get-public-program` | `get_public_program` | `loyalty_programs` | Pública |
| `join-program` | `join_program` | `memberships` | Autenticada (JWT) |
| `award-punch` | `award_punch` | `punches` | Autenticada (JWT) |
| `reverse-last-punch` | `reverse_last_punch` | `punches` | Autenticada (JWT) |
| `redeem-reward` | `redeem_reward` | `reward_redemptions` | Autenticada (JWT) |
| `claim-recovery` | `claim_recovery` | `cards` | Autenticada (JWT) |
| `recover-card` | `recover_card` | `cards` | Autenticada (JWT) |
| `update-customer-contact` | `update_customer_contact` | `customers` | Autenticada (JWT) |
| `create-checkout-session` | **MANTENER** | N/A | Autenticada |
| `stripe-webhook` | **MANTENER** | N/A | API Key |

## Configuración de Supabase

### Variables de Entorno (ya configuradas)
```
SUPABASE_URL=https://xcprpmzesfoirchafpjh.supabase.co
SUPABASE_ANON_KEY=<tu anon key>
SUPABASE_SERVICE_ROLE_KEY=<tu service role key>
```

### Verificar RPC Functions

```bash
# Conectarse a la DB
psql postgresql://postgres:password@db.xcprpmzesfoirchafpjh.supabase.co:5432/postgres

# Ver funciones creadas
SELECT proname FROM pg_proc WHERE proname LIKE 'get_%' OR proname LIKE '%punch%';
```

## Notas Importantes

1. **Nombres de parámetros:** Los parámetros RPC usan prefijo `p_`:
   - `p_token`, `p_owner_id`, `p_membership`, etc.

2. **Autenticación automática:** El cliente Supabase envía el JWT automáticamente

3. **Errores:** Los errores PostgreSQL (raise exception) se convierten a `AppException`

4. **Realtime:** Mantener igual: `Supabase.instance.client.channel(...)`

## Comandos Útiles

```bash
# Eliminar funciones antiguas (después de verificar)
rm -rf supabase/functions/{award-punch,claim-recovery,create-customer-portal,get-public-card,get-public-program,join-program,recover-card,redeem-reward,resolve-scan,reverse-last-punch,update-customer-contact}

# Desplegar cambios
supabase functions deploy create-checkout-session
supabase functions deploy stripe-webhook
supabase db push  # para cambios en RLS
```

## Status

- [x] RpcService creado
- [ ] Refactorizar CardRepository
- [ ] Refactorizar JoinRepository
- [ ] Refactorizar ScanRepository
- [ ] Refactorizar BillingRepository
- [ ] Actualizar RLS policies
- [ ] Eliminar Edge Functions
- [ ] Probar completamente
