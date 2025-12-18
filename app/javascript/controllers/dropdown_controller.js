import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  disconnect() {
    this.removeClickListener()
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
    this.menuTarget.classList.remove("hidden")
    this.addClickListener()
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.removeClickListener()
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  addClickListener() {
    document.addEventListener("click", this.closeOnClickOutside)
  }

  removeClickListener() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }
}
