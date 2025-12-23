import { Controller } from "@hotwired/stimulus"

// Контроллер для dropdown аккаунта
export default class extends Controller {
  static targets = ["menu", "icon"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // показать dropdown
    this.menuTarget.classList.remove("hidden")
    this.menuTarget.classList.add("block")
    // поворот стрелки
    this.iconTarget.classList.add("rotate-180")

    document.addEventListener("click", this.closeOnClickOutside)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.menuTarget.classList.remove("block")
    this.iconTarget.classList.remove("rotate-180")

    document.removeEventListener("click", this.closeOnClickOutside)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}
