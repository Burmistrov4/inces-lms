# Propuesta: «Próxima inscripción» por curso — 2026-10-25

**Lo que pidió Lorenzo:** que el administrador pueda poner algo como «Cupos
disponibles para este curso en (fecha)»; que cuando no haya cupos el sistema
**igual deje registrarse** pero le avise cuándo habrá cupos; que el admin lo
gestione; y que se vea en la landing.

## Lo que ya existe (medido, no supuesto)

| Pieza | Estado |
|---|---|
| **Lista de espera** | ✅ **Ya funciona.** `enrollments.status` tiene `WAITLISTED` (en la cola) → `PENDING_BID` (se le ofreció un asiento, con vencimiento) → `ENROLLED` → `DROPPED` (`backend/src/dominio/tipos.ts:508`). El ciclo completo está implementado y probado. |
| **Ofertas públicas** | ✅ `GET /api/v1/ofertas` (`backend/src/http/rutas/inscripciones.ts:80`) es pública: la landing ya la consume. |
| **Fecha de próxima apertura** | ❌ **No existe.** `sections` tiene `nombre`, `cupo_maximo`, `activa` y timestamps. Nada más. |
| **Aviso en la landing** | ❌ No hay. |

**Conclusión:** la mitad difícil —la cola de espera con vencimiento y promoción
automática— ya está hecha y probada. Lo que falta es el **dato** (la fecha) y
**mostrarlo**.

## Lo que hay que construir

| # | Pieza | Dónde | Coste |
|---|---|---|---|
| 1 | 2 columnas: `inscripcion_apertura timestamptz` y `inscripcion_nota text` | 1 migración | bajo |
| 2 | Exponerlas en `/ofertas` | `inscripciones.ts` + el repositorio | bajo |
| 3 | Editarlas en el panel de Secciones | `cpanel_secciones_panel.dart` | medio |
| 4 | Banner en la landing cuando no hay cupo: «Próxima inscripción: <fecha>» + botón «Entrar a la lista de espera» | `landing_page.dart` | medio |
| 5 | Pruebas: E2E de la landing + matriz | `e2e/` | medio |

**Total: una sesión de trabajo**, no un refactor. El riesgo es bajo porque la
pieza grande (la cola) ya existe.

## Las 3 decisiones que necesito de Lorenzo

No las tomo yo porque son de producto, no técnicas:

**1. ¿La fecha es informativa o automática?**
- **Informativa** (recomendada): el admin pone «abrimos el 15 de noviembre» y
  cuando llega el día **abre los cupos a mano**. Simple, sin sorpresas.
- **Automática**: al llegar la fecha, el sistema empieza a aceptar inscripciones
  solo. Cómodo, pero si el centro se equivoca de fecha hay cupos abiertos sin
  querer.

**2. ¿Se muestra en la landing siempre o solo cuando no hay cupo?**
- **Solo cuando no hay cupo** (recomendada): es cuando la información importa.
- **Siempre**: más previsible, pero añade ruido a los cursos que sí tienen cupo.

**3. ¿Quién puede entrar a la lista de espera?**
- **Cualquiera que se registre** (recomendada): es lo que pediste («igual lo deje
  registrarse»).
- **Solo correos verificados**: más control, más fricción.

## Mientras tanto, lo que ya está hecho

- **Logo duplicado en la landing**: arreglado. `_construirContenidoHero` y
  `_construirNavbar` pintaban el **mismo** `_construirMarca()`, y como la navbar
  va above del hero en el mismo `Column`, se veían los dos a la vez. Ahora el hero
  empieza por el titular.
- **Login con cédula para admin y docente**: migración
  `202610250001_login_cedula_admin_docente.sql`, validada con PGlite (546
  aserciones). El RPC buscaba **solo en `aspirantes`**, por eso un docente no
  podía entrar con su cédula aunque la interfaz prometía «Correo o Cédula».
- **Etiquetas del login unificadas** («Cédula o Correo» en escritorio y móvil).
  Ojo: esa etiqueta es un contrato con la prueba E2E (`LoginPage.ts:13`), así que
  se unificó en la dirección que **no** la rompe.

## Lo que necesito para seguir

1. **Los archivos del logo y favicon oficiales del INCES.** No los tengo; no voy a
   inventarme la imagen institucional. Con un PNG o SVG del logo y otro del
   favicon, los cambio en `web/` y en `assets/`.
2. **Las 3 decisiones de arriba.**
3. **Autorización para desplegar a Cloudflare Pages** —ver el apartado siguiente.
