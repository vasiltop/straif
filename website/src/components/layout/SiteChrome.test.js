import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import SiteFooter from './SiteFooter.vue';
import SiteHeader from './SiteHeader.vue';

const steamUrl = 'https://store.steampowered.com/app/3850480/Straif/';
const routerLinkStub = {
  props: ['to'],
  template: '<a :href="to"><slot /></a>',
};

function mountWithRouterLink(component) {
  return mount(component, {
    global: {
      stubs: {
        RouterLink: routerLinkStub,
      },
    },
  });
}

describe('site Steam links', () => {
  it('adds the approved Steam link to the header', () => {
    const wrapper = mountWithRouterLink(SiteHeader);
    const link = wrapper.get(`a[href="${steamUrl}"]`);

    expect(link.text()).toBe('Get Straif');
    expect(link.attributes()).toMatchObject({
      target: '_blank',
      rel: 'noopener noreferrer',
    });
  });

  it('adds the approved Steam link to the footer', () => {
    const wrapper = mountWithRouterLink(SiteFooter);
    const link = wrapper.get(`a[href="${steamUrl}"]`);

    expect(link.text()).toBe('Steam');
    expect(link.attributes()).toMatchObject({
      target: '_blank',
      rel: 'noopener noreferrer',
    });
  });
});
