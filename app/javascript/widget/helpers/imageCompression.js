/**
 * Encolhe a foto no navegador do cliente, ANTES de subir.
 *
 * O ganho nao e de qualidade — e de tempo e de banda. Imagem acima do limite e reduzida
 * automaticamente do lado do modelo de visao, entao mandar uma foto de 12 MP nao faz o agente ler
 * melhor: so demora no 4G de quem mandou e ocupa armazenamento nosso. Uma foto de celular sai de
 * 3-5 MB para 200-300 KB sem perder uma letra.
 */

// Teto: o lado maior. 1568 px e o limite dos modelos de visao ate o Claude 4.6; acima disso a
// imagem e reduzida do outro lado de qualquer jeito.
export const MAX_EDGE = 1568;

// 🔴 Piso: abaixo de 200 px em qualquer lado o desempenho do modelo PIORA. Este numero existe para
// proteger o caso que mais importa aqui — a foto de um DOCUMENTO, onde letra pequena some se a
// compressao passar do ponto.
export const MIN_EDGE = 200;

const QUALITY = 0.82;

// GIF perde a animacao ao passar pelo canvas, e SVG e vetor: rasterizar piora os dois. Passam
// intactos.
const FORMATOS_INTOCADOS = ['image/gif', 'image/svg+xml'];

const ehImagemTratavel = file =>
  Boolean(file) &&
  typeof file.type === 'string' &&
  file.type.startsWith('image/') &&
  !FORMATOS_INTOCADOS.includes(file.type);

/**
 * @param {File} file
 * @returns {Promise<File>} a imagem encolhida, ou o PROPRIO arquivo quando nao ha o que ganhar.
 *
 * Nunca lanca: qualquer imprevisto devolve o original. Falhar aqui nao pode impedir o cliente de
 * mandar a foto — subir grande e muito melhor que nao subir.
 */
export async function compressImage(file) {
  if (!ehImagemTratavel(file)) return file;
  if (typeof createImageBitmap !== 'function') return file;

  let bitmap = null;
  try {
    // `from-image` respeita a orientacao gravada pela camera. Sem isso, documento fotografado em
    // pe chega deitado — e o agente nao le.
    bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });

    const { width, height } = bitmap;
    const maior = Math.max(width, height);
    const menor = Math.min(width, height);

    // A escala mira o teto no lado maior, mas nunca deixa o lado menor furar o piso. Em foto
    // panoramica as duas regras brigam, e o piso ganha: legibilidade vale mais que bytes.
    const escala = Math.min(1, Math.max(MAX_EDGE / maior, MIN_EDGE / menor));
    if (escala >= 1) return file;

    const w = Math.round(width * escala);
    const h = Math.round(height * escala);

    const canvas = document.createElement('canvas');
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext('2d');
    if (!ctx) return file;
    ctx.drawImage(bitmap, 0, 0, w, h);

    const blob = await new Promise(resolve => {
      canvas.toBlob(resolve, 'image/jpeg', QUALITY);
    });

    // Se o resultado nao ficou menor, o original ja estava bom. Acontece com imagem pequena e
    // muito comprimida, e trocar por um JPEG maior seria piorar duas vezes.
    if (!blob || blob.size >= file.size) return file;

    const nome = `${(file.name || 'foto').replace(/\.[^.]+$/, '')}.jpg`;
    return new File([blob], nome, {
      type: 'image/jpeg',
      lastModified: Date.now(),
    });
  } catch (error) {
    return file;
  } finally {
    if (bitmap && typeof bitmap.close === 'function') bitmap.close();
  }
}
