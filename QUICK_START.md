# RPC Migration - Quick Start Guide

## 🎯 Resumen Ejecutivo

Ya se ha creado toda la infraestructura para migrar de Edge Functions a RPC. Solo necesitas:

1. **Actualizar las pantallas** para usar los repositorios
2. **Verificar RLS** en Supabase
3. **Eliminar Edge Functions**
4. **Probar y desplegar**

## 🚀 Paso 1: Actualizar CardScreen (10 min)

**Archivo actual:** `lib/features/public_card/presentation/card_screen.dart`
**Referencia:** Ver `card_screen_refactored.dart`

### Cambios necesarios:

```dart
// ❌ REMOVER
import '../../../core/services/supabase_service.dart';

// ✅ AGREGAR
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/card_repository.dart';

// ❌ CAMBIAR CLASE
class CardScreen extends StatefulWidget { ... }

// ✅ CAMBIAR A
class CardScreen extends ConsumerStatefulWidget { ... }

// ❌ REMOVER
class _CardScreenState extends State<CardScreen> { ... }

// ✅ CAMBIAR A  
class _CardScreenState extends ConsumerState<CardScreen> { ... }

// ❌ CAMBIAR LÍNEA ~47
final card = await callFunction('get-public-card', {'token': widget.token});

// ✅ CAMBIAR A
final card = await ref.read(cardRepositoryProvider).getPublicCard(widget.token);
```

## 🚀 Paso 2: Actualizar JoinScreen (10 min)

**Archivo:** `lib/features/public_join/presentation/join_screen.dart`

```dart
// ✅ AGREGAR
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/program_repository.dart';

// ❌ CAMBIAR
final _program = callFunction('get-public-program', {'program_slug': widget.slug});
final res = await callFunction('join-program', {'program_slug': widget.slug});

// ✅ CAMBIAR A
final _program = ref.read(programRepositoryProvider).getPublicProgram(widget.slug);
final res = await ref.read(programRepositoryProvider).joinProgram(widget.slug);
```

## 🚀 Paso 3: Otras Pantallas (opcional, pero recomendado)

Busca todas las llamadas a `callFunction`:

```bash
grep -r "callFunction" lib --include="*.dart"
```

Reemplaza cada una con el repositorio correspondiente:

- `callFunction('award-punch', ...)` → `ref.read(punchRepositoryProvider).awardPunch(...)`
- `callFunction('redeem-reward', ...)` → `ref.read(rewardRepositoryProvider).redeemReward(...)`
- `callFunction('recover-card', ...)` → `ref.read(recoveryRepositoryProvider).recoverCard(...)`
- `callFunction('claim-recovery', ...)` → `ref.read(recoveryRepositoryProvider).claimRecovery(...)`
- `callFunction('resolve-scan', ...)` → `ref.read(punchRepositoryProvider).resolveScan(...)`
- `callFunction('reverse-last-punch', ...)` → `ref.read(punchRepositoryProvider).reverseLastPunch(...)`
- `callFunction('update-customer-contact', ...)` → `ref.read(recoveryRepositoryProvider).updateCustomerContact(...)`

## 🔐 Paso 4: Verificar RLS en Supabase

### Conectarse a Supabase
```bash
# Usar psql o pgAdmin en Supabase dashboard
psql postgresql://postgres:[password]@db.xcprpmzesfoirchafpjh.supabase.co:5432/postgres
```

### Verificar RPC functions existen
```sql
SELECT proname FROM pg_proc 
WHERE proname LIKE 'get_%' 
   OR proname LIKE '%punch%' 
   OR proname LIKE '%reward%'
ORDER BY proname;
```

### Verificar RLS policies
```sql
-- Ver todas las políticas
SELECT * FROM pg_policies;

-- Para tabla específica
SELECT * FROM pg_policies WHERE tablename = 'memberships';
```

### Crear/Actualizar políticas RLS si faltan
```sql
-- Ejemplo para función pública
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;
CREATE POLICY "get_by_token" ON cards
  FOR SELECT USING (true);  -- permitir acceso público

-- Ejemplo para función autenticada
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_memberships" ON memberships
  FOR SELECT USING (auth.uid() = owner_id);
```

## ❌ Paso 5: Eliminar Edge Functions

**SOLO después de verificar que todo funciona:**

```bash
cd /Users/dnuno/Documents/punchcardqr

# Listar funciones actuales
ls supabase/functions/

# Eliminar funciones (EXCEPTO Stripe)
rm -rf supabase/functions/award-punch
rm -rf supabase/functions/claim-recovery
rm -rf supabase/functions/create-customer-portal
rm -rf supabase/functions/get-public-card
rm -rf supabase/functions/get-public-program
rm -rf supabase/functions/join-program
rm -rf supabase/functions/recover-card
rm -rf supabase/functions/redeem-reward
rm -rf supabase/functions/resolve-scan
rm -rf supabase/functions/reverse-last-punch
rm -rf supabase/functions/update-customer-contact

# Verificar que solo quedan Stripe
ls supabase/functions/
# Debería mostrar solo:
# - create-checkout-session/
# - stripe-webhook/
# - _shared/

# Desplegar cambios
supabase db push  # actualizar RLS
```

## ✅ Paso 6: Probar

```bash
# Ejecutar app
flutter run

# Probar flujos principales:
# 1. Ver tarjeta pública (/c/:token)
# 2. Unirse a programa
# 3. Hacer punch
# 4. Ver recompensas
# 5. Recuperar tarjeta
```

## 🎯 Checklist Final

- [ ] Actualizar CardScreen
- [ ] Actualizar JoinScreen  
- [ ] Actualizar otras pantallas que usen callFunction
- [ ] Remover importación de callFunction de lib/core/services/supabase_service.dart
- [ ] Verificar RLS policies en Supabase
- [ ] Probar flujo público (tarjeta sin login)
- [ ] Probar flujo autenticado (owner punch)
- [ ] Eliminar Edge Functions (excepto Stripe)
- [ ] Hacer git commit
- [ ] Desplegar a producción

## 📞 Troubleshooting

### Error: "card_not_found"
- Verifica que el token sea válido
- Verifica que la RPC function `get_public_card` existe

### Error: "unauthorized"
- Asegúrate de que el JWT sea válido
- Verifica que `SUPABASE_ANON_KEY` esté configurado

### Error: "forbidden"
- Revisa las políticas RLS
- Verifica que el usuario actual tenga permiso

### Error de conexión
- Verifica las credenciales de Supabase
- Verifica que la URL de API sea correcta

## 📚 Documentación Completa

- **REFACTORING_GUIDE.md** - Guía detallada de la refactorización
- **MIGRATION_SUMMARY.md** - Checklist completo
- **RPC Service:** `lib/core/services/rpc_service.dart`
- **Ejemplo:** `lib/features/public_card/presentation/card_screen_refactored.dart`

## 🎓 Estructura de Repositorios

Todos los repositorios usan este patrón:

```dart
class XyzRepository {
  XyzRepository(this._rpc);
  final RpcService _rpc;
  
  Future<Map<String, dynamic>> operation({required params}) async {
    return await _rpc.call(
      'function_name',
      params: {'p_param1': value1, 'p_param2': value2},
    );
  }
}

final xyzRepositoryProvider = Provider((ref) => 
  XyzRepository(ref.watch(rpcProvider))
);
```

## ✨ Ventajas de Esta Implementación

1. **Menos latencia** - Sin salto por Edge Function
2. **Más seguro** - RLS aplica directamente
3. **Más simple** - Menos código en servidor
4. **Mejor mantenibilidad** - Lógica centralizada en repositorios
5. **Mismo error handling** - AppException funciona igual

---

**¡Listo para comenzar! 🚀**
