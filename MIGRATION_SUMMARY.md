# Refactorización RPC - Resumen de Cambios

## ✅ Completado

### 1. Nuevo Servicio RPC
- **Archivo:** `lib/core/services/rpc_service.dart`
- **Función:** Llamar RPC de PostgreSQL directamente
- **Características:**
  - Maneja autenticación JWT automáticamente
  - Convierte errores PostgreSQL a `AppException`
  - Mapea códigos de error HTTP según tabla `PG_ERRORS`

### 2. Repositorios Creados
Se han creado 5 repositorios que reemplazan las Edge Functions:

| Repositorio | Archivo | Funciones RPC |
|---|---|---|
| **CardRepository** | `lib/features/public_card/data/card_repository.dart` | `get_public_card` |
| **ProgramRepository** | `lib/features/public_join/data/program_repository.dart` | `get_public_program`, `join_program` |
| **PunchRepository** | `lib/features/scanner/data/punch_repository.dart` | `resolve_scan`, `award_punch`, `reverse_last_punch` |
| **RewardRepository** | `lib/features/rewards/data/reward_repository.dart` | `redeem_reward` |
| **RecoveryRepository** | `lib/features/recover/data/recovery_repository.dart` | `recover_card`, `claim_recovery`, `update_customer_contact` |

### 3. Ejemplo de Refactorización
- **Archivo:** `lib/features/public_card/presentation/card_screen_refactored.dart`
- **Cambio:** De `callFunction('get-public-card')` a `cardRepositoryProvider.getPublicCard()`

### 4. Documentación
- **REFACTORING_GUIDE.md** - Guía completa de migración
- **MIGRATION_SUMMARY.md** - Este archivo (resumen de cambios)

## 🔄 Próximos Pasos

### Fase 1: Actualizar Pantallas
Necesitas reemplazar en cada pantalla las llamadas `callFunction` con las del repositorio:

```dart
// Antes
final card = await callFunction('get-public-card', {'token': widget.token});

// Después
final card = await ref.read(cardRepositoryProvider).getPublicCard(widget.token);
```

**Pantallas a actualizar:**
1. `lib/features/public_card/presentation/card_screen.dart`
2. `lib/features/public_join/presentation/join_screen.dart`
3. `lib/features/scanner/presentation/scan_screen.dart` (si existe)
4. Cualquier otra que use `callFunction`

### Fase 2: Verificar RLS (Row Level Security)

Asegúrate de que las políticas RLS en Supabase permitan:

#### Para funciones públicas (sin autenticación):
```sql
-- get_public_card, get_public_program
CREATE POLICY "public_by_token" ON cards
  FOR SELECT USING (token = $1);  -- token se pasa como p_token
```

#### Para funciones autenticadas:
```sql
-- award_punch, join_program, etc.
CREATE POLICY "owner_access" ON memberships
  FOR SELECT USING (owner_id = auth.uid());
```

### Fase 3: Eliminar Edge Functions

**Una vez que hayas verificado que todo funciona:**

```bash
# Eliminar funciones (EXCEPTO Stripe)
rm -rf supabase/functions/{award-punch,claim-recovery,create-customer-portal,get-public-card,get-public-program,join-program,recover-card,redeem-reward,resolve-scan,reverse-last-punch,update-customer-contact}

# Mantener
# - supabase/functions/create-checkout-session/
# - supabase/functions/stripe-webhook/

# Desplegar cambios
supabase db push  # RLS policies
```

### Fase 4: Pruebas

1. **Función pública:**
   ```dart
   // Acceder a tarjeta sin autenticación
   final card = await cardRepository.getPublicCard(token);
   ```

2. **Función autenticada:**
   ```dart
   // Necesita JWT del usuario autenticado
   final result = await punchRepository.awardPunch(...);
   ```

3. **Manejo de errores:**
   ```dart
   try {
     await punchRepository.reverseLastPunch(membershipId);
   } on AppException catch (e) {
     // e.code, e.status, e.message, e.data
   }
   ```

## 📋 Checklist de Migración

### Código
- [ ] Actualizar `CardScreen` - usar `cardRepositoryProvider`
- [ ] Actualizar `JoinScreen` - usar `programRepositoryProvider`
- [ ] Actualizar `ScanScreen` - usar `punchRepositoryProvider`
- [ ] Actualizar `RewardScreen` - usar `rewardRepositoryProvider`
- [ ] Actualizar `RecoverScreen` - usar `recoveryRepositoryProvider`
- [ ] Remover importación de `callFunction` de `supabase_service.dart`

### Database
- [ ] Revisar políticas RLS existentes
- [ ] Crear/actualizar políticas RLS para funciones públicas
- [ ] Verificar permisos de roles en Supabase

### Supabase
- [ ] Desplegar cambios de DB: `supabase db push`
- [ ] Verificar que RPC functions existen: `psql ... SELECT proname FROM pg_proc ...`
- [ ] Eliminar Edge Functions no necesarias

### Testing
- [ ] Probar acceso público a tarjeta
- [ ] Probar join a programa
- [ ] Probar award de punch
- [ ] Probar reverse de punch
- [ ] Probar redeem de reward
- [ ] Probar recuperación de tarjeta
- [ ] Probar actualización de contacto

## 🚀 Diferencias Clave

### Antes (Edge Functions)
```typescript
// supabase/functions/award-punch/index.ts
export async function handler(req) {
  const membership = req.body.membership_id;
  const result = await rpc("award_punch", {
    p_membership: membership,
    ...
  });
  return result;
}
```

### Después (RPC Directo)
```dart
// lib/features/scanner/data/punch_repository.dart
Future<Map<String, dynamic>> awardPunch({
  required String membershipId,
  ...
}) async {
  return await _rpc.call(
    'award_punch',
    params: {
      'p_membership': membershipId,
      ...
    },
  );
}
```

**Ventajas:**
- ✅ Menos latencia (sin saltar por Edge Function)
- ✅ Más seguro (RLS aplica directamente)
- ✅ Más simple (menos código en servidor)
- ✅ Mismo error handling

## ⚠️ Consideraciones

1. **Autenticación:** El cliente Supabase envía JWT automáticamente en `Authorization` header
2. **RLS:** Los RPC respetan las políticas RLS del usuario actual
3. **Realtime:** Mantener igual: `Supabase.instance.client.channel(...)`
4. **Stripe:** Mantener Edge Functions para Stripe (requieren API Key del servidor)

## 📞 Soporte

Si encuentras errores durante la migración:

1. **Error `card_not_found`:** Verifica que el token sea válido
2. **Error `forbidden`:** Revisa las políticas RLS
3. **Error `unauthorized`:** Asegúrate que el JWT sea válido
4. **Error de conexión:** Verifica las credenciales de Supabase

## 📚 Referencias

- Archivo completo: `/Users/dnuno/Documents/punchcardqr/REFACTORING_GUIDE.md`
- Servicio RPC: `/Users/dnuno/Documents/punchcardqr/lib/core/services/rpc_service.dart`
- Ejemplo refactorizado: `/Users/dnuno/Documents/punchcardqr/lib/features/public_card/presentation/card_screen_refactored.dart`
