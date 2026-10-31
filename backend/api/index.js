// Entrada de la función de Vercel.
//
// Es JavaScript puro y no .ts a propósito: Vercel compila las funciones con
// esbuild, que **no** reescribe los especificadores `.js` de TypeScript
// (`import './app.js'` apuntando a `app.ts`), y este backend usa NodeNext en
// todo. Apuntar al `dist/` ya compilado evita el problema: `npm run build`
// corre antes en el `buildCommand` y aquí sólo se reexporta.
export { default } from '../dist/vercel.js';
