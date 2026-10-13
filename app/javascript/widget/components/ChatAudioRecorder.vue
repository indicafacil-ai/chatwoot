<script>
import FluentIcon from 'shared/components/FluentIcon/Index.vue';

// Teto de seguranca. Nao e regra de produto: e para o microfone nao ficar ligado por horas se a
// pessoa esquecer a aba aberta, e para o arquivo nao chegar grande demais no 4G dela.
const MAX_SEGUNDOS = 5 * 60;

// A ordem importa: o primeiro que o navegador aceitar e o escolhido. Opus e o menor com boa voz;
// o Safari nao grava webm e cai no mp4/aac, que tambem serve.
const FORMATOS = [
  'audio/webm;codecs=opus',
  'audio/webm',
  'audio/mp4',
  'audio/ogg;codecs=opus',
];

const EXTENSAO = { webm: 'webm', mp4: 'm4a', ogg: 'ogg' };

export default {
  name: 'ChatAudioRecorder',
  components: { FluentIcon },
  emits: ['finish', 'cancel', 'error'],
  data() {
    return {
      segundos: 0,
      gravando: false,
      recorder: null,
      stream: null,
      pedacos: [],
      cronometro: null,
      cancelado: false,
    };
  },
  computed: {
    tempo() {
      const m = Math.floor(this.segundos / 60);
      const s = this.segundos % 60;
      return `${m}:${String(s).padStart(2, '0')}`;
    },
  },
  mounted() {
    this.iniciar();
  },
  beforeUnmount() {
    this.liberar();
  },
  methods: {
    formatoSuportado() {
      if (typeof MediaRecorder === 'undefined') return null;
      const aceito = FORMATOS.find(f => MediaRecorder.isTypeSupported(f));
      // `undefined` deixa o navegador escolher sozinho, que e melhor que falhar.
      return aceito || undefined;
    },
    async iniciar() {
      if (!navigator.mediaDevices?.getUserMedia) {
        this.$emit('error', 'NOT_SUPPORTED');
        return;
      }
      try {
        this.stream = await navigator.mediaDevices.getUserMedia({
          audio: true,
        });
      } catch (error) {
        // Negar o microfone e uma escolha legitima de quem esta do outro lado — nao e defeito.
        this.$emit('error', 'PERMISSION_DENIED');
        return;
      }

      const mimeType = this.formatoSuportado();
      try {
        this.recorder = new MediaRecorder(
          this.stream,
          mimeType ? { mimeType } : undefined
        );
      } catch (error) {
        this.liberar();
        this.$emit('error', 'NOT_SUPPORTED');
        return;
      }

      this.recorder.addEventListener('dataavailable', e => {
        if (e.data && e.data.size) this.pedacos.push(e.data);
      });
      this.recorder.addEventListener('stop', this.aoParar);

      this.recorder.start();
      this.gravando = true;
      this.cronometro = setInterval(() => {
        this.segundos += 1;
        if (this.segundos >= MAX_SEGUNDOS) this.parar();
      }, 1000);
    },
    aoParar() {
      // O microfone e desligado ANTES de qualquer outra coisa: a luzinha do aparelho tem de apagar
      // no instante em que a pessoa para, mesmo que o resto falhe.
      this.liberar();

      if (this.cancelado) {
        this.$emit('cancel');
        return;
      }

      const tipo = this.recorder?.mimeType || 'audio/webm';
      const blob = new Blob(this.pedacos, { type: tipo });
      if (!blob.size) {
        this.$emit('cancel');
        return;
      }

      const base = tipo.split(';')[0].split('/')[1] || 'webm';
      const ext = EXTENSAO[base] || 'webm';
      const arquivo = new File([blob], `audio-${Date.now()}.${ext}`, {
        type: tipo.split(';')[0],
      });
      this.$emit('finish', arquivo);
    },
    parar() {
      if (this.recorder && this.recorder.state !== 'inactive') {
        this.recorder.stop();
      } else {
        this.liberar();
        this.$emit('cancel');
      }
      this.gravando = false;
    },
    descartar() {
      this.cancelado = true;
      this.parar();
    },
    liberar() {
      clearInterval(this.cronometro);
      this.cronometro = null;
      if (this.stream) {
        this.stream.getTracks().forEach(t => t.stop());
        this.stream = null;
      }
    },
  },
};
</script>

<template>
  <div class="flex items-center flex-1 gap-2 px-1">
    <span class="relative flex w-2 h-2">
      <span
        class="absolute inline-flex w-full h-full rounded-full opacity-75 bg-n-ruby-9 animate-ping"
      />
      <span class="relative inline-flex w-2 h-2 rounded-full bg-n-ruby-9" />
    </span>
    <span class="text-sm tabular-nums text-n-slate-12">{{ tempo }}</span>
    <span class="flex-1 text-sm truncate text-n-slate-11">
      {{ $t('VOICE_MESSAGE.RECORDING') }}
    </span>
    <button
      class="flex items-center justify-center min-h-8 min-w-8 text-n-slate-11"
      :aria-label="$t('VOICE_MESSAGE.CANCEL')"
      @click="descartar"
    >
      <FluentIcon icon="dismiss" />
    </button>
    <button
      class="flex items-center justify-center min-h-8 min-w-8 text-n-brand"
      :aria-label="$t('VOICE_MESSAGE.STOP_AND_SEND')"
      @click="parar"
    >
      <FluentIcon icon="send" />
    </button>
  </div>
</template>
