# Matriks RBAC

Sumber kebenaran di klien: `lib/core/security/permissions.dart`.
Validasi final selalu di Cloud Functions.

| Permission | farmer_viewer | operator | pekaseh | mikiko_admin | platform_admin |
|---|:--:|:--:|:--:|:--:|:--:|
| `dashboard.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `monitoring.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `ledger.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `rule.view` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `alert.acknowledge` | – | ✓ | ✓ | ✓ | – |
| `gate.command` | – | ✓ | – | – | – |
| `rule.manage` | – | – | ✓ | – | – |
| `rule.approve` | – | – | ✓ | – | – |
| `device.manage` | – | – | – | ✓ | ✓ |
| `member.manage` | – | – | – | – | ✓ |
| `audit.view` | – | – | ✓ | ✓ | ✓ |

Catatan:

- Admin Mikiko **tidak** otomatis berwenang menentukan alokasi air.
- Persetujuan aturan hanya untuk `pekaseh` yang memiliki `rule.approve`.
- Keanggotaan situs eksplisit (`sites/{siteId}/members/{uid}`); klaim token
  hanya petunjuk kasar dan tidak dipakai untuk otorisasi data sensitif.
- Perubahan peran/membership hanya lewat Functions dan tercatat di
  `auditEvents`.
