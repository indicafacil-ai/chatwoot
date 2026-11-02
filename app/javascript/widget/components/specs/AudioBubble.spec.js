import { mount } from '@vue/test-utils';
import AudioBubble from '../AudioBubble.vue';

describe('AudioBubble', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  const montar = () => {
    const wrapper = mount(AudioBubble, {
      props: { url: 'https://x/reply.ogg' },
    });
    const load = vi.fn();
    wrapper.find('audio').element.load = load;
    return { wrapper, load };
  };

  it('usa o endereco recebido', () => {
    const { wrapper } = montar();
    expect(wrapper.find('source').attributes('src')).toBe(
      'https://x/reply.ogg'
    );
  });

  it('tenta carregar de novo quando o arquivo ainda nao esta pronto', async () => {
    const { wrapper, load } = montar();
    await wrapper.find('source').trigger('error');
    expect(load).not.toHaveBeenCalled();
    vi.advanceTimersByTime(1000);
    expect(load).toHaveBeenCalledTimes(1);
  });

  it('desiste depois do limite de tentativas', async () => {
    const { wrapper, load } = montar();
    for (let i = 0; i < 10; i += 1) {
      // eslint-disable-next-line no-await-in-loop
      await wrapper.find('source').trigger('error');
      vi.advanceTimersByTime(10000);
    }
    expect(load).toHaveBeenCalledTimes(6);
  });

  it('nao tenta de novo depois de sair da tela', async () => {
    const { wrapper, load } = montar();
    await wrapper.find('source').trigger('error');
    wrapper.unmount();
    vi.advanceTimersByTime(10000);
    expect(load).not.toHaveBeenCalled();
  });
});
