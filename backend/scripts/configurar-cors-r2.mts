/**
 * Configura el CORS del bucket R2 para que el navegador pueda subir archivos.
 *
 * **Por qué hace falta.** La subida no pasa por la API: el servidor firma una URL
 * y el navegador hace `PUT` **directo** a R2. Sin una regla CORS en el bucket,
 * ese PUT lo bloquea el navegador y la pantalla sólo puede decir «no pudimos
 * conectar con el servidor» —que es verdad, pero señala al sitio equivocado—.
 * Medido el 2026-10-31: subir un .docx desde la cuenta de estudiante fallaba en
 * ese punto.
 *
 * La API de Cloudflare exige un token con permiso de R2 (el del despliegue de
 * Pages no lo tiene: responde 403). Las credenciales S3 del bucket sí permiten
 * `PutBucketCors`, así que se usa la API S3.
 *
 * Uso: npx tsx scripts/configurar-cors-r2.mts
 */
import { GetBucketCorsCommand, PutBucketCorsCommand, S3Client } from '@aws-sdk/client-s3';

const cuenta = process.env.CLOUDFLARE_ACCOUNT_ID ?? '';
const bucket = process.env.R2_BUCKET ?? '';
const acceso = process.env.R2_ACCESS_KEY_ID ?? '';
const secreto = process.env.R2_SECRET_ACCESS_KEY ?? '';

if (!cuenta || !bucket || !acceso || !secreto) {
  console.error('Faltan CLOUDFLARE_ACCOUNT_ID, R2_BUCKET, R2_ACCESS_KEY_ID o R2_SECRET_ACCESS_KEY.');
  process.exit(1);
}

const cliente = new S3Client({
  region: 'auto',
  endpoint: `https://${cuenta}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: acceso, secretAccessKey: secreto },
});

// Producción y previsualizaciones de Pages, más el desarrollo local. El comodín
// `https://*.inces-lms.pages.dev` cubre los despliegues de previsualización, que
// usan un subdominio distinto en cada publicación.
const origenes = [
  'https://inces-lms.pages.dev',
  'https://*.inces-lms.pages.dev',
  'http://localhost:8090',
  'http://127.0.0.1:8090',
];

const regla = {
  AllowedOrigins: origenes,
  AllowedMethods: ['GET', 'PUT', 'HEAD'],
  // `content-type` es el que la firma incluye; sin él el PUT falla por cabecera
  // no permitida aunque la URL esté bien firmada.
  AllowedHeaders: ['*'],
  ExposeHeaders: ['ETag'],
  MaxAgeSeconds: 3600,
};

try {
  await cliente.send(
    new PutBucketCorsCommand({
      Bucket: bucket,
      CORSConfiguration: { CORSRules: [regla] },
    }),
  );
  console.log('CORS aplicado a', bucket);
} catch (error) {
  console.error('No se pudo aplicar el CORS:', error instanceof Error ? error.message : error);
  process.exit(1);
}

const leido = await cliente.send(new GetBucketCorsCommand({ Bucket: bucket }));
console.log('CORS vigente:', JSON.stringify(leido.CORSRules ?? [], null, 1));
