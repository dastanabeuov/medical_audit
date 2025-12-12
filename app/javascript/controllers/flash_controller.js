import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Автоматически скрывать flash-сообщения через 5 секунд
    this.timeout = setTimeout(() => {
      this.dismissAll()
    }, 5000)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss(event) {
    const message = event.target.closest('[data-flash-target="message"]')
    if (message) {
      this.fadeOut(message)
    }
  }

  dismissAll() {
    this.messageTargets.forEach(message => {
      this.fadeOut(message)
    })
  }

  fadeOut(element) {
    element.style.transition = "opacity 0.3s ease-out"
    element.style.opacity = "0"

    setTimeout(() => {
      element.remove()
    }, 300)
  }
}
