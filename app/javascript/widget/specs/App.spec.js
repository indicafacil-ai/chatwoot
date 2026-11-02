import App from '../App.vue';

const { goStraightToConversation } = App.methods;

const contexto = (rota, extras = {}) => {
  const replace = vi.fn();
  const estado = { $route: { name: undefined } };
  return {
    ...estado,
    preChatFormEnabled: false,
    conversationSize: 0,
    router: {
      replace,
      isReady() {
        this.pronto = true;
        contexto.atual.$route = { name: rota };
        return Promise.resolve();
      },
    },
    ...extras,
  };
};

describe('goStraightToConversation', () => {
  const rodar = async (rota, startInConversation = true, extras = {}) => {
    const ctx = contexto(rota, extras);
    contexto.atual = ctx;
    await goStraightToConversation.call(ctx, startInConversation);
    return ctx.router.replace;
  };

  it('espera a rota inicial antes de decidir', async () => {
    expect(await rodar('home')).toHaveBeenCalledWith({ name: 'messages' });
  });

  it('nao faz nada sem a opcao', async () => {
    expect(await rodar('home', false)).not.toHaveBeenCalled();
  });

  it('respeita mensagem nao lida e campanha', async () => {
    expect(await rodar('unread-messages')).not.toHaveBeenCalled();
    expect(await rodar('campaigns')).not.toHaveBeenCalled();
  });

  it('mantem o formulario de pre-atendimento', async () => {
    const replace = await rodar('home', true, { preChatFormEnabled: true });
    expect(replace).toHaveBeenCalledWith({ name: 'prechat-form' });
  });
});
