module = angular.module("taigaHistory")

module.directive "tgEmojiPicker", ->
  return {
    restrict: "A"
    scope: {
      onSelect: "&"
      commentId: "@"
      suggested: "=?"
    }

    link: (scope, element) ->
      pickerInstance = null
      container = null
      hoverBox = null
      hoverTimeout = null

      scope.suggested ?= ['👍', '✅', '💯', '🎉', '👏', '❤️']

      closePicker = ->
        if container
          container.remove()
          container = null
          pickerInstance = null
          document.removeEventListener("click", onClickOutside)

      removeHoverBox = ->
        hoverBox?.remove()
        hoverBox = null
        hoverTimeout = null

      onClickOutside = (event) ->
        isClickInside = container?.contains(event.target) or element[0].contains(event.target)
        unless isClickInside
          closePicker()

      createHoverBox = ->
        return if hoverBox

        hoverBox = document.createElement("div")
        hoverBox.className = "emoji-hover-box"
        document.body.appendChild(hoverBox)

        for emoji in scope.suggested
          do (e = emoji) ->
            btn = document.createElement("button")
            btn.className = "emoji-hover-btn"
            btn.textContent = e
            btn.onclick = (event) ->
              event.stopPropagation()
              scope.$apply ->
                scope.onSelect({ emoji: e, commentId: scope.commentId })
              removeHoverBox()
            hoverBox.appendChild(btn)

        rect = element[0].getBoundingClientRect()
        hoverBox.style.position = "absolute"
        hoverBox.style.top = "#{rect.top + window.scrollY - 36}px"
        hoverBox.style.left = "#{rect.left + window.scrollX}px"
        hoverBox.style.zIndex = "10000"
        hoverBox.style.display = "flex"
        hoverBox.style.gap = "4px"

        hoverBox.onmouseenter = ->
          if hoverTimeout?
            clearTimeout(hoverTimeout)
            hoverTimeout = null

        hoverBox.onmouseleave = ->
          hoverTimeout = setTimeout(removeHoverBox, 200)

        onClickOutsideSuggested = (event) ->
          return unless hoverBox and element[0]
          unless hoverBox.contains(event.target) or element[0].contains(event.target)
            removeHoverBox()
            document.removeEventListener("click", onClickOutsideSuggested)

        document.addEventListener("click", onClickOutsideSuggested)

      element.on "mouseenter", -> createHoverBox()

      element.on "mouseleave", (event) ->
        target = event.relatedTarget
        unless hoverBox?.contains(target)
          hoverTimeout = setTimeout(removeHoverBox, 200)

      element.on "click", (e) ->
        e.stopPropagation()

        removeHoverBox() #dispensa a sugestao ao clicar no picker

        if container
          closePicker()
          return

        container = document.createElement("div")
        container.className = "emoji-mart-container"
        document.body.appendChild(container)

        pickerInstance = new EmojiMart.Picker({
          emojiVersion: '15',
          noCountryFlags: false,
          theme: 'auto',
          previewPosition: 'top',
          set: 'google',
          locale: 'pt',
          onEmojiSelect: (emoji) ->
            scope.$apply ->
              scope.onSelect({
                emoji: emoji.native,
                commentId: scope.commentId
              })
              closePicker()
        })

        container.appendChild(pickerInstance)

        rect = element[0].getBoundingClientRect()
        container.style.position = "absolute"
        setTimeout ->
          container.style.top = "#{rect.top + window.scrollY - container.offsetHeight}px"
        , 0
        container.style.left = "#{rect.left + window.scrollX}px"
        container.style.zIndex = "9999"

        document.addEventListener("click", onClickOutside)
  }
