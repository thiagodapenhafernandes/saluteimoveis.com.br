import { Controller } from "@hotwired/stimulus"
import Swiper from "swiper/bundle"

export default class extends Controller {
  connect() {
    this.initializeSwiper();
  }

  initializeSwiper() {
    if (this.swiper) return;

    try {
      this.swiper = new Swiper(this.element, {
        slidesPerView: 1,
        spaceBetween: 0,
        loop: false,
        effect: 'slide',
        speed: 300,
        width: this.element.offsetWidth,

        // Allow events to bubble
        touchEventsTarget: 'wrapper',
        nested: true,
        passiveListeners: true,

        // Navigation arrows
        navigation: {
          nextEl: this.element.querySelector('.swiper-button-next'),
          prevEl: this.element.querySelector('.swiper-button-prev'),
        },

        // Pagination dots
        pagination: {
          el: this.element.querySelector('.swiper-pagination'),
          clickable: true,
          dynamicBullets: false,
        },

        // Stop clicks from bubbling to card link
        on: {
          click: (swiper, event) => {
            const target = event.target;
            // Only stop propagation on navigation elements
            if (target.closest('.swiper-button-next') ||
              target.closest('.swiper-button-prev') ||
              target.closest('.swiper-pagination')) {
              event.stopPropagation();
            }
          }
        }
      });
    } catch (error) {
      console.error('Error initializing card swiper:', error);
    }
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy(true, true);
      this.swiper = null;
    }
  }
}
