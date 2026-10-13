<script>
import FileUpload from 'vue-upload-component';
import Spinner from 'shared/components/Spinner.vue';
import {
  checkFileSizeLimit,
  resolveMaximumFileUploadSize,
} from 'shared/helpers/FileHelper';
import { ALLOWED_FILE_TYPES } from 'shared/constants/messages';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import { DirectUpload } from 'activestorage';
import { mapGetters } from 'vuex';
import { emitter } from 'shared/helpers/mitt';
import { useAttachments } from '../composables/useAttachments';
import { compressImage } from 'widget/helpers/imageCompression';

export default {
  components: { FluentIcon, FileUpload, Spinner },
  props: {
    onAttach: {
      type: Function,
      default: () => {},
    },
  },
  setup() {
    const { canHandleAttachments } = useAttachments();
    return { canHandleAttachments };
  },
  data() {
    return { isUploading: false };
  },
  computed: {
    ...mapGetters({
      globalConfig: 'globalConfig/get',
    }),
    fileUploadSizeLimit() {
      return resolveMaximumFileUploadSize(
        this.globalConfig.maximumFileUploadSize
      );
    },
    allowedFileTypes() {
      return ALLOWED_FILE_TYPES;
    },
    // A camera so aparece em aparelho de toque. No computador, `capture` nao abre camera nenhuma:
    // abre o mesmo seletor de arquivo do botao ao lado, e dois botoes para a mesma coisa confundem.
    showCamera() {
      const temCapture = 'capture' in document.createElement('input');
      const toque =
        typeof window.matchMedia === 'function' &&
        window.matchMedia('(pointer: coarse)').matches;
      return temCapture && toque;
    },
  },
  mounted() {
    document.addEventListener('paste', this.handleClipboardPaste);
  },
  unmounted() {
    document.removeEventListener('paste', this.handleClipboardPaste);
  },
  methods: {
    handleClipboardPaste(e) {
      // If file picker is not enabled, do not allow paste
      if (!this.canHandleAttachments) return;

      const items = (e.clipboardData || e.originalEvent.clipboardData).items;
      // items is a DataTransferItemList object which does not have forEach method
      const itemsArray = Array.from(items);
      itemsArray.forEach(item => {
        if (item.kind === 'file') {
          e.preventDefault();
          const file = item.getAsFile();
          this.$refs.upload.add(file);
        }
      });
    },
    getFileType(fileType) {
      return fileType.includes('image') ? 'image' : 'file';
    },
    // Encolhe a foto ANTES de subir. O ganho e de tempo e de banda de quem manda, nao de
    // qualidade: imagem acima do limite e reduzida do lado do modelo de qualquer jeito. Devolve o
    // proprio arquivo quando nao ha o que ganhar, e NUNCA lanca — falhar aqui nao pode impedir
    // alguem de mandar uma foto.
    async encolherSeForImagem(file) {
      if (!file || !file.file) return file;
      const menor = await compressImage(file.file);
      if (menor === file.file) return file;
      return {
        ...file,
        file: menor,
        name: menor.name,
        size: menor.size,
        type: menor.type,
      };
    },
    // Porta de entrada para quem nao vem do seletor de arquivo — hoje, o gravador de audio.
    // Fica aqui de proposito: o envio (limite de tamanho, upload direto, aviso de erro) e um so.
    async uploadRawFile(rawFile) {
      if (!rawFile) return;
      await this.onFileUpload({
        file: rawFile,
        name: rawFile.name,
        size: rawFile.size,
        type: rawFile.type,
      });
    },
    async onFileUpload(file) {
      const pronto = await this.encolherSeForImagem(file);
      if (this.globalConfig.directUploadsEnabled) {
        await this.onDirectFileUpload(pronto);
      } else {
        await this.onIndirectFileUpload(pronto);
      }
    },
    async onDirectFileUpload(file) {
      if (!file) {
        return;
      }
      this.isUploading = true;
      try {
        if (checkFileSizeLimit(file, this.fileUploadSizeLimit)) {
          const { websiteToken } = window.chatwootWebChannel;
          const upload = new DirectUpload(
            file.file,
            `/api/v1/widget/direct_uploads?website_token=${websiteToken}`,
            {
              directUploadWillCreateBlobWithXHR: xhr => {
                xhr.setRequestHeader('X-Auth-Token', window.authToken);
              },
            }
          );

          upload.create((error, blob) => {
            if (error) {
              emitter.emit(BUS_EVENTS.SHOW_ALERT, {
                message: error,
              });
            } else {
              this.onAttach({
                file: blob.signed_id,
                ...this.getLocalFileAttributes(file),
              });
            }
          });
        } else {
          emitter.emit(BUS_EVENTS.SHOW_ALERT, {
            message: this.$t('FILE_SIZE_LIMIT', {
              MAXIMUM_FILE_UPLOAD_SIZE: this.fileUploadSizeLimit,
            }),
          });
        }
      } catch (error) {
        // Error
      }
      this.isUploading = false;
    },
    async onIndirectFileUpload(file) {
      if (!file) {
        return;
      }
      this.isUploading = true;
      try {
        if (checkFileSizeLimit(file, this.fileUploadSizeLimit)) {
          await this.onAttach({
            file: file.file,
            ...this.getLocalFileAttributes(file),
          });
        } else {
          emitter.emit(BUS_EVENTS.SHOW_ALERT, {
            message: this.$t('FILE_SIZE_LIMIT', {
              MAXIMUM_FILE_UPLOAD_SIZE: this.fileUploadSizeLimit,
            }),
          });
        }
      } catch (error) {
        // Error
      }
      this.isUploading = false;
    },
    getLocalFileAttributes(file) {
      return {
        thumbUrl: window.URL.createObjectURL(file.file),
        fileType: this.getFileType(file.type),
      };
    },
  },
};
</script>

<template>
  <FileUpload
    v-if="showCamera"
    :size="4096 * 2048"
    accept="image/*"
    capture="environment"
    :data="{
      direct_upload_url: '/api/v1/widget/direct_uploads',
      direct_upload: true,
    }"
    @input-file="onFileUpload"
  >
    <button
      class="min-h-8 min-w-8 flex items-center justify-center"
      :aria-label="$t('CAMERA.TAKE_PHOTO')"
    >
      <FluentIcon icon="image" />
    </button>
  </FileUpload>
  <FileUpload
    ref="upload"
    :size="4096 * 2048"
    :accept="allowedFileTypes"
    :data="{
      direct_upload_url: '/api/v1/widget/direct_uploads',
      direct_upload: true,
    }"
    @input-file="onFileUpload"
  >
    <button class="min-h-8 min-w-8 flex items-center justify-center">
      <FluentIcon v-if="!isUploading.image" icon="attach" />
      <Spinner v-if="isUploading" size="small" />
    </button>
  </FileUpload>
</template>
